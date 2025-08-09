import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/helpers.dart';

class CallHistoryPage extends StatefulWidget {
  @override
  _CallHistoryPageState createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  List<CallLogEntry> _callLogs = [];
  List<String> _leadPhoneNumbers = [];
  bool _loading = true;
  String? staffId;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    await Hive.initFlutter();
    final box = await Hive.openBox('myBox');

    final rawData = box.get('staffinfo');
    final staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);
    staffId = staffInfo['staffid']?.toString();

    if (staffId == null) {
      print("Staff ID not found");
      setState(() => _loading = false);
      return;
    }

    await _fetchLeadPhoneNumbers();
    await _loadCallLogs();
  }

  Future<void> _fetchLeadPhoneNumbers() async {
    final url =
    Uri.parse("https://crm.vasaantham.com/api/get_leads_by_id/$staffId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List leads = jsonDecode(response.body);
        _leadPhoneNumbers = leads
            .map((lead) =>
            (lead['phonenumber'] ?? '').toString().replaceAll(RegExp(r'\D'), ''))
            .where((number) => number.isNotEmpty)
            .toList()
            .cast<String>();
      }
    } catch (e) {
      print("Error fetching leads: $e");
    }
  }

  Future<bool> _requestPermission() async {
    final status = await Permission.phone.status;
    if (!status.isGranted) {
      final result = await Permission.phone.request();
      return result.isGranted;
    }
    return true;
  }

  Future<void> _loadCallLogs() async {
    if (!await _requestPermission()) {
      setState(() => _loading = false);
      return;
    }

    try {
      Iterable<CallLogEntry> entries = await CallLog.get();
      final filtered = _filterByLeadNumbers(entries.toList());

      setState(() {
        _callLogs = _removeDuplicateTimestamps(filtered)
          ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
        _loading = false;
      });
    } catch (e) {
      print('Failed to get call logs: $e');
      setState(() => _loading = false);
    }
  }

  List<CallLogEntry> _filterByLeadNumbers(List<CallLogEntry> entries) {
    return entries.where((entry) {
      final number = entry.number?.replaceAll(RegExp(r'\D'), '');
      return number != null && _leadPhoneNumbers.contains(number);
    }).toList();
  }

  List<CallLogEntry> _removeDuplicateTimestamps(List<CallLogEntry> calls) {
    final seenTimestamps = <int>{};
    return calls.where((call) {
      final ts = call.timestamp;
      final isNew = ts != null && !seenTimestamps.contains(ts);
      if (isNew) seenTimestamps.add(ts!);
      return isNew;
    }).toList();
  }

  String formatCallType(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return "Incoming";
      case CallType.outgoing:
        return "Outgoing";
      case CallType.missed:
        return "Missed";
      default:
        return "Unknown";
    }
  }

  String formatDate(int? timestamp) {
    if (timestamp == null) return "Unknown date";
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      // appBar: AppBar(title: const Text('Filtered Call History')),
      body: RefreshIndicator(
        onRefresh: _loadCallLogs,
        child: _callLogs.isEmpty
            ? ListView(
          children: const [
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text("No call history available."),
              ),
            ),
          ],
        )
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _callLogs.length,
          itemBuilder: (context, index) {
            final call = _callLogs[index];
            return ListTile(
              leading: Icon(
                call.callType == CallType.missed
                    ? Icons.call_missed
                    : Icons.call_made,
                color: call.callType == CallType.missed ? Colors.red : Colors.green,
              ),
              title: Text(
                (call.name?.isNotEmpty == true)
                    ? call.name!
                    : (call.number?.trim().isNotEmpty == true ? call.number! : "Unknown"),
              ),
              subtitle: Text(
                  "${formatCallType(call.callType)} - Duration: ${formatDuration(call.duration)}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () =>
                        showCallDetailsBottomSheet(context, call),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Call ${call.number}?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                // Implement call logic
                              },
                              child: const Text("Call"),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void showCallDetailsBottomSheet(BuildContext context, CallLogEntry call) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Wrap(
            children: [
              Row(
                children: const [
                  Icon(Icons.phone_forwarded, color: Colors.green, size: 30),
                  SizedBox(width: 10),
                  Text("Call Details",
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text("Number"),
                subtitle: Text(call.number ?? "Unknown"),
              ),
              ListTile(
                leading: const Icon(Icons.call),
                title: const Text("Type"),
                subtitle: Text(formatCallType(call.callType)),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text("Duration"),
                subtitle: Text(formatDuration(call.duration)),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text("Date"),
                subtitle: Text(formatDate(call.timestamp)),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text("Close"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

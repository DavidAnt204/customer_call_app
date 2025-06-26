// screens/call_history_page.dart
import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';

class CallHistoryPage extends StatefulWidget {
  @override
  _CallHistoryPageState createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  List<CallLogEntry> _callLogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCallLogs();
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
      setState(() {
        _callLogs = removeDuplicateTimestamps(entries.toList());
        _callLogs.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
        _loading = false;
      });
    } catch (e) {
      print('Failed to get call logs: $e');
      setState(() => _loading = false);
    }
  }

  List<CallLogEntry> removeDuplicateTimestamps(List<CallLogEntry> calls) {
    final seenTimestamps = <int>{}; // Use Set to track seen timestamps
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
    if (_loading) return Center(child: CircularProgressIndicator());

    if (_callLogs.isEmpty)
      return Center(child: Text("No call history available."));

    return ListView.builder(
      itemCount: _callLogs.length,
      itemBuilder: (context, index) {
        final call = _callLogs[index];
        print('callllll ${call.name} ${call.number} ${call.timestamp}');
        return ListTile(
          leading: Icon(
            call.callType == CallType.missed ? Icons.call_missed : Icons.call_made,
            color: call.callType == CallType.missed ? Colors.red : Colors.green,
          ),
          title: Text(
            (call.name?.isNotEmpty == true)
                ? call.name!
                : (call.number?.trim().isNotEmpty == true
                ? call.number!
                : "Unknown"),
          ),
          subtitle: Text(
              "${formatCallType(call.callType)} - Duration: ${call.duration}s"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.info_outline),
                onPressed: () {
                  showCallDetailsBottomSheet(context, call);
                },
              ),
              IconButton(
                icon: Icon(Icons.call, color: Colors.green),
                onPressed: () {
                  // Confirmation dialog before calling
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text("Call ${call.number}?"),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Cancel")),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final Uri uri = Uri(scheme: 'tel', path: call.number);
                            // if (await canLaunchUrl(uri)) {
                            //   await launchUrl(uri);
                            // }
                          },
                          child: Text("Call"),
                        )
                      ],
                    ),
                  );
                },
              )
            ],
          ),
        );
      },
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
                children: [
                  Icon(
                    Icons.phone_forwarded,
                    color: Colors.green,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Call Details",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Divider(),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.phone),
                title: Text("Number"),
                subtitle: Text(call.number ?? "Unknown"),
              ),
              ListTile(
                leading: Icon(Icons.call),
                title: Text("Type"),
                subtitle: Text(formatCallType(call.callType)),
              ),
              ListTile(
                leading: Icon(Icons.timer),
                title: Text("Duration"),
                subtitle: Text("${call.duration} seconds"),
              ),
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text("Date"),
                subtitle: Text(formatDate(call.timestamp)),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                  label: Text("Close"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

}

import 'dart:convert';
import 'package:call_log/call_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_direct_call_plus/flutter_direct_call.dart';
import 'package:flutter_phone_call_state/flutter_phone_call_state.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../services/api_services.dart';
import '../services/helpers.dart';
import 'add_lead_screen.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  late Future<List<Lead>> leadsFuture;
  late Future<List<LeadStatus>> statusFuture;
  List<LeadStatus> statusList = [];
  List<CallLogEntry> _callLogs = [];
  bool _isCallActive = false;
  String? _currentCallLeadId;
  String? _currentCallNumber;
  final Color primaryColor = const Color(0xFF4169E1); // #4169E1
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Listen to phone call state changes
    // PhoneCallState.instance.phoneStateChange.listen(_onPhoneStateEvent);
    PhoneCallState.instance.phoneStateChange.listen((event) {
      // print('phone Event: ${event.state}, number: ${event.number} outtttt');
      _onPhoneStateEvent(event);
    });

    _refresh();
  }

  void _onPhoneStateEvent(event) async {
    // Debug log
    print('📞 Phone event: ${event.state}, number: ${event.number} inside ');

    if ((event.state == CallState.outgoing || event.state == CallState.call) &&
        _currentCallLeadId != null) {
      _isCallActive = true;
      _currentCallNumber = event.number;
    }

    if (_isCallActive && event.state == CallState.end) {
      _isCallActive = false;
      if (_currentCallLeadId != null && _currentCallNumber != null) {
        await _onCallEnded(_currentCallLeadId!, _currentCallNumber!);
      }
      // reset
      _currentCallLeadId = null;
      _currentCallNumber = null;
    }
  }

  Future<void> _onCallEnded(String leadId, String phoneNumber) async {
    print('on call end 111');
    if (!await Permission.phone.request().isGranted) return;

    Iterable<CallLogEntry> logs = await CallLog.query(number: phoneNumber);
    if (logs.isEmpty) return;
    print('on call end 111');
    var entryList = logs.toList()
      ..sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
    CallLogEntry entry = entryList.first;
    print('on call end 111');
    final box = Hive.box('myBox');
    final rawData = box.get('staffinfo');
    final staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);
    final staffId = staffInfo['staffid'] ?? '';
    print('on call end 111');
    final callHistoryMap = {
      "name": entry.name,
      "number": entry.number,
      "duration": formatDuration(entry.duration),
      "timestamp": entry.timestamp,
      "callType": entry.callType.toString()
    };
    print('on call end 1111111 $callHistoryMap');
    final success = await saveCallHistory(
      staffId: staffId,
      leadId: leadId,
      callHistory: callHistoryMap,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '📘 History saved' : '⚠️ Save failed')),
    );
  }

  Future<List<Lead>> fetchLeads() async {
    final res = await http
        .get(Uri.parse('https://crm.vasaantham.com/api/get_leads_by_id/12'));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => Lead.fromJson(e)).toList();
    }
    throw Exception('Failed to load leads');
  }

  Future<List<LeadStatus>> fetchStatuses() async {
    final res = await http
        .get(Uri.parse('https://crm.vasaantham.com/api/get_all_lead_statuses'));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => LeadStatus.fromJson(e)).toList();
    }
    throw Exception('Failed to load statuses');
  }

  Future<void> _loadData() async {
    setState(() {
      _isRefreshing = true;
    });

    // Replace these with actual fetch methods
    leadsFuture = fetchLeads();
    statusFuture = fetchStatuses();

    // Wait for both futures to complete
    await Future.wait([leadsFuture, statusFuture]);

    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _refresh() async {
    _loadData(); // reset futures
    // Wait for both to complete
    await Future.wait([leadsFuture, statusFuture]);
    setState(() {}); // rebuild with new data
  }

  Future<bool> updateLeadStatus(String leadId, String statusId) async {
    final res = await http.patch(
      Uri.parse('https://crm.vasaantham.com/api/update_lead_status/$leadId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status_id': int.parse(statusId)}),
    );
    return res.statusCode == 200;
  }

  Future<bool> _requestPermission() async {
    final status = await Permission.phone.status;
    if (!status.isGranted) {
      final result = await Permission.phone.request();
      return result.isGranted;
    }
    return true;
  }

  Future<void> _loadCallLogs(Iterable<CallLogEntry> logs) async {
    if (!await _requestPermission()) {
      // setState(() => _loading = false);
      return;
    }
    for (var log in logs) {
      print('check log -- $log');
      try {
        Iterable<CallLogEntry> entries = await CallLog.get();
        setState(() {
          _callLogs = removeDuplicateTimestamps(entries.toList());
          _callLogs
              .sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
          // _loading = false;
          print(_callLogs);
        });
      } catch (e) {
        print('Failed to get call logs: $e');
        // setState(() => _loading = false);
      }
    }
  }

  List<CallLogEntry> removeDuplicateTimestamps(List<CallLogEntry> calls) {
    final seenTimestamps = <int>{};
    return calls.where((call) {
      final ts = call.timestamp;
      final isNew = ts != null && !seenTimestamps.contains(ts);
      if (isNew) seenTimestamps.add(ts!);
      return isNew;
    }).toList();
  }

  Future<void> makeCall(String phone, String status, String leadId) async {
    if (status.toLowerCase() == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot call a completed lead')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Make a call'),
        content: Text('Call $phone?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Call')),
        ],
      ),
    );

    if (confirm != true) return;

    // set the current lead and number before dialing
    _currentCallLeadId = leadId;

    await FlutterDirectCall.makeDirectCall(phone);
  }

  Future<bool?> confirmStatusChange(String newStatus) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Status Change'),
        content: Text('Change status to "$newStatus"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
  }

  Color _getStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'new':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.deepPurple;
      case 'rejected':
        return Colors.red;
      case 'accepted':
        return Colors.teal;
      case 'maintenance':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'new':
        return Icons.fiber_new_outlined;
      case 'pending':
        return Icons.hourglass_top;
      case 'in progress':
        return Icons.autorenew;
      case 'rejected':
        return Icons.cancel;
      case 'accepted':
        return Icons.thumb_up;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                // TODO: Add your add lead screen navigation here
                print('Add lead button tapped');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddLeadScreen(
                            leadId: '--', // Pass the lead ID to AddLeadScreen
                          )),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: primaryColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.2), // shadow color with opacity
                      spreadRadius: 1, // how much the shadow spreads
                      blurRadius: 2, // blur effect
                      offset: const Offset(0, 1), // shadow position (x, y)
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        // backgroundColor: const Color(0xFF4169E1), // Matches your blue theme
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([leadsFuture, statusFuture]),
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final leads = snap.data![0] as List<Lead>;
          statusList = snap.data![1] as List<LeadStatus>;

          if (leads.isEmpty) return const Center(child: Text('No leads found'));

          return RefreshIndicator(
              onRefresh: _refresh,
              child: _isRefreshing
                  ? Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: leads.length,
                      separatorBuilder: (i, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final lead = leads[index];
                        final color = _getStatusColor(lead.statusName);

                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Avatar Icon
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF4169E1),
                                            Color(0xFF4A90E2)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.person,
                                          color: Colors.white, size: 28),
                                    ),
                                    const SizedBox(width: 16),

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Name
                                          Text(
                                            lead.name,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF4169E1),
                                            ),
                                          ),
                                          const SizedBox(height: 6),

                                          // Phone Row
                                          Row(
                                            children: [
                                              const Icon(Icons.phone,
                                                  size: 18,
                                                  color: Colors.black54),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  lead.phoneNumber,
                                                  style: const TextStyle(
                                                      fontSize: 14),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Dropdown + Call button in Wrap
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 12,
                                            children: [
                                              // Status Dropdown
                                              LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  return SizedBox(
                                                    width: constraints.maxWidth,
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(
                                                                lead.statusName)
                                                            .withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child:
                                                          DropdownButtonHideUnderline(
                                                        child: DropdownButton<
                                                            String>(
                                                          value:
                                                              lead.statusName,
                                                          isDense: true,
                                                          isExpanded: true,
                                                          icon: const SizedBox
                                                              .shrink(), // Hide dropdown icon
                                                          items: statusList
                                                              .map((status) {
                                                            return DropdownMenuItem(
                                                              value:
                                                                  status.name,
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                    _getStatusIcon(
                                                                        status
                                                                            .name),
                                                                    size: 16,
                                                                    color: _getStatusColor(
                                                                        status
                                                                            .name),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 6),
                                                                  Text(
                                                                    status.name,
                                                                    style:
                                                                        TextStyle(
                                                                      color: _getStatusColor(
                                                                          status
                                                                              .name),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }).toList(),
                                                          onChanged:
                                                              (selected) async {
                                                            if (selected ==
                                                                    null ||
                                                                selected ==
                                                                    lead.statusName)
                                                              return;
                                                            final confirm =
                                                                await confirmStatusChange(
                                                                    selected);
                                                            if (confirm != true)
                                                              return;

                                                            final statusObj =
                                                                statusList
                                                                    .firstWhere((s) =>
                                                                        s.name ==
                                                                        selected);
                                                            final success =
                                                                await updateLeadStatus(
                                                                    lead.id,
                                                                    statusObj
                                                                        .id);

                                                            if (success) {
                                                              setState(() {
                                                                lead.statusName =
                                                                    selected;
                                                                lead.statusId =
                                                                    statusObj
                                                                        .id;
                                                              });
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                    content: Text(
                                                                        'Status updated to "$selected"')),
                                                              );
                                                            } else {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                const SnackBar(
                                                                    content: Text(
                                                                        'Failed to update status')),
                                                              );
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),

                                              // Call Button
                                              LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  return SizedBox(
                                                    width: constraints.maxWidth,
                                                    child: ElevatedButton.icon(
                                                      onPressed: () => makeCall(
                                                          lead.phoneNumber,
                                                          lead.statusName,
                                                          lead.id),
                                                      icon: const Icon(
                                                          Icons.call),
                                                      label: const Text('Call'),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.green,
                                                        foregroundColor:
                                                            Colors.white,
                                                        fixedSize: const Size
                                                            .fromHeight(38),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(30),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Edit Icon in the top-right corner
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    // Handle the edit action
                                    print("Edit icon pressed");
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddLeadScreen(
                                          leadId: lead
                                              .id, // Pass the lead ID to AddLeadScreen
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ));
        },
      ),
    );
  }
}

class Lead {
  String phoneNumber;
  String name;
  String id;
  String statusName;
  String statusId;

  Lead({
    required this.phoneNumber,
    required this.name,
    required this.id,
    required this.statusName,
    required this.statusId,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      phoneNumber: json['phonenumber'] ?? '',
      name: json['name'] ?? '',
      id: json['id'] ?? '',
      statusName: json['status_name'] ?? '',
      statusId: json['status_id']?.toString() ?? '',
    );
  }
}

class LeadStatus {
  String id;
  String name;

  LeadStatus({required this.id, required this.name});

  factory LeadStatus.fromJson(Map<String, dynamic> json) {
    return LeadStatus(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

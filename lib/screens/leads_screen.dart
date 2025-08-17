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

    _showFeedbackPopup(context, leadId, phoneNumber);
  }

  Future<void> _onFeedbackSubmit(context, Map<String, dynamic> formData) async {
    // Extract individual values
    String leadId = formData["leadId"];
    String phoneNumber = formData["phoneNumber"];

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
      formData: formData,
      callHistory: callHistoryMap,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '📘 Call history & notes saved successfully.' : '⚠️ Call history & notes save failed')),
    );
    Navigator.of(context).pop(true);
  }

  void _showFeedbackPopup(BuildContext context, leadId, phoneNumber) {
    // ---------- Static dropdown data (value + text) ----------
    final List<Map<String, String>> leadCallStatus = [
      {"value": "1", "text": "Interested"},
      {"value": "2", "text": "Not Interested"},
      {"value": "3", "text": "Not Attend The Call"},
      {"value": "4", "text": "Switch Off"},
    ];

    final List<Map<String, String>> leadBusinessCategory = [
      {"value": "agri", "text": "Agri"},
      {"value": "civil", "text": "Civil"},
    ];

    final List<Map<String, String>> leadTypePurchase = [
      {"value": "subsidy", "text": "Subsidy"},
      {"value": "sales", "text": "Sales"},
    ];

    // ---------- Form + controllers ----------
    final _formKey = GlobalKey<FormState>();
    final TextEditingController farmerNameController = TextEditingController();
    final TextEditingController remarksController = TextEditingController();
    final TextEditingController reminderDateController =
        TextEditingController();

    // ---------- Selected values ----------
    String? selectedStatus;
    String? selectedBusinessCategory;
    String? selectedTypePurchase;
    String? district; // from API
    String? division;
    String? block;
    String? village;
    String? product;
    String? machineName;

    // ---------- API: fetch districts ----------
    final Future<List<Map<String, String>>> districtsFuture =
        LeadService().getLeadDistrict();
    Future<List<Map<String, String>>>? divisionsFuture;
    Future<List<Map<String, String>>>? blocksFuture;
    Future<List<Map<String, String>>>? villagesFuture;
    Future<List<Map<String, String>>> productsFuture =
        LeadService().getProducts();
    Future<List<Map<String, String>>>? machineNamesFuture;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.zero, // full screen
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // page-like
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              // filter purchase options based on business category
              final List<Map<String, String>> filteredPurchaseOptions =
                  (selectedBusinessCategory == "civil")
                      ? leadTypePurchase
                          .where((t) => t["value"] == "sales")
                          .toList()
                      : leadTypePurchase; // agri/null -> both

              return Column(
                children: [
                  // ---------- Fixed Header ----------
                  Container(
                    width: double.infinity,
                    color: Colors.white70,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "Call History",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(height: 1),

                  // ---------- Scrollable form ----------
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Farmer Name
                              TextFormField(
                                controller: farmerNameController,
                                decoration: const InputDecoration(
                                  labelText: "Farmer Name",
                                  border: UnderlineInputBorder(),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? "Enter farmer name"
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Lead Call Status
                              DropdownButtonFormField<String>(
                                value: selectedStatus,
                                decoration: const InputDecoration(
                                  labelText: "Lead Call Status",
                                  border: UnderlineInputBorder(),
                                ),
                                items: leadCallStatus
                                    .map((s) => DropdownMenuItem<String>(
                                          value: s["value"],
                                          child: Text(s["text"]!),
                                        ))
                                    .toList(),
                                onChanged: (val) => setState(() {
                                  selectedStatus = val;
                                }),
                                validator: (v) => v == null
                                    ? "Select lead call status"
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Lead Business Category
                              DropdownButtonFormField<String>(
                                value: selectedBusinessCategory,
                                decoration: const InputDecoration(
                                  labelText: "Lead Business Category",
                                  border: UnderlineInputBorder(),
                                ),
                                items: leadBusinessCategory
                                    .map((c) => DropdownMenuItem<String>(
                                          value: c["value"],
                                          child: Text(c["text"]!),
                                        ))
                                    .toList(),
                                onChanged: (val) => setState(() {
                                  selectedBusinessCategory = val;
                                  selectedTypePurchase = null; // reset child
                                }),
                                validator: (v) => v == null
                                    ? "Select business category"
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Type of Purchase (dependent)
                              DropdownButtonFormField<String>(
                                value: selectedTypePurchase,
                                decoration: const InputDecoration(
                                  labelText: "Type of Purchase",
                                  border: UnderlineInputBorder(),
                                ),
                                items: filteredPurchaseOptions
                                    .map((t) => DropdownMenuItem<String>(
                                          value: t["value"],
                                          child: Text(t["text"]!),
                                        ))
                                    .toList(),
                                onChanged: (val) => setState(() {
                                  selectedTypePurchase = val;
                                }),
                                validator: (v) => v == null
                                    ? "Select type of purchase"
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // District (from API)
                              FutureBuilder<List<Map<String, String>>>(
                                future: districtsFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8),
                                      child: LinearProgressIndicator(),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return const Text(
                                      "Error loading districts",
                                      style: TextStyle(color: Colors.red),
                                    );
                                  }
                                  final districts = snapshot.data ?? [];
                                  if (districts.isEmpty) {
                                    return const Text("No districts available");
                                  }
                                  return DropdownButtonFormField<String>(
                                    value: district,
                                    decoration: const InputDecoration(
                                      labelText: "District",
                                      border: UnderlineInputBorder(),
                                    ),
                                    items: districts
                                        .map((d) => DropdownMenuItem<String>(
                                              value: d["value"],
                                              child: Text(d["text"]!),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        district = val;
                                        division = null;
                                        divisionsFuture = LeadService()
                                            .getLeadDivision(
                                                val!); // fetch divisions dynamically
                                        blocksFuture = null; // reset blocks
                                      });
                                      if (val != null) {
                                        LeadService().getLeadDivision(val);
                                      }
                                    },
                                    validator: (v) =>
                                        v == null ? "Select district" : null,
                                  );
                                },
                              ),
                              const SizedBox(height: 12),

                              // Division Dropdown
                              if (divisionsFuture != null)
                                FutureBuilder<List<Map<String, String>>>(
                                  future: divisionsFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator();
                                    }
                                    if (snapshot.hasError) {
                                      return const Text(
                                          "Error loading divisions",
                                          style: TextStyle(color: Colors.red));
                                    }
                                    final divisions = snapshot.data ?? [];
                                    if (divisions.isEmpty) {
                                      return const Text(
                                          "No divisions available");
                                    }
                                    return DropdownButtonFormField<String>(
                                      value: division,
                                      decoration: const InputDecoration(
                                        labelText: "Division",
                                        border: UnderlineInputBorder(),
                                      ),
                                      items: divisions
                                          .map((d) => DropdownMenuItem<String>(
                                                value: d["value"],
                                                child: Text(d["text"]!),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          division = val;
                                          block = null;
                                          if (district != null &&
                                              division != null) {
                                            blocksFuture = LeadService()
                                                .getLeadBlocks(
                                                    district!, division!);
                                          }
                                        });
                                      },
                                      validator: (v) =>
                                          v == null ? "Select division" : null,
                                    );
                                  },
                                )
                              else
                                const SizedBox(),
                              const SizedBox(height: 12),

                              if (blocksFuture != null)
                                FutureBuilder<List<Map<String, String>>>(
                                  future: blocksFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator();
                                    }
                                    if (snapshot.hasError) {
                                      return const Text("Error loading blocks",
                                          style: TextStyle(color: Colors.red));
                                    }
                                    final blocks = snapshot.data ?? [];
                                    if (blocks.isEmpty) {
                                      return const Text("No blocks available");
                                    }
                                    return DropdownButtonFormField<String>(
                                      value: block,
                                      decoration: const InputDecoration(
                                        labelText: "Block",
                                        border: UnderlineInputBorder(),
                                      ),
                                      items: blocks
                                          .map((b) => DropdownMenuItem<String>(
                                                value: b["value"],
                                                child: Text(b["text"]!),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          block = val;
                                          village = null;
                                          if (district != null &&
                                              division != null &&
                                              block != null) {
                                            villagesFuture = LeadService()
                                                .getLeadVillages(district!,
                                                    division!, block!);
                                          }
                                        });
                                      },
                                      validator: (v) =>
                                          v == null ? "Select block" : null,
                                    );
                                  },
                                ),
                              const SizedBox(height: 12),

                              // Village
                              if (villagesFuture != null)
                                FutureBuilder<List<Map<String, String>>>(
                                  future: villagesFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator();
                                    }
                                    if (snapshot.hasError) {
                                      return const Text(
                                          "Error loading villages",
                                          style: TextStyle(color: Colors.red));
                                    }
                                    final villages = snapshot.data ?? [];
                                    if (villages.isEmpty) {
                                      return const Text(
                                          "No villages available");
                                    }
                                    return DropdownButtonFormField<String>(
                                      value: village,
                                      decoration: const InputDecoration(
                                        labelText: "Village",
                                        border: UnderlineInputBorder(),
                                      ),
                                      items: villages
                                          .map((v) => DropdownMenuItem<String>(
                                                value: v["value"],
                                                child: Text(v["text"]!),
                                              ))
                                          .toList(),
                                      onChanged: (val) =>
                                          setState(() => village = val),
                                      validator: (v) =>
                                          v == null ? "Select village" : null,
                                    );
                                  },
                                ),
                              const SizedBox(height: 12),

                              // Product
                              FutureBuilder<List<Map<String, String>>>(
                                future: productsFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const LinearProgressIndicator();
                                  }
                                  if (snapshot.hasError) {
                                    return const Text("Error loading products",
                                        style: TextStyle(color: Colors.red));
                                  }
                                  final products = snapshot.data ?? [];
                                  if (products.isEmpty) {
                                    return const Text("No products available");
                                  }
                                  return DropdownButtonFormField<String>(
                                    value: product,
                                    decoration: const InputDecoration(
                                      labelText: "Product",
                                      border: UnderlineInputBorder(),
                                    ),
                                    items: products
                                        .map((p) => DropdownMenuItem<String>(
                                              value: p["value"],
                                              child: Text(p["text"]!),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        product = val;
                                        machineName = null; // reset machine
                                        machineNamesFuture =
                                            null; // reset before fetch
                                      });
                                      if (val != null) {
                                        setState(() {
                                          machineNamesFuture = LeadService()
                                              .getMachineNames(val);
                                        });
                                      }
                                    },
                                    validator: (v) =>
                                        v == null ? "Select product" : null,
                                  );
                                },
                              ),
                              const SizedBox(height: 12),

                              // Machine Name
                              if (machineNamesFuture != null)
                                FutureBuilder<List<Map<String, String>>>(
                                  future: machineNamesFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator();
                                    }
                                    if (snapshot.hasError) {
                                      return const Text(
                                        "Error loading machine names",
                                        style: TextStyle(color: Colors.red),
                                      );
                                    }
                                    final machines = snapshot.data ?? [];
                                    if (machines.isEmpty) {
                                      return const Text(
                                          "No machine names available");
                                    }
                                    return DropdownButtonFormField<String>(
                                      value: machineName,
                                      decoration: const InputDecoration(
                                        labelText: "Machine Name",
                                        border: UnderlineInputBorder(),
                                      ),
                                      items: machines
                                          .map((m) => DropdownMenuItem<String>(
                                                value: m["value"],
                                                child: Text(m["text"]!),
                                              ))
                                          .toList(),
                                      onChanged: (val) =>
                                          setState(() => machineName = val),
                                      validator: (v) => v == null
                                          ? "Select machine name"
                                          : null,
                                    );
                                  },
                                )
                              else
                                const SizedBox(), // safe placeholder

                              const SizedBox(height: 12),

                              // Lead Reminder Date
                              TextFormField(
                                controller: reminderDateController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: "Lead Reminder Date",
                                  border: UnderlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                onTap: () async {
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (pickedDate != null) {
                                    reminderDateController.text =
                                        "${pickedDate.toLocal()}".split(' ')[0];
                                  }
                                },
                              ),
                              const SizedBox(height: 12),

                              // Remarks
                              TextFormField(
                                controller: remarksController,
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: UnderlineInputBorder(),
                                ),
                                maxLines: 3,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Remarks required'
                                        : null,
                              ),

                              const SizedBox(
                                  height: 80), // keep above fixed button
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ---------- Fixed Submit Button ----------
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // Collect all values into JSON
                          final Map<String, dynamic> formData = {
                            "leadId": leadId,
                            "phoneNumber": phoneNumber,
                            "farmerName": farmerNameController.text.trim(),
                            "leadCallStatus": selectedStatus,
                            "businessCategory": selectedBusinessCategory,
                            "typeOfPurchase": selectedTypePurchase,
                            "district": district,
                            "division": division ?? 0,
                            "block": block ?? 0,
                            "village": village ?? 0,
                            "product": product,
                            "machineName": machineName ?? 0,
                            "reminderDate": reminderDateController.text.trim(),
                            "remarks": remarksController.text.trim(),
                          };

                          // Print / send this JSON
                          debugPrint("Form JSON: ${jsonEncode(formData)}");

                          // Call your submit function
                          _onFeedbackSubmit(context, formData);
                        }
                      },
                      child: const Text(
                        "Submit",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
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
    // _showFeedbackPopup(context, leadId, '8902320323');
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

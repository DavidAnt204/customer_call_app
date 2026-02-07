import 'dart:convert';
import 'dart:ui'; // Required for BackdropFilter
import 'package:call_log/call_log.dart';
import 'package:customer_call/screens/task_list_screen.dart';
import 'package:customer_call/screens/view_lead_screen.dart' hide LeadService;
import 'package:flutter/material.dart';
import 'package:flutter_direct_call_plus/flutter_direct_call.dart';
import 'package:flutter_phone_call_state/flutter_phone_call_state.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../services/api_services.dart';
import '../services/helpers.dart';
import 'add_lead_screen.dart';
import 'create_task_screen.dart';

// --- Color and Style Constants (Trendy/M3 Look) ---
const Color primaryColor = Color(0xFF4169E1); // A vibrant Royal Blue
const Color onPrimary = Colors.white;
const Color secondaryColor = Color(0xFF64B5F6); // Lighter Blue for accents
const double cardRadius = 16.0;

// Reusable Status Chip Widget
class StatusChip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const StatusChip({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
  });

  // Determines if the color is dark enough to require white text
  bool _isDark(Color c) => c.computeLuminance() < 0.3;

  @override
  Widget build(BuildContext context) {
    final textColor = _isDark(color) ? onPrimary : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color, // Use the solid color for better visibility
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
// ------------------------------------------------

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
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    PhoneCallState.instance.phoneStateChange.listen((event) {
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
      SnackBar(
          content: Text(success
              ? '📘 Call history & notes saved successfully.'
              : '⚠️ Call history & notes save failed')),
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
        // Helper for modern outlined input fields
        InputDecoration _buildModernInputDecoration({
          required String labelText,
          IconData? icon,
        }) {
          return InputDecoration(
            labelText: labelText,
            // Use primaryColor for focus
            labelStyle: TextStyle(color: Colors.grey.shade600),
            floatingLabelStyle:
            const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
            suffixIcon: icon != null
                ? Icon(icon, color: primaryColor.withOpacity(0.7))
                : null,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2.0),
            ),
            filled: true,
            fillColor: Colors.white,
          );
        }

        return Dialog(
          insetPadding: EdgeInsets.zero,
          // Slightly rounded edges for a modern feel, but mostly full-screen
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              final List<Map<String, String>> filteredPurchaseOptions =
              (selectedBusinessCategory == "civil")
                  ? leadTypePurchase
                  .where((t) => t["value"] == "sales")
                  .toList()
                  : leadTypePurchase;

              return Column(
                children: [
                  // ---------- Trendy Header with Close Button ----------
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)), // Match dialog shape
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.only(
                        top: 8, bottom: 8, left: 16, right: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close Button
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.black87),
                          onPressed: () => Navigator.pop(context),
                          tooltip: "Close",
                        ),
                        // Title
                        Text(
                          "Call History Feedback",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // Placeholder for alignment
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.grey),

                  // ---------- Scrollable Form (Trendy Input Fields) ----------
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF5F7FA), // Light background for contrast
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Farmer Name
                              TextFormField(
                                controller: farmerNameController,
                                decoration: _buildModernInputDecoration(
                                  labelText: "Farmer Name",
                                  icon: Icons.person_rounded,
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? "Enter farmer name"
                                    : null,
                              ),
                              const SizedBox(height: 20),

                              // Lead Call Status
                              DropdownButtonFormField<String>(
                                value: selectedStatus,
                                decoration: _buildModernInputDecoration(
                                  labelText: "Lead Call Status",
                                  icon: Icons.call_end_rounded,
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
                                validator: (v) =>
                                v == null ? "Select lead call status" : null,
                              ),
                              const SizedBox(height: 20),

                              // Lead Business Category
                              DropdownButtonFormField<String>(
                                value: selectedBusinessCategory,
                                decoration: _buildModernInputDecoration(
                                  labelText: "Lead Business Category",
                                  icon: Icons.business_rounded,
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
                                validator: (v) =>
                                v == null ? "Select business category" : null,
                              ),
                              const SizedBox(height: 20),

                              // Type of Purchase (dependent)
                              DropdownButtonFormField<String>(
                                value: selectedTypePurchase,
                                decoration: _buildModernInputDecoration(
                                  labelText: "Type of Purchase",
                                  icon: Icons.shopping_bag_rounded,
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
                                validator: (v) =>
                                v == null ? "Select type of purchase" : null,
                              ),
                              const SizedBox(height: 20),

                              // District (from API)
                              FutureBuilder<List<Map<String, String>>>(
                                future: districtsFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: LinearProgressIndicator(
                                          color: primaryColor),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return const Text("Error loading districts",
                                        style: TextStyle(color: Colors.red));
                                  }
                                  final districts = snapshot.data ?? [];
                                  // Use the modern decoration helper
                                  return DropdownButtonFormField<String>(
                                    value: district,
                                    decoration: _buildModernInputDecoration(
                                      labelText: "District",
                                      icon: Icons.map_rounded,
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
                                            .getLeadDivision(val!);
                                        blocksFuture = null;
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
                              const SizedBox(height: 20),

                              // Division Dropdown
                              if (divisionsFuture != null)
                                FutureBuilder<List<Map<String, String>>>(
                                  future: divisionsFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator(
                                          color: primaryColor);
                                    }
                                    if (snapshot.hasError) {
                                      return const Text("Error loading divisions",
                                          style: TextStyle(color: Colors.red));
                                    }
                                    final divisions = snapshot.data ?? [];
                                    return DropdownButtonFormField<String>(
                                      value: division,
                                      decoration: _buildModernInputDecoration(
                                        labelText: "Division",
                                        icon: Icons.apartment_rounded,
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
                                                .getLeadBlocks(district!, division!);
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
                              const SizedBox(height: 20),

                              // Block Dropdown
                              if (blocksFuture != null)
                                FutureBuilder<List<Map<String, String>>>(
                                  future: blocksFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator(
                                          color: primaryColor);
                                    }
                                    if (snapshot.hasError) {
                                      return const Text("Error loading blocks",
                                          style: TextStyle(color: Colors.red));
                                    }
                                    final blocks = snapshot.data ?? [];
                                    return DropdownButtonFormField<String>(
                                      value: block,
                                      decoration: _buildModernInputDecoration(
                                        labelText: "Block",
                                        icon: Icons.location_city_rounded,
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
                                                .getLeadVillages(
                                                district!, division!, block!);
                                          }
                                        });
                                      },
                                      validator: (v) =>
                                      v == null ? "Select block" : null,
                                    );
                                  },
                                ),
                              const SizedBox(height: 20),

                              // Village Dropdown
                              if (villagesFuture != null)
                                FutureBuilder<List<Map<String, String>>>(
                                  future: villagesFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator(
                                          color: primaryColor);
                                    }
                                    if (snapshot.hasError) {
                                      return const Text("Error loading villages",
                                          style: TextStyle(color: Colors.red));
                                    }
                                    final villages = snapshot.data ?? [];
                                    return DropdownButtonFormField<String>(
                                      value: village,
                                      decoration: _buildModernInputDecoration(
                                        labelText: "Village",
                                        icon: Icons.home_work_rounded,
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
                              const SizedBox(height: 20),

                              // Product Dropdown
                              FutureBuilder<List<Map<String, String>>>(
                                future: productsFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const LinearProgressIndicator(
                                        color: primaryColor);
                                  }
                                  if (snapshot.hasError) {
                                    return const Text("Error loading products",
                                        style: TextStyle(color: Colors.red));
                                  }
                                  final products = snapshot.data ?? [];
                                  return DropdownButtonFormField<String>(
                                    value: product,
                                    decoration: _buildModernInputDecoration(
                                      labelText: "Product",
                                      icon: Icons.agriculture_rounded,
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
                                        machineName = null;
                                        machineNamesFuture = null;
                                      });
                                      if (val != null) {
                                        setState(() {
                                          machineNamesFuture =
                                              LeadService().getMachineNames(val);
                                        });
                                      }
                                    },
                                    validator: (v) =>
                                    v == null ? "Select product" : null,
                                  );
                                },
                              ),
                              const SizedBox(height: 20),

                              // Machine Name Dropdown
                              if (machineNamesFuture != null)
                                FutureBuilder<List<Map<String, String>>>(
                                  future: machineNamesFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator(
                                          color: primaryColor);
                                    }
                                    if (snapshot.hasError) {
                                      return const Text(
                                        "Error loading machine names",
                                        style: TextStyle(color: Colors.red),
                                      );
                                    }
                                    final machines = snapshot.data ?? [];
                                    return DropdownButtonFormField<String>(
                                      value: machineName,
                                      decoration: _buildModernInputDecoration(
                                        labelText: "Machine Name",
                                        icon: Icons.precision_manufacturing_rounded,
                                      ),
                                      items: machines
                                          .map((m) => DropdownMenuItem<String>(
                                        value: m["value"],
                                        child: Text(m["text"]!),
                                      ))
                                          .toList(),
                                      onChanged: (val) =>
                                          setState(() => machineName = val),
                                      validator: (v) =>
                                      v == null ? "Select machine name" : null,
                                    );
                                  },
                                )
                              else
                                const SizedBox(),

                              const SizedBox(height: 20),

                              // Lead Reminder Date
                              TextFormField(
                                controller: reminderDateController,
                                readOnly: true,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                decoration: _buildModernInputDecoration(
                                  labelText: "Lead Reminder Date",
                                  icon: Icons.calendar_today_rounded,
                                ),
                                onTap: () async {
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    builder: (context, child) {
                                      return Theme(
                                        data: ThemeData.light().copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: primaryColor, // header background color
                                            onPrimary: Colors.white, // header text color
                                            onSurface: Colors.black, // body text color
                                          ),
                                          textButtonTheme: TextButtonThemeData(
                                            style: TextButton.styleFrom(
                                              foregroundColor: primaryColor, // button text color
                                            ),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (pickedDate != null) {
                                    reminderDateController.text =
                                    "${pickedDate.toLocal()}".split(' ')[0];
                                  }
                                },
                              ),
                              const SizedBox(height: 20),

                              // Remarks
                              TextFormField(
                                controller: remarksController,
                                decoration: _buildModernInputDecoration(
                                  labelText: "Remarks",
                                  icon: Icons.comment_rounded,
                                ),
                                maxLines: 3,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Remarks required'
                                    : null,
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ---------- Fixed Submit Button (Trendy Footer) ----------
                  Container(
                    width: double.infinity,
                    // Slightly lighter color for the footer area
                    color: const Color(0xFFF5F7FA),
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, top: 10, bottom: 20),
                    child: SizedBox(
                      height: 54, // Taller button
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          elevation: 8,
                          shadowColor: primaryColor.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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

                            // Call your submit function
                            _onFeedbackSubmit(context, formData);
                          }
                        },
                        child: const Text(
                          "SUBMIT CALL FEEDBACK",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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

  // --- New Modal Bottom Sheet for Status Selection (Better UX) ---
  void _showStatusSelector(BuildContext context, Lead lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to use full height if needed
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Fixes potential overflow by minimizing size
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Change Status for ${lead.name}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              // Use flexible and check if it exceeds a certain height (e.g., 400.0)
              // Since ListView.builder with shrinkWrap is inside mainAxisSize.min column, it should behave correctly.
              ListView.builder(
                shrinkWrap: true,
                itemCount: statusList.length,
                physics: const ClampingScrollPhysics(), // Ensures proper scrolling behavior
                itemBuilder: (context, index) {
                  final status = statusList[index];
                  final isSelected = status.name == lead.statusName;
                  final statusColor = _getStatusColor(status.name);
                  final statusIcon = _getStatusIcon(status.name);

                  return ListTile(
                    leading: Icon(statusIcon, color: statusColor),
                    title: Text(status.name,
                        style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? primaryColor : Colors.black)),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () async {
                      Navigator.pop(context); // Close sheet immediately
                      if (status.name == lead.statusName) return;

                      final confirm = await confirmStatusChange(status.name);
                      if (confirm != true) return;

                      final success = await updateLeadStatus(lead.id, status.id);

                      if (success) {
                        setState(() {
                          lead.statusName = status.name;
                          lead.statusId = status.id;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                              Text('Status updated to "${status.name}"')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Failed to update status')),
                        );
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<List<Lead>> fetchLeads() async {
    // NOTE: Hardcoded URL should be moved to a configuration file or environment
    final res = await http
        .get(Uri.parse('https://crm.vasaantham.com/api/get_leads_by_id/12'));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => Lead.fromJson(e)).toList();
    }
    throw Exception('Failed to load leads');
  }

  Future<List<LeadStatus>> fetchStatuses() async {
    // NOTE: Hardcoded URL should be moved to a configuration file or environment
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

    leadsFuture = fetchLeads();
    statusFuture = fetchStatuses();

    await Future.wait([leadsFuture, statusFuture]);

    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _refresh() async {
    _loadData();
    await Future.wait([leadsFuture, statusFuture]);
    setState(() {});
  }

  Future<bool> updateLeadStatus(String leadId, String statusId) async {
    // NOTE: Hardcoded URL should be moved to a configuration file or environment
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

  // --- Styling Logic ---
  Color _getStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return const Color(0xFF1B5E20); // Darker Green
      case 'new':
        return primaryColor; // Primary Blue
      case 'pending':
        return const Color(0xFFFF9800); // Yellowish Orange (Requested change)
      case 'in progress':
        return const Color(0xFF512DA8); // Deep Purple
      case 'rejected':
        return const Color(0xFFB71C1C); // Dark Red
      case 'accepted':
        return const Color(0xFF00695C); // Dark Teal
      case 'maintenance':
        return const Color(0xFF4E342E); // Dark Brown
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getStatusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'new':
        return Icons.star_border_rounded;
      case 'pending':
        return Icons.access_time_filled_rounded;
      case 'in progress':
        return Icons.rotate_right_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'accepted':
        return Icons.thumb_up_alt_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      default:
        return Icons.help_center_rounded;
    }
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

    _currentCallLeadId = leadId;

    await FlutterDirectCall.makeDirectCall(phone);
  }
  // ------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Get the standard height of the AppBar
    final double appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;

    return Scaffold(
      // CRITICAL: Extends the body under the AppBar for the glassy effect
      extendBodyBehindAppBar: true,

      // Glassy Header (AppBar) Implementation
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // The Blur effect
            child: AppBar(
              title: const Text('Leads',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)), // Visible title color
              actions: [
                // Add Lead Icon
                IconButton(
                  icon: const Icon(Icons.add_rounded,
                      size: 28, color: primaryColor), // Clearly visible icon color
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddLeadScreen(
                            leadId: '--',
                          )),
                    );
                  },
                  tooltip: 'Add New Lead',
                ),
                const SizedBox(width: 8),
              ],
              // Semi-transparent background for the glassy look
              backgroundColor: Colors.white.withOpacity(0.6),
              elevation: 0,
              foregroundColor: Colors.black,
            ),
          ),
        ),
      ),

      // Body content, pushed down by the AppBar height
      body: Padding(
        padding: EdgeInsets.only(top: appBarHeight),
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([leadsFuture, statusFuture]),
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: primaryColor));
            }
            if (snap.hasError) {
              return Center(
                  child: Text('Error: ${snap.error}',
                      style: TextStyle(color: Colors.red.shade700)));
            }

            final leads = snap.data![0] as List<Lead>;
            statusList = snap.data![1] as List<LeadStatus>;

            if (leads.isEmpty)
              return const Center(
                  child: Text('No leads found',
                      style: TextStyle(fontSize: 16, color: Colors.black54)));

            return RefreshIndicator(
                onRefresh: _refresh,
                color: primaryColor,
                child: _isRefreshing
                    ? const Center(
                    child: CircularProgressIndicator(color: primaryColor))
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: leads.length,
                  separatorBuilder: (i, _) =>
                  const SizedBox(height: 16), // Increased spacing
                  itemBuilder: (context, index) {
                    final lead = leads[index];
                    final statusColor = _getStatusColor(lead.statusName);
                    final statusIcon = _getStatusIcon(lead.statusName);

                    return Card(
                      // Requested Card Background Color: White
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(cardRadius)),
                      elevation: 4, // Slightly higher elevation
                      clipBehavior: Clip.antiAlias, // For clean borders

                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar Icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor.withOpacity(0.1),
                                    border: Border.all(
                                        color: primaryColor, width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    lead.name.isNotEmpty
                                        ? lead.name[0].toUpperCase()
                                        : 'L',
                                    style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Content (Name & Phone)
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
                                          fontWeight: FontWeight.w700,
                                          color: primaryColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),

                                      // Phone Row
                                      Row(
                                        children: [
                                          const Icon(
                                              Icons.phone_android_rounded,
                                              size: 16,
                                              color: Colors.black54),
                                          const SizedBox(width: 8),
                                          Text(
                                            lead.phoneNumber,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      // TODO: Navigate to Add Task screen
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AddTaskScreen(
                                                leadId: int.parse(lead.id),
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.add_task_rounded, size: 18),
                                    label: const Text('Add Task'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      // TODO: Navigate to Task List screen
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TaskListScreen(leadId: int.parse(lead.id)),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.list_alt_rounded, size: 18),
                                    label: const Text('Task List'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: const BorderSide(color: primaryColor),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(
                                height: 1, color: Colors.black12),
                            const SizedBox(height: 16),

                            // Status Dropdown and Action Buttons
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                // Status Chip (Tap target to open bottom sheet)
                                Expanded(
                                  child: InkWell(
                                    onTap: () =>
                                        _showStatusSelector(context, lead),
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    child: StatusChip(
                                      color: statusColor,
                                      icon: statusIcon,
                                      text: lead.statusName,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12), // Compact spacing

                                // Action Icons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. Call Button
                                    IconButton(
                                      icon: const Icon(Icons.call_rounded,
                                          color: Colors.green, size: 24),
                                      onPressed: () => makeCall(
                                          lead.phoneNumber,
                                          lead.statusName,
                                          lead.id),
                                      tooltip: 'Call Lead',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),

                                    // 2. Edit Button
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded,
                                          color: secondaryColor, size: 24),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddLeadScreen(
                                                  leadId: lead.id,
                                                ),
                                          ),
                                        );
                                      },
                                      tooltip: 'Edit Lead',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),

                                    // 3. View Button
                                    IconButton(
                                      icon: const Icon(
                                          Icons.visibility_rounded,
                                          color: primaryColor,
                                          size: 24),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                LeadDetailsPage(
                                                  leadId: lead.id,
                                                ),
                                          ),
                                        );
                                      },
                                      tooltip: 'View Details',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ));
          },
        ),
      ),
    );
  }
}

// --- Lead Data Classes (Unchanged for API functionality) ---

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
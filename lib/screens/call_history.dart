import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:core'; // Ensure core types are available

// Assuming 'helpers.dart' provides formatDuration.
// Defining a local helper for completeness in this file.

// --- Design Constants ---
const Color primaryColor = Color(0xFF4169E1); // Royal Blue
const Color lightBg = Color(0xFFF3F5F9);
const Color darkBg = Color(0xFF121212);
const double cardRadius = 16.0;

// --- Helper Functions (Modernized & Assumed from 'helpers.dart') ---

String formatDuration(int? duration) {
  if (duration == null || duration <= 0) return "0s";
  final dur = Duration(seconds: duration);
  if (dur.inHours > 0) {
    return '${dur.inHours}h ${dur.inMinutes.remainder(60)}m';
  } else if (dur.inMinutes > 0) {
    return '${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s';
  } else {
    return '${dur.inSeconds}s';
  }
}

Map<DateTime, List<CallLogEntry>> _groupEntriesByDate(List<CallLogEntry> entries) {
  final Map<DateTime, List<CallLogEntry>> grouped = {};
  for (var entry in entries) {
    final timestamp = entry.timestamp;
    if (timestamp != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final key = DateTime(date.year, date.month, date.day);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(entry);
    }
  }
  return grouped;
}

String _formatDateHeader(DateTime date) {
  if (DateUtils.isSameDay(date, DateTime.now())) {
    return 'Today';
  } else if (DateUtils.isSameDay(date, DateTime.now().subtract(const Duration(days: 1)))) {
    return 'Yesterday';
  } else {
    return DateFormat('EEEE, MMM d, y').format(date);
  }
}

// Helper to get call type details for styling
(IconData, Color, String) _getCallTypeDetails(CallType? type) {
  switch (type) {
    case CallType.incoming:
      return (Icons.call_received_rounded, Colors.green.shade600, "Incoming");
    case CallType.outgoing:
      return (Icons.call_made_rounded, primaryColor, "Outgoing");
    case CallType.missed:
      return (Icons.call_missed_rounded, Colors.red.shade600, "Missed");
    case CallType.rejected:
      return (Icons.call_end_rounded, Colors.red.shade800, "Rejected");
    default:
      return (Icons.phone_android_rounded, Colors.grey.shade600, "Unknown");
  }
}

// --- Main Page Implementation ---

class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({super.key});

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

  // --- Core Functionality (Preserved) ---
  Future<void> _initializeAndLoad() async {
    // Hive.initFlutter() is called here as in original code
    await Hive.initFlutter();
    final box = await Hive.openBox('myBox');

    final rawData = box.get('staffinfo');
    final staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);
    staffId = staffInfo['staffid']?.toString();

    if (staffId == null) {
      if (mounted) setState(() => _loading = false);
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
      // Print or log the error, but do not block the UI
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
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      Iterable<CallLogEntry> entries = await CallLog.get();
      final filtered = _filterByLeadNumbers(entries.toList());

      if (mounted) {
        setState(() {
          _callLogs = _removeDuplicateTimestamps(filtered)
            ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
          _loading = false;
        });
      }
    } catch (e) {
      print('Failed to get call logs: $e');
      if (mounted) setState(() => _loading = false);
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
  // --- End Core Functionality ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? darkBg : lightBg;
    final Map<DateTime, List<CallLogEntry>> groupedEntries = _groupEntriesByDate(_callLogs);

    if (_loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Call History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 24, color: isDark ? Colors.white : Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadCallLogs,
        color: primaryColor,
        child: _callLogs.isEmpty
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              "No filtered call history available.\nCalls must match one of your assigned leads.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        )
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: groupedEntries.keys.length,
          itemBuilder: (context, index) {
            final date = groupedEntries.keys.elementAt(index);
            final calls = groupedEntries[date]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Header
                Padding(
                  padding: const EdgeInsets.only(top: 18.0, bottom: 8.0),
                  child: Text(
                    _formatDateHeader(date),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
                // List of calls for that date
                ...calls.map((entry) => _buildCallEntryTile(entry, isDark)).toList(),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- REDESIGNED CALL ENTRY TILE ---
  Widget _buildCallEntryTile(CallLogEntry entry, bool isDark) {
    final title = (entry.name?.isNotEmpty == true) ? entry.name! : (entry.number?.trim().isNotEmpty == true ? entry.number! : "Unknown");
    final subTitle = (entry.name?.isNotEmpty == true) ? entry.number : entry.number;

    final (icon, color, typeLabel) = _getCallTypeDetails(entry.callType);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      elevation: isDark ? 0 : 4,
      color: isDark ? Colors.grey[900] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Call Type Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),

            // Name, Number, and Type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    typeLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Trailing Actions (Info and Call)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Button
                IconButton(
                  icon: Icon(Icons.info_outline, color: Colors.grey.shade600),
                  onPressed: () => showCallDetailsBottomSheet(context, entry, isDark),
                  tooltip: 'View details',
                ),
                // Call Back Button
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _showCallConfirmationDialog(context, entry),
                  tooltip: 'Call back',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- INTERACTION WIDGETS (Modernized) ---

  void _showCallConfirmationDialog(BuildContext context, CallLogEntry call) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        title: Text(
          "Call ${call.number ?? 'Unknown'}?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          "Are you sure you want to call this number?",
          style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement call logic here (e.g., using flutter_direct_call_plus)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling ${call.number}... (Logic to be implemented)')),
              );
            },
            child: Text("Call", style: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void showCallDetailsBottomSheet(BuildContext context, CallLogEntry call, bool isDark) {
    final (icon, color, typeLabel) = _getCallTypeDetails(call.callType);
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
      ),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(icon, color: color, size: 30),
                  const SizedBox(width: 15),
                  Text("Call Details",
                      style: GoogleFonts.poppins(
                          fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              const Divider(height: 30),

              // Detail List
              _buildDetailRow("Name/Number", call.name ?? call.number ?? "Unknown", Icons.person_outline, isDark),
              _buildDetailRow("Type", typeLabel, Icons.call, isDark, valueColor: color),
              _buildDetailRow("Date", DateFormat('MMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(call.timestamp!)), Icons.calendar_today_outlined, isDark),
              _buildDetailRow("Time", DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(call.timestamp!)), Icons.access_time_outlined, isDark),
              _buildDetailRow("Duration", formatDuration(call.duration), Icons.timer_outlined, isDark),

              const SizedBox(height: 30),

              // Close Button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: Text("Close", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String title, String value, IconData icon, bool isDark, {Color? valueColor}) {
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final valColor = valueColor ?? (isDark ? Colors.white : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 22, color: primaryColor),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 13, color: labelColor)),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: valColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
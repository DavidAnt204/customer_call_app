import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../services/api_services.dart';
import 'punch_in_out_screen.dart';

// --- Design & Color Constants ---
const Color primaryColor = Color(0xFF4169E1); // Royal Blue
const Color accentColor = Color(0xFF00C6FF); // Bright Cyan
const Color bgColor = Color(0xFFF5F7FA); // Light background
const Color cardColor = Colors.white;
const double cardRadius = 18.0;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Functionality Preserved: Initialization
  AttendanceService _attendanceService = AttendanceService();
  Attendance? _attendance;

  DateTime? punchInTime;
  DateTime? punchOutTime;
  String? punchLocation;
  String? userName;
  Map<String, dynamic>? staffInfo;

  @override
  void initState() {
    super.initState();
    getUserInfo();
    _loadAttendance();
  }

  // Functionality Preserved: Swipe Refresh Handler
  Future<void> _onRefresh() async {
    await _loadAttendance();
  }

  // Functionality Preserved: Data Fetching
  getUserInfo() {
    final box = Hive.box('myBox');
    final dynamic rawData = box.get('staffinfo');
    staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);

    userName = (staffInfo!['firstname'] ?? '') + ' ' + (staffInfo!['lastname'] ?? '');
    return staffInfo;
  }

  // Functionality Preserved: Attendance Loading
  _loadAttendance() async {
    if (staffInfo != null && staffInfo!['staffid'] != null) {
      // Assuming Attendance is defined in api_services.dart
      Attendance? attendance = await _attendanceService.getTodayAttendance(staffInfo!['staffid']);
      if (mounted) {
        setState(() {
          _attendance = attendance;
          punchInTime = DateTime.tryParse(_attendance?.punchIn ?? '');
          punchOutTime = DateTime.tryParse(_attendance?.punchOut ?? '');
          punchLocation = _attendance?.punchInLocation ?? '';
        });
      }
    }
  }

  // Functionality Preserved: Punch Action Handler
  void handlePunchAction() async {
    final DateTime? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PunchInOutScreen(
          isPunchIn: punchInTime == null || punchOutTime != null,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (punchInTime == null || punchOutTime != null) {
          punchInTime = result;
          punchOutTime = null;
        } else {
          punchOutTime = result;
        }
        _loadAttendance();
      });
    }
  }

  // Functionality Preserved: Time Formatting
  String formatTime(DateTime? time) {
    if (time == null) return "--:--";
    return DateFormat('hh:mm').format(time);
  }

  String formatMeridiem(DateTime? time) {
    if (time == null) return "";
    return DateFormat('a').format(time); // 'AM' or 'PM'
  }

  // --- WIDGETS ---

  Widget _buildGreetingHeader(String userName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Welcome back,",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(userName,
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.waving_hand, color: Color(0xFFF4C542), size: 20),
                  ],
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: cardColor,
            child: Icon(Icons.person_rounded, color: primaryColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget buildAttendanceCard() {
    final bool hasPunchedIn = punchInTime != null && punchOutTime == null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      elevation: 8,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Attendance Status',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
            const Divider(height: 20, thickness: 1),

            Row(
              children: [
                // Time Display
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Punch In
                      _buildTimeStatus(
                        'Punch In',
                        punchInTime,
                        Icons.login_rounded,
                        primaryColor,
                      ),
                      // Divider
                      Container(width: 1, height: 60, color: Colors.grey.shade200),
                      // Punch Out
                      _buildTimeStatus(
                        'Punch Out',
                        punchOutTime,
                        Icons.logout_rounded,
                        Colors.redAccent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 15),

                // Punch Button
                InkWell(
                  onTap: handlePunchAction,
                  borderRadius: BorderRadius.circular(cardRadius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasPunchedIn ? [Colors.redAccent, Colors.red.shade700] : [accentColor, primaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: hasPunchedIn ? Colors.red.withOpacity(0.3) : primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(hasPunchedIn ? Icons.logout_rounded : Icons.login_rounded, color: Colors.white, size: 30),
                        const SizedBox(height: 8),
                        Text(hasPunchedIn ? "Punch Out" : "Punch In",
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            // Location Info
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    punchLocation?.isNotEmpty == true ? punchLocation! : 'Location not recorded.',
                    style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeStatus(String label, DateTime? time, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color.withOpacity(0.7)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(formatTime(time),
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(width: 4),
            Text(formatMeridiem(time),
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
          ],
        ),
      ],
    );
  }

  // --- MODIFIED: Reduced padding and font size ---
  Widget buildStatCard(String value, String title, {Color startColor = primaryColor, Color endColor = accentColor}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius),
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: endColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        // REDUCED VERTICAL PADDING FROM 20 TO 15
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget buildQuickActionCard(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(cardRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardRadius),
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Flexible(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSalesActivityItem(String name, String status) {
    Color statusColor;
    switch (status) {
      case 'Meeting':
        statusColor = Colors.orange.shade700;
        break;
      case 'Follow-up':
        statusColor = primaryColor;
        break;
      case 'Contacted':
      default:
        statusColor = Colors.green.shade600;
        break;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.15),
          child: Icon(Icons.person, color: statusColor),
        ),
        title: Text(name,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
        subtitle: Text(status,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              expandedHeight: 100.0,
              toolbarHeight: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.zero,
                centerTitle: false,
                title: _buildGreetingHeader(userName ?? 'User'),
              ),
              backgroundColor: primaryColor,
            ),

            SliverList(
              delegate: SliverChildListDelegate(
                [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Attendance Card
                        buildAttendanceCard(),
                        const SizedBox(height: 24),

                        // 2. Stat Cards (Performance Overview)
                        Text('Performance Overview',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            buildStatCard('245', 'Total Leads', startColor: primaryColor, endColor: accentColor),
                            buildStatCard('56', 'New Leads', startColor: Colors.deepPurple, endColor: Colors.purpleAccent),
                            buildStatCard('34', 'Opportunities', startColor: Colors.teal, endColor: Colors.tealAccent.shade400),
                            buildStatCard('12', 'Closed Deals', startColor: Colors.orange, endColor: Colors.pinkAccent),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 3. Quick Actions
                        // Text('Quick Actions',
                        //     style: GoogleFonts.poppins(
                        //         fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
                        // const SizedBox(height: 12),
                        // GridView.count(
                        //   shrinkWrap: true,
                        //   crossAxisCount: 4,
                        //   crossAxisSpacing: 10,
                        //   mainAxisSpacing: 10,
                        //   childAspectRatio: 0.7,
                        //   physics: const NeverScrollableScrollPhysics(),
                        //   children: [
                        //     buildQuickActionCard(Icons.add, 'Add Lead', Colors.green.shade600),
                        //     buildQuickActionCard(Icons.calendar_today, 'Add Event', Colors.orange.shade600),
                        //     buildQuickActionCard(Icons.list, 'Add Task', primaryColor),
                        //     buildQuickActionCard(Icons.note, 'Add Note', Colors.pink.shade600),
                        //   ],
                        // ),

                        const SizedBox(height: 24),

                        // 4. Sales Activity
                        Text('Recent Sales Activities',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
                        const SizedBox(height: 12),

                        buildSalesActivityItem('John Doe', 'Contacted'),
                        buildSalesActivityItem('Sarah Smith', 'Meeting'),
                        buildSalesActivityItem('Michael Brown', 'Follow-up'),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
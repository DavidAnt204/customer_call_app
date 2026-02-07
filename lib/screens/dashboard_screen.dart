import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'punch_in_out_screen.dart';

const Color primaryColor = Color(0xFF4169E1);
const Color accentColor = Color(0xFF00C6FF);
const Color bgColor = Color(0xFFF5F7FA);
const double cardRadius = 16.0;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? staffInfo;
  String? userName;

  Map<String, dynamic> myLeads = {};
  Map<String, dynamic> myTasks = {};
  Map<String, dynamic> today = {};

  bool isLoading = true;

  DateTime? punchInTime;
  DateTime? punchOutTime;
  String? punchLocation;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadDashboard();
  }

  Future<void> _onRefresh() async {
    await _loadDashboard();
  }

  void _loadUserInfo() {
    final box = Hive.box('myBox');
    final dynamic rawData = box.get('staffinfo');
    staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);
    userName =
        (staffInfo?['firstname'] ?? '') + ' ' + (staffInfo?['lastname'] ?? '');
  }

  Future<void> _loadDashboard() async {
    if (staffInfo == null) return;
    setState(() => isLoading = true);
    final staffId = staffInfo!['staffid'];
    final res = await http.get(
      Uri.parse('https://crm.vasaantham.com/api/dashboard/$staffId'),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        myLeads = Map<String, dynamic>.from(data['my_leads'] ?? {});
        myTasks = Map<String, dynamic>.from(data['my_tasks'] ?? {});
        today = Map<String, dynamic>.from(data['today'] ?? {});
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

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
      });
    }
  }

  String formatTime(DateTime? time) {
    if (time == null) return "--:--";
    return DateFormat('hh:mm').format(time);
  }

  String formatMeridiem(DateTime? time) {
    if (time == null) return "";
    return DateFormat('a').format(time);
  }

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
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 2),
                Text(userName,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
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
      color: Colors.white,
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
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimeStatus('Punch In', punchInTime, Icons.login_rounded, primaryColor),
                      Container(width: 1, height: 60, color: Colors.grey.shade200),
                      _buildTimeStatus('Punch Out', punchOutTime, Icons.logout_rounded, Colors.redAccent),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
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
                        Icon(hasPunchedIn ? Icons.logout_rounded : Icons.login_rounded,
                            color: Colors.white, size: 30),
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

  Widget _buildLeadCard(String title, String value, Color startColor, Color endColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius),
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: endColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500)),
          Text(value,
              style: GoogleFonts.poppins(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.poppins(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFullWidthCard(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Text(label + ": $value",
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No data available', style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16)),
        ],
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
              expandedHeight: 100,
              toolbarHeight: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.zero,
                title: _buildGreetingHeader(userName ?? "User"),
              ),
              backgroundColor: primaryColor,
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildAttendanceCard(),
                        const SizedBox(height: 20),

                        // My Leads List
                        _buildSectionTitle("My Leads"),
                        isLoading
                            ? const Center(child: CircularProgressIndicator(color: primaryColor))
                            : myLeads.isEmpty
                            ? _buildEmptyState()
                            : ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildLeadCard("Total Leads", "${myLeads['total'] ?? 0}", Colors.deepPurple, Colors.purpleAccent),
                            _buildLeadCard("Open Leads", "${myLeads['open'] ?? 0}", Colors.teal, Colors.tealAccent),
                            _buildLeadCard("Converted Leads", "${myLeads['converted'] ?? 0}", Colors.orange, Colors.orangeAccent),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // My Tasks Grid
                        _buildSectionTitle("My Tasks"),
                        isLoading
                            ? const Center(child: CircularProgressIndicator(color: primaryColor))
                            : myTasks.isEmpty
                            ? _buildEmptyState()
                            : GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildTaskCard("Total Tasks", "${myTasks['total'] ?? 0}", Colors.indigo),
                            _buildTaskCard("Pending", "${myTasks['pending'] ?? 0}", Colors.orange),
                            _buildTaskCard("Completed", "${myTasks['completed'] ?? 0}", Colors.green),
                            _buildTaskCard("Due Today", "${myTasks['due_today'] ?? 0}", Colors.redAccent),
                            _buildTaskCard("Overdue", "${myTasks['overdue'] ?? 0}", Colors.pinkAccent),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Today Section
                        _buildSectionTitle("Today"),
                        isLoading
                            ? const Center(child: CircularProgressIndicator(color: primaryColor))
                            : today.isEmpty
                            ? _buildEmptyState()
                            : Column(
                          children: [
                            _buildFullWidthCard("Leads Added Today", "${today['leads_added'] ?? 0}", Colors.blue),
                            _buildFullWidthCard("Tasks Added Today", "${today['tasks_added'] ?? 0}", Colors.green),
                          ],
                        ),
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

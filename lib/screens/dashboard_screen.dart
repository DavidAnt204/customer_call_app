import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../services/api_services.dart';
import 'punch_in_out_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // String userName = "John Doe";
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

  getUserInfo() {
    final box = Hive.box('myBox');
    final dynamic rawData = box.get('staffinfo');
    staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);

    userName =
        (staffInfo!['firstname'] ?? '') + ' ' + (staffInfo!['lastname'] ?? '');

    return staffInfo;
  }

  _loadAttendance() async {
    Attendance? attendance =
        await _attendanceService.getTodayAttendance(staffInfo!['staffid']);
    setState(() {
      _attendance = attendance!;
      punchInTime = DateTime.tryParse(_attendance!.punchIn ?? '');
      punchOutTime = DateTime.tryParse(_attendance!.punchOut ?? '');
      punchLocation = _attendance!.punchInLocation ?? '';
    });
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
    if (result != null) {
      setState(() {
        if (punchInTime == null || punchOutTime != null) {
          // Punch In
          punchInTime = result;
          punchOutTime = null;
        } else {
          // Punch Out
          punchOutTime = result;
        }
      });
    }
    // setState(() {
    //   if (punchInTime == null) {
    //     // Simulate punch in
    //     punchInTime = DateTime.now();
    //     punchOutTime = null;
    //   } else {
    //     // Simulate punch out
    //     punchOutTime = DateTime.now();
    //   }
    // });
  }

  String formatTime(DateTime? time) {
    if (time == null) return "--:--";
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}";
  }

  Widget buildAttendanceCard() {
    final bool hasPunchedIn = punchInTime != null && punchOutTime == null;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Match quick actions
      ),
      color: Colors.white, // Match quick actions
      elevation: 3, // Match quick actions
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Punch In/Out section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Punch In",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            formatTime(punchInTime),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Punch Out",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            formatTime(punchOutTime),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Right side: Button
                GestureDetector(
                  onTap: handlePunchAction,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasPunchedIn ? Icons.logout : Icons.login,
                          color: Colors.white,
                          size: 30,
                        ),
                        SizedBox(height: 8),
                        Text(
                          hasPunchedIn ? "Punch Out" : "Punch In",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Location (Full width)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.blue),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    punchLocation ?? '--',
                    style: TextStyle(color: Colors.black54),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: EdgeInsets.all(16),
        width: double.infinity,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA), // Light background like image
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final fontSize = screenWidth > 400 ? 20.0 : 16.0;

            return Row(
              children: [
                Text(
                  "Welcome, ",
                  style: TextStyle(fontSize: fontSize, color: Colors.white),
                ),
                Text(
                  userName!,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.waving_hand,
                  size: fontSize + 2,
                  color: Color(0xFFF4C542),
                ),
              ],
            );
          },
        ),
        // Text(
        //   'Dashboard',
        //   style: TextStyle(
        //     color: Colors.white,
        //     fontWeight: FontWeight.bold,
        //     fontSize: 20,
        //   ),
        // ),
        backgroundColor: Color(0xFF2A6BC8), // Blue header background from image
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Color(0xFF1E57B7),
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildAttendanceCard(),
              SizedBox(height: 24),

              // Stats cards grid (Total Leads, New Leads, Opportunities, Closed Deals)
              // GridView.count(
              //   shrinkWrap: true,
              //   crossAxisCount: 2,
              //   crossAxisSpacing: 12,
              //   mainAxisSpacing: 12,
              //   physics: NeverScrollableScrollPhysics(),
              //   children: [
              //     buildStatCardNew('245', 'Total Leads'),
              //     buildStatCardNew('56', 'New Leads'),
              //     buildStatCardNew('34', 'Opportunities'),
              //     buildStatCardNew('12', 'Closed Deals'),
              //   ],
              // ),
              //
              // SizedBox(height: 24),
              // Text(
              //   'Quick Actions',
              //   style: TextStyle(
              //     fontWeight: FontWeight.bold,
              //     fontSize: 18,
              //     color: Color(0xFF1F2F5C),
              //   ),
              // ),
              // SizedBox(height: 12),
              //
              // // Quick actions grid
              // GridView.count(
              //   shrinkWrap: true,
              //   crossAxisCount: 2,
              //   crossAxisSpacing: 12,
              //   mainAxisSpacing: 12,
              //   physics: NeverScrollableScrollPhysics(),
              //   // childAspectRatio: 2.8,
              //   children: [
              //     buildQuickActionCard(Icons.add, 'Add Lead'),
              //     buildQuickActionCard(Icons.calendar_today, 'Add Event'),
              //     buildQuickActionCard(Icons.list, 'Add Task'),
              //     buildQuickActionCard(Icons.note, 'Add Note'),
              //   ],
              // ),
              //
              // SizedBox(height: 24),
              // Text(
              //   'Sales Activities',
              //   style: TextStyle(
              //     fontWeight: FontWeight.bold,
              //     fontSize: 18,
              //     color: Color(0xFF1F2F5C),
              //   ),
              // ),
              // SizedBox(height: 12),

              // Sales activities list
              // buildSalesActivityItem('John Doe', 'Contacted'),
              // buildSalesActivityItem('Sarah Smith', 'Meeting'),
              // buildSalesActivityItem('Michael Brown', 'Follow-up'),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildStatCardNew(String value, String title) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2F5C),
              ),
            ),
            SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF1F2F5C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildQuickActionCard(IconData icon, String label) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Color(0xFF2A6BC8), size: 28),
            SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF1F2F5C),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSalesActivityItem(String name, String status) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(0xFF2A6BC8),
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2F5C),
          ),
        ),
        subtitle: Text(
          status,
          style: TextStyle(
            color: Color(0xFF64798A),
          ),
        ),
      ),
    );
  }
}

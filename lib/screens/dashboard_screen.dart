import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'punch_in_out_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // String userName = "John Doe";

  DateTime? punchInTime;
  DateTime? punchOutTime;

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Container(
        padding: EdgeInsets.all(16),
        width: double.infinity,
        child: Row(
          children: [
            // Left side: Punch In/Out info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Punch In",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54)),
                  SizedBox(height: 4),
                  Text(formatTime(punchInTime),
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text("Punch Out",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54)),
                  SizedBox(height: 4),
                  Text(formatTime(punchOutTime),
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.blue),
                      SizedBox(width: 4),
                      Text("In office",
                          style: TextStyle(color: Colors.black54)),
                    ],
                  )
                ],
              ),
            ),

            // Right side: Punch In / Out button
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
            )
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
    final box = Hive.box('myBox');
    final dynamic rawData = box.get('staffinfo');
    final Map<String, dynamic> staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);

    final userName =
        (staffInfo['firstname'] ?? '') + ' ' + (staffInfo['lastname'] ?? '');

    return Scaffold(
      appBar: AppBar(
          title: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final fontSize = screenWidth > 400 ? 20.0 : 16.0;

              return Row(
                children: [
                  Text(
                    "Welcome, ",
                    style: TextStyle(fontSize: fontSize),
                  ),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
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
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Attendance Punch In/Out Card
            buildAttendanceCard(),
            SizedBox(height: 24),

            // Optional Stats
            buildStatCard(
                'Attendance', '22 Days', Icons.calendar_today, Colors.blue),
            buildStatCard(
                'Leaves Taken', '2 Days', Icons.beach_access, Colors.orange),
            buildStatCard(
                'Late Entries', '1 Day', Icons.access_time, Colors.redAccent),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ProfilePage extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfilePage({super.key, required this.onLogout});

  final Color primaryColor = const Color(0xFF4169E1); // #4169E1

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('myBox');
    final dynamic rawData = box.get('staffinfo');
    final Map<String, dynamic> staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);

    final String fullName = (staffInfo['firstname'] ?? '') + ' ' + (staffInfo['lastname'] ?? '');
    final String phone = staffInfo['phonenumber'] ?? 'N/A';
    final String email = staffInfo['email'] ?? 'N/A';
    final String designation = staffInfo['designation'] ?? 'Employee';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      // Remove AppBar or make it transparent with no title
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: primaryColor,
                  backgroundImage: const AssetImage('assets/user_placeholder.png'),
                  onBackgroundImageError: (_, __) {
                    // This callback doesn't rebuild widget, so we'll use a conditional below instead.
                  },
                  child: staffInfo['firstname'] != null && staffInfo['firstname'].isNotEmpty
                      ? Text(
                    staffInfo['firstname'][0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.trim().isEmpty ? 'Unknown' : fullName.trim(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        designation,
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 16),

            _buildInfoTile("Email", email, Icons.alternate_email_rounded),
            const SizedBox(height: 16),
            _buildInfoTile("Phone", phone, Icons.phone_outlined),
            const SizedBox(height: 16),
            _buildInfoTile("Designation", designation, Icons.work_outline_rounded),
            const SizedBox(height: 40),

            // Logout button with primary color background and white text/icon
            ElevatedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                "Logout",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
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

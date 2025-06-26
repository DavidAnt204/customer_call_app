import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  final String email;
  final VoidCallback onLogout;

  const ProfilePage({
    required this.email,
    required this.onLogout,
  });

  final String fullName = "John Doe";
  final String phoneNumber = "+91 9876543210";
  final String designation = "Software Engineer";

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: AssetImage('assets/user_placeholder.png'),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName,
                      style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(designation,
                      style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(),
          SizedBox(height: 10),

          Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(email),

          SizedBox(height: 16),
          Text("Phone", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(phoneNumber),

          SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: onLogout,
            icon: Icon(Icons.logout),
            label: Text("Logout"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

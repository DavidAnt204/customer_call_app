import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'dart:ui'; // Used for potential future glassmorphic effects or minor blurring

class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfilePage({Key? key, required this.onLogout}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> staffInfo;
  late String fullName;
  late String phone;
  late String email;
  late String designation;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Modern Color Palette
  final Color primaryColor = const Color(0xFF4169E1); // Royal Blue
  final Color secondaryColor = const Color(0xFF8B0000); // Dark Red for Logout
  final Color lightBg = const Color(0xFFF3F5F9);
  final Color darkBg = const Color(0xFF121212);
  final double cardRadius = 18.0;

  @override
  void initState() {
    super.initState();
    // 1. Data Initialization (Functionality Preserved)
    final box = Hive.box('myBox');
    final dynamic rawData = box.get('staffinfo');
    staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);

    fullName = (staffInfo['firstname'] ?? '') + ' ' + (staffInfo['lastname'] ?? '');
    phone = staffInfo['phonenumber'] ?? 'N/A';
    email = staffInfo['email'] ?? 'N/A';
    designation = staffInfo['designation'] ?? 'Employee';

    // 2. Animation Setup (Functionality Preserved)
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    // 3. Logout Logic (Functionality Preserved)
    await _animationController.forward();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? darkBg : lightBg;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation.drive(Tween(begin: 1.0, end: 0.0)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(isDark), // Redesigned Header
                const SizedBox(height: 30),

                // Info Tiles
                _buildInfoTile(
                  title: "Email",
                  value: email,
                  icon: Icons.email_outlined,
                  isEditable: true,
                  onChanged: (val) {
                    setState(() => email = val);
                  },
                ),
                const SizedBox(height: 16),

                _buildInfoTile(
                  title: "Phone",
                  value: phone,
                  icon: Icons.phone_outlined,
                  isEditable: true,
                  onChanged: (val) {
                    setState(() => phone = val);
                  },
                ),
                const SizedBox(height: 16),

                _buildInfoTile(
                  title: "Designation",
                  value: designation,
                  icon: Icons.work_outline,
                  isEditable: false,
                ),
                const SizedBox(height: 50),

                // Logout Button
                _buildLogoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- REDESIGNED WIDGETS ---

  Widget _buildHeaderCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // Sleek, slightly intense gradient
          colors: [primaryColor, primaryColor.withOpacity(0.9)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2), // Subtle white ring
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              child: Text(
                // Placeholder logic preserved
                staffInfo['firstname'] != null ? staffInfo['firstname'][0].toUpperCase() : '?',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.trim().isEmpty ? 'Unknown' : fullName.trim(),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    designation,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    required IconData icon,
    required bool isEditable,
    ValueChanged<String>? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(cardRadius),
        border: isDark ? Border.all(color: Colors.white12, width: 1) : null,
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Icon(icon, size: 22, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: primaryColor.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                isEditable
                    ? TextFormField(
                  initialValue: value,
                  onChanged: onChanged,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'N/A',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                  ),
                )
                    : Text(
                  value,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (isEditable)
            Icon(Icons.edit_rounded, size: 20, color: Colors.grey.shade400)
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: secondaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout, color: Colors.white, size: 22),
        label: Text(
          "LOGOUT",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
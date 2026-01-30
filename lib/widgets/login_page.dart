import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Added for modern typography
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../screens/home_screen.dart'; // Assuming this import is correct

class ModernLoginPage extends StatefulWidget {
  final VoidCallback onToggle;
  const ModernLoginPage({super.key, required this.onToggle});

  @override
  State<ModernLoginPage> createState() => _ModernLoginPageState();
}

class _ModernLoginPageState extends State<ModernLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;

  // --- Design & Color Constants ---
  final Color primaryColor = const Color(0xFF4169E1); // Royal Blue
  final Color secondaryColor = const Color(0xFF00C6FF); // Bright Cyan
  final Color cardColor = Colors.white.withOpacity(0.95);
  final double cardRadius = 24.0;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  // --- Functionality Preserved: Remember Me ---
  Future<void> _loadRemembered() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('remember_me') ?? false) {
      _phoneController.text = prefs.getString('phone') ?? '';
      _passwordController.text = prefs.getString('password') ?? '';
      setState(() => _rememberMe = true);
    }
  }

  Future<void> _saveRemembered() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('phone', _phoneController.text);
      await prefs.setString('password', _passwordController.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('phone');
      await prefs.remove('password');
      await prefs.setBool('remember_me', false);
    }
  }

  // --- Functionality Preserved: Login Logic ---
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final phone = _phoneController.text;
    final pass = _passwordController.text;
    final url = Uri.parse('https://crm.vasaantham.com/api/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phonenumber': phone, 'password': pass}),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['staffid'] != null) {
          var box = Hive.box('myBox');
          box.put('staffid', data['staffid'].toString());
          box.put('staffinfo', jsonEncode(data));
          await _saveRemembered();

          // Show and close dialog before navigating
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(width: 20),
                      Text("Logging you in...", style: GoogleFonts.poppins()),
                    ],
                  ),
                ),
              );
            },
          );
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) Navigator.of(context).pop();

          if (mounted) {
            // Navigate to home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomePage(email: data['email']),
              ),
            );
          }
        } else {
          final msg = data['message'] ?? 'Login failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      } else {
        final error = 'Server error: ${response.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: Please check your connection.')),
      );
    }
  }

  // --- Modern Input Decoration Helper ---
  InputDecoration _buildModernInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
      floatingLabelStyle: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2.0),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Background Gradient for a modern feel
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFF3F5F9), primaryColor.withOpacity(0.1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Header/Logo Area ---
                // SizedBox(height: 50), // Use for logo space
                Text(
                  'Welcome Back 👋',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to your account',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),

                // --- Form Card ---
                Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(cardRadius),
                  ),
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Phone Number Field
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.poppins(),
                            decoration: _buildModernInputDecoration(
                              label: 'Phone Number',
                              icon: Icons.phone_android_rounded,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Please enter your phone number';
                              if (!RegExp(r'^\d{10}$').hasMatch(val)) return 'Enter a valid 10-digit number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // 2. Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: GoogleFonts.poppins(),
                            decoration: _buildModernInputDecoration(
                              label: 'Password',
                              icon: Icons.lock_rounded,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: primaryColor,
                                ),
                                onPressed: () =>
                                    setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                            ),
                            validator: (val) =>
                            val == null || val.isEmpty ? 'Please enter your password' : null,
                          ),
                          const SizedBox(height: 10),

                          // 3. Remember Me Checkbox
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (val) =>
                                          setState(() => _rememberMe = val ?? false),
                                      activeColor: primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Remember me',
                                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                              // Optional: Forgot Password Button
                              // TextButton(
                              //   onPressed: () {},
                              //   child: Text('Forgot Password?', style: GoogleFonts.poppins(color: primaryColor)),
                              // ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // 4. Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                elevation: 10,
                                shadowColor: primaryColor.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                  : Text(
                                'LOGIN',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Optional: Toggle to Sign Up
                // TextButton(
                //   onPressed: widget.onToggle,
                //   child: Text(
                //     "Don't have an account? Sign up",
                //     style: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.bold),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
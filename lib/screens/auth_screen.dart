import 'package:flutter/material.dart';

import '../widgets/login_page.dart';
import '../widgets/signup_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool showLogin = true;

  void toggleScreen() {
    setState(() {
      showLogin = !showLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return showLogin
        ? ModernLoginPage(onToggle: toggleScreen)
        : SignupPage(onToggle: toggleScreen);
  }
}

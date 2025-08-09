import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../screens/auth_screen.dart'; // or your login/auth screen

Future<void> logout(BuildContext context) async {
  final box = Hive.box('myBox');

  // Clear login-related data
  await box.delete('staffid');
  await box.delete('staffinfo');

  // Optional: Clear all if needed
  // await box.clear();

  // Navigate to login/auth screen and remove all previous routes
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
  );
}

import 'dart:convert';

import 'package:customer_call/screens/home_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/auth_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('myBox');
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await _requestPermissions();
  } else {
    // Skip phone permission logic for web
    print("Phone permission not supported on web.");
  }
  // your code here
  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  // Request multiple permissions if needed
  await [
    Permission.phone,
    Permission.contacts,
    Permission.microphone
  ].request();

  // Optional: handle denied or permanently denied
  if (await Permission.phone.isDenied) {
    print("Phone permission denied.");
  }

  if (await Permission.phone.isPermanentlyDenied) {
    openAppSettings(); // Prompt user to manually allow
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> isLoggedIn() async {
    var box = Hive.box('myBox');
    final staffId = box.get('staffid');
    return staffId != null && staffId.toString().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Auth Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FutureBuilder<bool>(
        future: isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData && snapshot.data == true) {
            var box = Hive.box('myBox');
            var staffInfoString = box.get('staffinfo');
            var staffInfo = jsonDecode(staffInfoString); // ✅ FIX here
            return HomePage(email: staffInfo['email'] ?? '');
          } else {
            return const AuthScreen();
          }
        },
      ),

    );
  }
}

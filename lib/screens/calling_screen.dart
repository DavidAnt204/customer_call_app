import 'package:flutter/material.dart';

class CallingScreen extends StatelessWidget {
  final String phoneNumber;

  const CallingScreen({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle, size: 100, color: Colors.white70),
            const SizedBox(height: 20),
            Text(
              phoneNumber,
              style: const TextStyle(fontSize: 28, color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Text('Calling...', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

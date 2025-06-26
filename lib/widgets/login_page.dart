import 'package:flutter/material.dart';

import '../screens/home_screen.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onToggle;

  const LoginPage({super.key, required this.onToggle});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Simulated user data (replace with real API later)
  final String demoUser = 'user@example.com';
  final String demoPass = 'password123';

  void _login() {
    // if (_formKey.currentState!.validate()) {
    //   if (_usernameController.text == demoUser &&
    //       _passwordController.text == demoPass) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(email: _usernameController.text),
          ),
        );
      // } else {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Invalid credentials')),
      //   );
      // }
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (val) =>
                val!.isEmpty ? 'Enter your email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (val) =>
                val!.isEmpty ? 'Enter your password' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _login, child: const Text("Login")),
              TextButton(
                onPressed: widget.onToggle,
                child: const Text("Don't have an account? Sign up"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class SignupPage extends StatefulWidget {
  final VoidCallback onToggle;

  const SignupPage({super.key, required this.onToggle});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  void _signup() {
    if (_formKey.currentState!.validate()) {
      // For now, we simulate success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created. Please log in.")),
      );
      widget.onToggle(); // Switch to login screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Signup")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _emailController,
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
                val!.length < 6 ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                validator: (val) =>
                val != _passwordController.text ? 'Passwords don\'t match' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _signup, child: const Text("Sign Up")),
              TextButton(
                onPressed: widget.onToggle,
                child: const Text("Already have an account? Log in"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class RegisterStudent extends StatefulWidget {
  @override
  State<RegisterStudent> createState() => _RegisterStudentState();
}

class _RegisterStudentState extends State<RegisterStudent> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  String extractFastApiError(String responseBody) {
    try {
      final Map<String, dynamic> parsedJson = jsonDecode(responseBody);
      if (parsedJson['detail'] is List && (parsedJson['detail'] as List).isNotEmpty) {
        final firstError = parsedJson['detail'][0];
        return firstError['msg'] ?? 'Validation error occurred.';
      } else if (parsedJson['detail'] is String) {
        return parsedJson['detail'];
      }
    } catch (e) {
      print('Failed to parse error body: $e');
    }
    return 'An unexpected error occurred. Please try again.';
  }

  Future<void> _register() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          "full_name": fullName,
          "role": "student",
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! You can now log in.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // back to login screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(extractFastApiError(response.body)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Sign Up")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  hintText: 'Full name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  hintText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _register,
                child: const Text("Create Account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
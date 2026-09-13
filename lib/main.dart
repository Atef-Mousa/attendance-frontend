import 'package:attendance_project/active_student.dart';
import 'package:attendance_project/admin.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' ;
import 'package:shared_preferences/shared_preferences.dart';
import 'create_course.dart';
import 'route_guard.dart';
import 'config.dart';
import 'registration.dart';
enum Role {student , teacher}
void main() {
  runApp(const MyApp());
}

Map<String, dynamic> parseJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw Exception('Invalid token format');
  }

  // Normalize Base64 string length for Dart's base64Url decoder
  String payload = parts[1];
  switch (payload.length % 4) {
    case 2:
      payload += '==';
      break;
    case 3:
      payload += '=';
      break;
  }

  // Decode Base64 string to JSON map
  final decodedBytes = base64Url.decode(payload);
  final decodedString = utf8.decode(decodedBytes);
  return jsonDecode(decodedString) as Map<String, dynamic>;
}




class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'attendance_project',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'attendance_system'),
      routes: {
        '/activate_student': (context) => RouteGuard(requiredRole: 'student', child: activate_student()),
        '/activate_teacher': (context) => RouteGuard(requiredRole: 'instructor', child: Admin()),
        '/create_course': (context) => RouteGuard(requiredRole: 'instructor', child: CreateCourseScreen()),
        '/register_student': (context) => RegisterStudent(),

      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();



  final url = Uri.parse('$baseUrl/api/v1/login');

  @override
  void initState() {
    super.initState();
    _redirectIfLoggedIn();
  }
  Future<void> _redirectIfLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    try {
      final payload = parseJwtPayload(token);

      // Check expiry ('exp' is a Unix timestamp in seconds)
      final int? exp = payload['exp'];
      if (exp != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
        if (DateTime.now().toUtc().isAfter(expiryDate)) {
          await prefs.remove('jwt_token');
          return; // Token expired -> stay on login page
        }
      }

      final String? role = payload['role'];
      if (!mounted) return;

      if (role == 'student') {
        Navigator.pushReplacementNamed(context, '/activate_student');
      } else if (role == 'instructor') {
        Navigator.pushReplacementNamed(context, '/activate_teacher');
      }
    } catch (e) {
      await prefs.remove('jwt_token');
    }
  }

  Future<void> _login() async {
    final email = _nameController.text;
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty');
      return; // Stop execution here

    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        final message = data['detail'] ?? 'Login is currently locked.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange),
        );
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to login');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final accessToken = data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', accessToken);

      final Map<String, dynamic> payload = parseJwtPayload(accessToken);
      final String? userRole = payload['role'];
      if (!mounted) return;
      if (userRole == 'student') {
        Navigator.pushNamed(context, '/activate_student');
      } else {
        Navigator.pushNamed(context, '/activate_teacher');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      print('done');
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(

        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text(widget.title),
      ),
      body: Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'email or name',
                border:OutlineInputBorder(),
              ),


            ),
            SizedBox.fromSize(
              size: Size(56, 12),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: 'password',
                border:OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox.fromSize(
              size: Size(56, 12),
            ),

            ElevatedButton(onPressed: _login,
                child: Text("Sign In")),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register_student'),
              child: const Text("Don't have an account? Sign up"),
            ),

          ],
        ),
      ),

    );
  }
}

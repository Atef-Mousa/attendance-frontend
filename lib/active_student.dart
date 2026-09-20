import 'dart:convert';

import 'package:flutter/material.dart' ;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'package:geolocator/geolocator.dart';

class activate_student extends StatefulWidget {
  @override
  State<activate_student> createState() => _activate_student_state();
  }
class _activate_student_state extends State<activate_student> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _sessionIdController = TextEditingController();
  final TextEditingController _submissionLinkController = TextEditingController();
  Uri url = Uri.parse('$baseUrl/api/v1/attendance/submit');

  bool _taskSubmitted = false;
  bool _isSubmittingTask = false;


  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission permanently denied. Enable it in browser settings.')),
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
      return null;
    }
  }


  Future<void> _logout() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/settings/lock_status'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['login_locked'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You cannot log out while a session is active.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }
    } catch (e) {
      // If the check itself fails (e.g. no internet), fall through and allow logout
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }


  String extractFastApiError(String responseBody) {
    try {
      final Map<String, dynamic> parsedJson = jsonDecode(responseBody);

      // Check if the 'detail' field is a List (standard FastAPI validation errors)
      if (parsedJson['detail'] is List && (parsedJson['detail'] as List).isNotEmpty) {
        final firstError = parsedJson['detail'][0];
        return firstError['msg'] ?? 'Validation error occurred.';
      }
      // Handle single string errors (e.g., raise HTTPException(status_code=400, detail="Invalid token"))
      else if (parsedJson['detail'] is String) {
        return parsedJson['detail'];
      }
    } catch (e) {
      print('Failed to parse error body: $e');
    }

    return 'An unexpected error occurred. Please try again.';
  }

  Future<void> _sendOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the OTP code.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final position = await _getCurrentLocation();
    if (position == null) return; // error already shown

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": 'Bearer $token'
        },
        body: jsonEncode({
          "otp_code": otp,
          "latitude": position.latitude,
          "longitude": position.longitude,
        }),
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(extractFastApiError(response.body)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Pre-fill the session ID for convenience; the student can still edit it.
        final data = jsonDecode(response.body);
        final sessionId = data['session_id'];
        if (sessionId != null) {
          _sessionIdController.text = sessionId.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Attendance successfully recorded"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // consider showing an error here too
    }
  }

  Future<void> _submitTask() async {
    final sessionIdText = _sessionIdController.text.trim();
    final sessionId = int.tryParse(sessionIdText);
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid session ID (a number).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final link = _submissionLinkController.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a submission link.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    if (token == null) {
      throw Exception('No token found');
    }

    setState(() => _isSubmittingTask = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/sessions/$sessionId/submit_task'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": 'Bearer $token',
        },
        body: jsonEncode({"submission_link": link}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _taskSubmitted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task submitted successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(extractFastApiError(response.body)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // consider showing an error here too
    } finally {
      if (mounted) setState(() => _isSubmittingTask = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("OTP Verification "),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
          ],
        ),
      body :
        Center(
          child: Column(
            children: [
            TextField(
            controller: _otpController,
            decoration: InputDecoration(
              hintText: 'OTP',
              border:OutlineInputBorder(),
            ),

            ),
              ElevatedButton(onPressed: _sendOtp, child: Text("Submit")),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Submit Task Link',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sessionIdController,
                enabled: !_taskSubmitted,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Session ID',
                  hintText: 'e.g. 3',
                  helperText: 'Ask your instructor for the session ID they started.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _submissionLinkController,
                enabled: !_taskSubmitted,
                decoration: const InputDecoration(
                  labelText: 'Submission Link',
                  hintText: 'https://github.com/you/your-repo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              _taskSubmitted
                  ? const Text(
                      'Task submitted — submissions are locked.',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _isSubmittingTask ? null : _submitTask,
                      child: _isSubmittingTask
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Submit Task"),
                    ),
            ],
        )
    )

    );
  }
}
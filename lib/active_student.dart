import 'dart:convert';

import 'package:flutter/material.dart' ;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class activate_student extends StatefulWidget {
  @override
  State<activate_student> createState() => _activate_student_state();
  }
class _activate_student_state extends State<activate_student> {
  final TextEditingController _otpController = TextEditingController();
  Uri url = Uri.parse('$baseUrl/api/v1/attendance/submit');

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

  Future<void> _sendOtp() async{
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the OTP code.'),
          backgroundColor: Colors.orange,
        ),
      );
      return; // Exit early without throwing a crashing exception
    }
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    if (token == null){
      throw Exception('No token found');
    }
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": 'Bearer $token'},
        body:jsonEncode({"otp_code": otp}),
      );


      if (response.statusCode != 200){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(extractFastApiError(response.body)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      else
        {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Attendance successfully recorded"), // "Attendance successfully recorded"
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

    }catch(e){

    }finally{

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
              ElevatedButton(onPressed: _sendOtp, child: Text("Submit"))
            ],
        )
    )

    );
  }
}
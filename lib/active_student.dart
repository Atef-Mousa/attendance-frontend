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
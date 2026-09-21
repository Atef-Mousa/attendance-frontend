import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'student_search.dart';



class Admin extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _AdminState();
}

class _AdminState extends State<Admin> {



  List<dynamic> _courses = [];
  bool _isLoading = true;
  final Map<int, DateTime> _lockedUntil = {};
  Timer? _lockTimer;


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
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _stopSession(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final sessionIdStr = prefs.getString('sessionId_course_$courseId');

    if (token == null || sessionIdStr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active session found for this course.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/sessions/$sessionIdStr/stop'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session stopped.'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop session: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error while stopping session.')),
      );
    }
  }

  Future<void> _closeTaskSubmissions(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final sessionIdStr = prefs.getString('sessionId_course_$courseId');

    if (token == null || sessionIdStr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No session found for this course. Start a session first.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/sessions/$sessionIdStr/close_task_submissions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task submissions closed for this session.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close task submissions: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error while closing task submissions.')),
      );
    }
  }


  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }



@override
  void initState() {
    super.initState();
    _fetchCourses();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>?> startSession(
      int courseId, {
        int ttlSeconds = 60,
        required double latitude,
        required double longitude,
      }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      print('[startSession]: No JWT token found in SharedPreferences.');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/sessions/start'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'course_id': courseId,
          'ttl_seconds': ttlSeconds,
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 10));

      print('[start_session]: ${response.statusCode} -> ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Failed to start session: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error starting session: $e');
      return null;
    }
  }

  Future<void> _showSavedOtp(Map<String, dynamic> course) async {
    final dynamic rawId = course['id'] ?? course['course_id'];
    final int courseId = rawId is int ? rawId : int.parse(rawId.toString());

    final prefs = await SharedPreferences.getInstance();
    final String? otpCode = prefs.getString('otp_course_$courseId');
    final String? sessionIdStr = prefs.getString('sessionId_course_$courseId');

    if (!mounted) return;

    if (otpCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No OTP saved yet. Start a session first.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Saved OTP: ${course['code']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Last generated OTP for this course:'),
            const SizedBox(height: 16),
            SelectableText(
              otpCode,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            Text('Session ID: ${sessionIdStr ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAttendance(Map<String, dynamic> course) async {
    final dynamic rawId = course['id'] ?? course['course_id'];
    final int courseId = rawId is int ? rawId : int.parse(rawId.toString());

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final sessionIdStr = prefs.getString('sessionId_course_$courseId');

    if (sessionIdStr == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No session found for this course. Start a session first.')),
      );
      return;
    }

    List<dynamic> records = [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/sessions/$sessionIdStr/attendance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        records = jsonDecode(response.body) as List<dynamic>;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load attendance: ${response.statusCode}')),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error while loading attendance.')),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attendance: ${course['code']} (Session $sessionIdStr)'),
        content: SizedBox(
          width: double.maxFinite,
          child: records.isEmpty
              ? const Text('No attendance recorded yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final timestamp = record['timestamp'] as String?;
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(record['student_name'] ?? 'Unknown'),
                      subtitle: timestamp != null
                          ? Text(DateTime.parse(timestamp).toLocal().toString())
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSubmissionLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null || !await launchUrl(uri, webOnlyWindowName: '_blank')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $link')),
      );
    }
  }

  Future<void> _showTaskSubmissions(Map<String, dynamic> course) async {
    final dynamic rawId = course['id'] ?? course['course_id'];
    final int courseId = rawId is int ? rawId : int.parse(rawId.toString());

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final sessionIdStr = prefs.getString('sessionId_course_$courseId');

    if (sessionIdStr == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No session found for this course. Start a session first.')),
      );
      return;
    }

    List<dynamic> submissions = [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/sessions/$sessionIdStr/task_submissions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        submissions = jsonDecode(response.body) as List<dynamic>;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load submissions: ${response.statusCode}')),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error while loading submissions.')),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Task Submissions: ${course['code']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: submissions.isEmpty
              ? const Text('No submissions yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: submissions.length,
                  itemBuilder: (context, index) {
                    final sub = submissions[index];
                    final link = sub['submission_link'] as String? ?? '';
                    return ListTile(
                      title: Text(sub['student_name'] ?? 'Unknown'),
                      subtitle: InkWell(
                        onTap: () => _openSubmissionLink(link),
                        child: Text(
                          link,
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _startSession(Map<String, dynamic> course) async {
    final position = await _getCurrentLocation();
    if (position == null) return; // error already shown to user

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting session for ${course['code']}...')),
    );

    final dynamic rawId = course['id'] ?? course['course_id'];
    final int courseId = rawId is int ? rawId : int.parse(rawId.toString());

    final sessionData = await startSession(
      courseId,
      ttlSeconds: 60,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (!mounted) return;

    if (sessionData != null) {
      final String otpCode = sessionData['otp_code'] ?? sessionData['otp'] ?? 'N/A';
      final dynamic sessionId = sessionData['id'] ?? sessionData['session_id'];

      // Save OTP locally so it can be viewed permanently later
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('otp_course_$courseId', otpCode);
      await prefs.setString('sessionId_course_$courseId', sessionId.toString());

      // Lock the Start Session button until this session's expiry
      final DateTime expiresAt = DateTime.parse(sessionData['expires_at']).toLocal();
      setState(() {
        _lockedUntil[courseId] = expiresAt;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Session Started: ${course['code']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share this OTP with your students:'),
              const SizedBox(height: 16),
              SelectableText(
                otpCode,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text('Session ID: $sessionId'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start session. Check logs for details.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  bool _isLocked(int courseId) {
    final until = _lockedUntil[courseId];
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }
  // Fetch created courses from FastAPI
  Future<void> _fetchCourses() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/courses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _courses = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print('Failed to fetch courses: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create Sessions"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child:Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Additional Course'),
              onPressed: () async {
                // Navigate and refresh list if a new course was added
                final result = await Navigator.pushNamed(context, '/create_course');
                if (result == true) {
                  _fetchCourses();
                }
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Search Student'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudentSearchScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Select a course to start a session:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // 2. List of existing courses to start a session
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _courses.isEmpty
                  ? const Center(child: Text('No courses found. Add one above!'))
                  : ListView.builder(
                itemCount: _courses.length,
                itemBuilder: (context, index) {

                  final course = _courses[index];
                  final dynamic rawId = course['id'] ?? course['course_id'];
                  final int courseId = rawId is int ? rawId : int.parse(rawId.toString());
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.book),
                      title: Text('${course['code']} - ${course['title']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: _isLocked(courseId) ? null : () => _startSession(course),
                            child: const Text('Start Session'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            tooltip: 'Show saved OTP',
                            onPressed: () => _showSavedOtp(course),
                          ),
                          IconButton(
                            icon: const Icon(Icons.people),
                            tooltip: 'View attendance',
                            onPressed: () => _showAttendance(course),
                          ),
                          IconButton(
                            icon: const Icon(Icons.assignment_turned_in),
                            tooltip: 'View task submissions',
                            onPressed: () => _showTaskSubmissions(course),
                          ),
                          IconButton(
                            icon: const Icon(Icons.block, color: Colors.orange),
                            tooltip: 'Close task submissions for this session',
                            onPressed: () => _closeTaskSubmissions(courseId),
                          ),
                          IconButton(
                            icon: const Icon(Icons.stop_circle, color: Colors.red),
                            tooltip: 'Stop session',
                            onPressed: () => _stopSession(courseId),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),


          ],
        ),
      ),
    );
  }
}

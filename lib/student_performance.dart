import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';

class StudentPerformanceScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentPerformanceScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentPerformanceScreen> createState() => _StudentPerformanceScreenState();
}

class _StudentPerformanceScreenState extends State<StudentPerformanceScreen> {
  Map<String, dynamic>? _performance;
  bool _isLoading = true;
  String? _error;
  final Map<int, TextEditingController> _gradeControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchPerformance();
  }

  @override
  void dispose() {
    for (final controller in _gradeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchPerformance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/students/${widget.studentId}/performance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        for (final sub in (data['task_submissions'] as List<dynamic>)) {
          final id = sub['id'] as int;
          _gradeControllers[id] = TextEditingController(
            text: sub['grade'] != null ? sub['grade'].toString() : '',
          );
        }
        setState(() {
          _performance = data;
        });
      } else {
        setState(() {
          _error = 'Failed to load performance: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error while loading performance.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGrade(int submissionId) async {
    final controller = _gradeControllers[submissionId];
    if (controller == null) return;
    final grade = double.tryParse(controller.text.trim());
    if (grade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid numeric grade.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/v1/task_submissions/$submissionId/grade'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'grade': grade}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grade saved.'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save grade: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error while saving grade.')),
      );
    }
  }

  Future<void> _openLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null || !await launchUrl(uri, webOnlyWindowName: '_blank')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.studentName} - Performance')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Text(_performance!['email'] ?? '', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    const Text('Attendance by course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if ((_performance!['courses'] as List<dynamic>).isEmpty)
                      const Text('You have not created any courses yet.'),
                    ...(_performance!['courses'] as List<dynamic>).map((course) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.book),
                          title: Text('${course['code']} - ${course['title']}'),
                          subtitle: Text(
                            'Attended ${course['attended_count']} / ${course['sessions_held']} sessions',
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    const Text('Task submissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if ((_performance!['task_submissions'] as List<dynamic>).isEmpty)
                      const Text('No task submissions in your courses yet.'),
                    ...(_performance!['task_submissions'] as List<dynamic>).map((sub) {
                      final id = sub['id'] as int;
                      final link = sub['submission_link'] as String? ?? '';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => _openLink(link),
                                child: Text(
                                  link,
                                  style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Submitted: ${sub['submitted_at']}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _gradeControllers[id],
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Grade',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _saveGrade(id),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}

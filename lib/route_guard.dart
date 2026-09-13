import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // for parseJwtPayload

class RouteGuard extends StatefulWidget {
  final String requiredRole;
  final Widget child;

  const RouteGuard({super.key, required this.requiredRole, required this.child});

  @override
  State<RouteGuard> createState() => _RouteGuardState();
}

class _RouteGuardState extends State<RouteGuard> {
  bool? _authorized;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    // Re-check every 30 seconds while this page is open
    _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkExpiry());
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    bool ok = false;

    if (token != null) {
      try {
        final payload = parseJwtPayload(token);
        ok = payload['role'] == widget.requiredRole && !_isExpired(payload);
      } catch (e) {
        ok = false;
      }
    }

    if (!mounted) return;
    setState(() => _authorized = ok);

    if (!ok) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      });
    }
  }

  Future<void> _checkExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    try {
      final payload = parseJwtPayload(token);
      if (_isExpired(payload)) {
        _expiryTimer?.cancel();
        await prefs.remove('jwt_token');
        if (!mounted) return;

        // Force the message to show, then redirect
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Session expired'),
            content: const Text('Your session has ended. Please log in again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      // corrupted token, ignore here — next full check will catch it
    }
  }

  bool _isExpired(Map<String, dynamic> payload) {
    final int? exp = payload['exp'];
    if (exp == null) return false;
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    return DateTime.now().toUtc().isAfter(expiryDate);
  }

  @override
  Widget build(BuildContext context) {
    if (_authorized == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_authorized == true) {
      return widget.child;
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
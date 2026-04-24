import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'LoginPage.dart';
import 'SidebarLayout.dart';
import 'services/session_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  bool _isLoadingSession = true;
  Map<String, dynamic>? _session;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final session = await SessionService.loadSession();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      _session = session;
      _isLoadingSession = false;
    });
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await SessionService.saveSession(session);
    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
      _session = session;
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await SessionService.clearSession();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSession) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _isLoggedIn
          ? MainLayout(
              onLogout: _handleLogout,
              session: _session,
            )
          : LoginPage(onLoginSuccess: _handleLoginSuccess),
    );
  }
}

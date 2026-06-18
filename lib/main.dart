import 'package:flutter/material.dart';

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
  Map<String, dynamic>? _session;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> session) async {
    await SessionService.saveSession(session);
    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
      _session = session;
    });
  }

  Future<void> _handleLogout() async {
    await SessionService.clearSession();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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

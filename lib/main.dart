import 'LoginPage.dart';
import 'SidebarLayout.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _loggedInUsername;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      _loggedInUsername = prefs.getString('logged_in_username');
      _isLoadingSession = false;
    });
  }

  Future<void> _handleLoginSuccess(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('logged_in_username', username);
    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
      _loggedInUsername = username;
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('logged_in_username');
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _loggedInUsername = null;
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
              loggedInUsername: _loggedInUsername,
            )
          : LoginPage(onLoginSuccess: _handleLoginSuccess),
    );
  }
}

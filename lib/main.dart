import 'LoginPage.dart';
import 'SidebarLayout.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
          : AuthHomePage(onLoginSuccess: _handleLoginSuccess),
    );
  }
}

class AuthHomePage extends StatefulWidget {
  const AuthHomePage({super.key, required this.onLoginSuccess});

  final Future<void> Function(Map<String, dynamic> session) onLoginSuccess;

  @override
  State<AuthHomePage> createState() => _AuthHomePageState();
}

class _AuthHomePageState extends State<AuthHomePage> {
  LoginMode? _selectedMode;

  @override
  Widget build(BuildContext context) {
    if (_selectedMode != null) {
      return LoginPage(
        mode: _selectedMode!,
        onBack: () => setState(() => _selectedMode = null),
        onLoginSuccess: widget.onLoginSuccess,
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff081120), Color(0xff10243e), Color(0xff1a365d)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -120,
              child: _BackgroundGlow(
                size: 360,
                color: Color(0x33f59e0b),
              ),
            ),
            Positioned(
              bottom: -180,
              left: -140,
              child: _BackgroundGlow(
                size: 420,
                color: Color(0x2214b8a6),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding =
                      constraints.maxWidth < 720 ? 20.0 : 32.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 64,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0x14ffffff),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0x22ffffff),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.balance,
                                  size: 52,
                                  color: Color(0xfffbbf24),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'LegalAI Access Portal',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 680),
                                child: const Text(
                                  'Choose the right access point for the master side or the firm side.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xffcbd5e1),
                                    fontSize: 18,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              Wrap(
                                spacing: 24,
                                runSpacing: 24,
                                alignment: WrapAlignment.center,
                                children: [
                                  _AuthChoiceCard(
                                    title: 'Master Login',
                                    description:
                                        'Platform owner access. Keep current app data, create firms, and manage firm credentials.',
                                    buttonLabel: 'Open Master Login',
                                    icon: Icons.admin_panel_settings_outlined,
                                    onTap: () => setState(
                                      () => _selectedMode = LoginMode.master,
                                    ),
                                  ),
                                  _AuthChoiceCard(
                                    title: 'User Login',
                                    description:
                                        'Firm admin and lawyer access. Sign in to a firm workspace and manage firm team members.',
                                    buttonLabel: 'Open User Login',
                                    icon: Icons.groups_outlined,
                                    onTap: () => setState(
                                      () => _selectedMode = LoginMode.user,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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

class _AuthChoiceCard extends StatelessWidget {
  const _AuthChoiceCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Card(
        elevation: 0,
        color: const Color(0xfff8fafc),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 40, color: const Color(0xff0f172a)),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff0f172a),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  color: Colors.blueGrey.shade700,
                  height: 1.45,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff0f172a),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

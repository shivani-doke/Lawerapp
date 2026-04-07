import 'package:flutter/material.dart';
import 'services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoginSuccess,
  });

  final Future<void> Function(String username) onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _signUpUsernameController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureSignUpPassword = true;
  bool _obscureSignUpConfirmPassword = true;
  bool _isSubmitting = false;
  bool _isSignUpMode = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _signUpUsernameController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitSignIn() async {
    if (!_signInFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      final result = await ApiService().login(
        username: username,
        password: password,
      );
      await widget.onLoginSuccess((result['username'] ?? username).toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _submitSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiService().signup(
        username: _signUpUsernameController.text.trim(),
        password: _signUpPasswordController.text,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSignUpMode = false;
        _usernameController.text =
            (result['username'] ?? _signUpUsernameController.text.trim())
                .toString();
        _passwordController.clear();
        _signUpPasswordController.clear();
        _signUpConfirmPasswordController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign up successful. Please sign in with the new user.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blueGrey.shade100),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0f172a), Color(0xff102a43), Color(0xfff8fafc)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 18,
                color: const Color(0xfff8fafc),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.balance,
                          size: 56,
                          color: Color(0xffE0A800),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSignUpMode ? 'LegalAI Sign Up' : 'LegalAI Login',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff0f172a),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignUpMode
                              ? 'Create a new user account for the app from the same screen.'
                              : 'Sign in to access clients, documents, AI tools, and case work.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xffe2e8f0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: !_isSignUpMode
                                        ? const Color(0xff0f172a)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: TextButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () {
                                            setState(() => _isSignUpMode = false);
                                          },
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: !_isSignUpMode
                                            ? Colors.white
                                            : const Color(0xff0f172a),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: _isSignUpMode
                                        ? const Color(0xff0f172a)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: TextButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () {
                                            setState(() => _isSignUpMode = true);
                                          },
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: _isSignUpMode
                                            ? Colors.white
                                            : const Color(0xff0f172a),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Form(
                          key: _isSignUpMode ? _signUpFormKey : _signInFormKey,
                          child: Column(
                            children: [
                              if (!_isSignUpMode) ...[
                                TextFormField(
                                  controller: _usernameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecoration(
                                    label: 'Username',
                                    icon: Icons.person_outline,
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Enter username';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  onFieldSubmitted: (_) => _submitSignIn(),
                                  decoration: _inputDecoration(
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').isEmpty) {
                                      return 'Enter password';
                                    }
                                    return null;
                                  },
                                ),
                              ] else ...[
                                TextFormField(
                                  controller: _signUpUsernameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecoration(
                                    label: 'New Username',
                                    icon: Icons.person_add_alt_1_outlined,
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Enter username';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _signUpPasswordController,
                                  obscureText: _obscureSignUpPassword,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecoration(
                                    label: 'New Password',
                                    icon: Icons.lock_outline,
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscureSignUpPassword =
                                              !_obscureSignUpPassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscureSignUpPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').isEmpty) {
                                      return 'Enter password';
                                    }
                                    if ((value ?? '').length < 4) {
                                      return 'Use at least 4 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _signUpConfirmPasswordController,
                                  obscureText: _obscureSignUpConfirmPassword,
                                  onFieldSubmitted: (_) => _submitSignUp(),
                                  decoration: _inputDecoration(
                                    label: 'Confirm Password',
                                    icon: Icons.verified_user_outlined,
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscureSignUpConfirmPassword =
                                              !_obscureSignUpConfirmPassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscureSignUpConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').isEmpty) {
                                      return 'Confirm password';
                                    }
                                    if (value != _signUpPasswordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _isSubmitting
                                ? null
                                : (_isSignUpMode
                                    ? _submitSignUp
                                    : _submitSignIn),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xff0f172a),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isSignUpMode ? 'Create Account' : 'Login',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

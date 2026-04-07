import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _usernameKey = 'logged_in_username';

  static Future<String> getLoggedInUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_usernameKey) ?? 'admin').trim().isEmpty
        ? 'admin'
        : prefs.getString(_usernameKey)!.trim();
  }
}

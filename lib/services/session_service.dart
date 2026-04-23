import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _usernameKey = 'logged_in_username';
  static const _emailKey = 'logged_in_email';
  static const _displayNameKey = 'logged_in_display_name';
  static const _firmNameKey = 'logged_in_firm_name';
  static const _firmIdKey = 'logged_in_firm_id';
  static const _roleKey = 'logged_in_role';
  static const _canManageBillingKey = 'can_manage_billing';
  static const _isPlatformAdminKey = 'is_platform_admin';
  static const _appDisplayNameKey = 'app_display_name';
  static const _appLogoDataKey = 'app_logo_data';

  static Future<void> saveSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, (session['username'] ?? 'admin').toString());
    await prefs.setString(_emailKey, (session['email'] ?? '').toString());
    await prefs.setString(
      _displayNameKey,
      (session['display_name'] ?? session['full_name'] ?? session['username'] ?? 'User').toString(),
    );
    await prefs.setString(_firmNameKey, (session['firm_name'] ?? 'Default Firm').toString());
    await prefs.setInt(_firmIdKey, (session['firm_id'] is num) ? (session['firm_id'] as num).toInt() : 0);
    await prefs.setString(_roleKey, (session['role'] ?? 'lawyer').toString());
    await prefs.setBool(
      _canManageBillingKey,
      session['can_manage_billing'] == true ||
          (session['role'] ?? '').toString() == 'firm_admin',
    );
    await prefs.setBool(_isPlatformAdminKey, session['is_platform_admin'] == true);
    await prefs.setString(
      _appDisplayNameKey,
      (session['app_display_name'] ??
              (session['firm'] is Map ? (session['firm']['app_display_name']) : '') ??
              '')
          .toString(),
    );
    await prefs.setString(
      _appLogoDataKey,
      (session['app_logo_data'] ??
              (session['firm'] is Map ? (session['firm']['app_logo_data']) : '') ??
              '')
          .toString(),
    );
  }

  static Future<Map<String, dynamic>> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString(_usernameKey),
      'email': prefs.getString(_emailKey),
      'display_name': prefs.getString(_displayNameKey),
      'firm_name': prefs.getString(_firmNameKey),
      'firm_id': prefs.getInt(_firmIdKey),
      'role': prefs.getString(_roleKey),
      'can_manage_billing': prefs.getBool(_canManageBillingKey) ?? false,
      'is_platform_admin': prefs.getBool(_isPlatformAdminKey) ?? false,
      'app_display_name': prefs.getString(_appDisplayNameKey),
      'app_logo_data': prefs.getString(_appLogoDataKey),
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_firmNameKey);
    await prefs.remove(_firmIdKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_canManageBillingKey);
    await prefs.remove(_isPlatformAdminKey);
    await prefs.remove(_appDisplayNameKey);
    await prefs.remove(_appLogoDataKey);
  }

  static Future<String> getLoggedInUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final email = (prefs.getString(_emailKey) ?? '').trim();
    if (email.isNotEmpty) {
      return email;
    }
    return (prefs.getString(_usernameKey) ?? 'admin').trim().isEmpty
        ? 'admin'
        : prefs.getString(_usernameKey)!.trim();
  }

  static Future<String> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_displayNameKey) ?? prefs.getString(_usernameKey) ?? 'User').trim();
  }

  static Future<String> getFirmName() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_firmNameKey) ?? 'Default Firm').trim().isEmpty
        ? 'Default Firm'
        : prefs.getString(_firmNameKey)!.trim();
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_roleKey) ?? 'lawyer').trim().isEmpty
        ? 'lawyer'
        : prefs.getString(_roleKey)!.trim();
  }

  static Future<bool> canManageBilling() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_canManageBillingKey) ?? false;
  }
}

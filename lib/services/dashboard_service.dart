import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'session_service.dart';

class DashboardService {
  static const String baseUrl = "${AppConfig.backendBaseUrl}/dashboard";

  static Future<Map<String, String>> _authHeaders() async {
    final username = await SessionService.getLoggedInUsername();
    return {'X-Username': username};
  }

  static Future<Uri> _authorizedUri(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final username = await SessionService.getLoggedInUsername();
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: {
        ...?queryParameters,
        'username': username,
      },
    );
  }

  /// ✅ Fetch Dashboard Data
  static Future<Map<String, dynamic>> fetchDashboardData(
      {bool all = false}) async {
    final uri = await _authorizedUri(
      '/stats',
      queryParameters: all ? {'limit': 'all'} : null,
    );
    final response = await http.get(uri, headers: await _authHeaders());

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load dashboard data");
    }
  }

  static Future<Map<String, dynamic>> fetchFinanceReport() async {
    final username = await SessionService.getLoggedInUsername();
    final response = await http.get(
      Uri.parse("${AppConfig.backendBaseUrl}/payments/report")
          .replace(queryParameters: {'username': username}),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load finance report");
    }
  }

  /// ✅ Rename Document
  static Future<void> renameDocument(String oldName, String newName) async {
    final url = "$baseUrl/rename";

    final response = await http.post(
      await _authorizedUri('/rename'),
      headers: {
        ...await _authHeaders(),
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "old_name": oldName,
        "new_name": newName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to rename document");
    }
  }

  /// ✅ Delete Document
  static Future<void> deleteDocument(String filename) async {
    final url = "$baseUrl/delete";

    final response = await http.post(
      await _authorizedUri('/delete'),
      headers: {
        ...await _authHeaders(),
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "filename": filename,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to delete document");
    }
  }
}

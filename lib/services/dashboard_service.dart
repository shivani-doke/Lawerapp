import 'dart:convert';
import 'package:http/http.dart' as http;

class DashboardService {
  static const String baseUrl = "http://127.0.0.1:5000/dashboard";

  /// ✅ Fetch Dashboard Data
  static Future<Map<String, dynamic>> fetchDashboardData(
      {bool all = false}) async {
    final url = all ? "$baseUrl/stats?limit=all" : "$baseUrl/stats";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load dashboard data");
    }
  }

  /// ✅ Rename Document
  static Future<void> renameDocument(String oldName, String newName) async {
    final url = "$baseUrl/rename";

    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
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
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "filename": filename,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to delete document");
    }
  }
}

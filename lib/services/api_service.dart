import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import 'session_service.dart';

class ApiService {
  static const String baseUrl = AppConfig.backendBaseUrl;
  static String _fieldLanguage = 'English';

  static void setFieldLanguage(String language) {
    _fieldLanguage = language.trim().isEmpty ? 'English' : language;
  }

  Future<Map<String, String>> _authHeaders({
    Map<String, String>? extra,
  }) async {
    final username = await SessionService.getLoggedInUsername();
    return {
      'X-Username': username,
      ...?extra,
    };
  }

  Future<Uri> _authorizedUri(
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

  // -------------------------------------------------------------------------
  // Existing methods
  // -------------------------------------------------------------------------

  /// Extract fields from a reference document using Gemini.
  Future<List<dynamic>> extractFieldsFromReference(
    PlatformFile file, {
    required String documentType,
    String? subtype,
    String? language,
  }) async {
    var uri = await _authorizedUri('/extract_fields');
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authHeaders());

    if (kIsWeb) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
          contentType: MediaType(
            'application',
            'vnd.openxmlformats-officedocument.wordprocessingml.document',
          ),
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ),
      );
    }

    request.fields['document_type'] = documentType;
    request.fields['language'] = language ?? _fieldLanguage;
    if (subtype != null && subtype.isNotEmpty) {
      request.fields['subtype'] = subtype;
    }
    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to extract fields: $responseBody');
    }
  }

  /// Load backend-defined fields directly by document type.
  Future<List<dynamic>> getFieldsByDocumentType({
    required String documentType,
    String? subtype,
    String? language,
  }) async {
    final body = <String, String>{
      'document_type': documentType,
      'language': language ?? _fieldLanguage,
    };
    if (subtype != null && subtype.isNotEmpty) {
      body['subtype'] = subtype;
    }

    final uri = await _authorizedUri('/extract_fields');
    final response = await http.post(
      uri,
      headers: await _authHeaders(),
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load fields: ${response.body}');
    }
  }

  /// Generate a final document using either a new file or a saved reference.
  /// Optional [format] can be 'table' or 'blank' to choose template style.
  Future<Map<String, dynamic>> generateDocument({
    required String documentType,
    required Map<String, dynamic> fields,
    PlatformFile? referenceFile,
    String? referenceId,
    String? format, // NEW: 'table' or 'blank'
    String? language,
    String? fontFamily,
    int? fontSize,
  }) async {
    var uri = await _authorizedUri('/generate-document');
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authHeaders());

    request.fields['document_type'] = documentType;
    request.fields['fields'] = jsonEncode(fields);
    if (format != null) {
      request.fields['format'] = format; // Send format to backend
    }
    if (language != null && language.isNotEmpty) {
      request.fields['language'] = language;
    }
    if (fontFamily != null && fontFamily.isNotEmpty) {
      request.fields['font_family'] = fontFamily;
    }
    if (fontSize != null) {
      request.fields['font_size'] = fontSize.toString();
    }

    if (referenceId != null) {
      request.fields['reference_id'] = referenceId;
    } else if (referenceFile != null) {
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'reference_file',
            referenceFile.bytes!,
            filename: referenceFile.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'reference_file',
            referenceFile.path!,
            filename: referenceFile.name,
          ),
        );
      }
    }

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to generate document: $responseBody');
    }
  }

  /// Download a generated document (PDF or DOCX).
  Future<void> downloadGeneratedDocument(String filename) async {
    final username = await SessionService.getLoggedInUsername();
    final url = '$baseUrl/download/$filename?username=$username';

    if (kIsWeb) {
      html.AnchorElement anchor = html.AnchorElement(href: url);
      anchor.download = filename;
      anchor.click();
    } else {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);
      } else {
        throw Exception('Download failed');
      }
    }
  }

  /// Retrieve the content of a generated document (for editing).
  Future<Map<String, dynamic>> getDocumentContent(String filename) async {
    final url = await _authorizedUri('/generated-document-content/$filename');
    final response = await http.get(url, headers: await _authHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load document content');
    }
  }

  /// Update a generated document after editing.
  Future<void> updateDocument(
    String filename,
    String content, {
    String? html,
    String? fontFamily,
    int? fontSize,
    String? lineSpacing,
  }) async {
    final url = await _authorizedUri('/generated-document-content/$filename');
    final response = await http.post(
      url,
      headers: await _authHeaders(
        extra: {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({
        'content': content,
        if (html != null) 'html': html,
        if (fontFamily != null) 'font_family': fontFamily,
        if (fontSize != null) 'font_size': fontSize,
        if (lineSpacing != null) 'line_spacing': lineSpacing,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update document');
    }
  }

  // -------------------------------------------------------------------------
  // New methods for saved references
  // -------------------------------------------------------------------------

  /// Upload a reference document, extract fields, and save it on the server.
  Future<Map<String, dynamic>> uploadReference(
    PlatformFile file,
    String documentType, {
    String? subtype,
    String? language,
  }
  ) async {
    var uri = await _authorizedUri('/upload_reference');
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authHeaders());

    if (kIsWeb) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ),
      );
    }

    request.fields['document_type'] = documentType;
    request.fields['language'] = language ?? _fieldLanguage;
    if (subtype != null && subtype.isNotEmpty) {
      request.fields['subtype'] = subtype;
    }
    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to upload reference: $responseBody');
    }
  }

  /// List all saved references, optionally filtered by document type.
  Future<List<Map<String, dynamic>>> listReferences(
      {String? documentType}) async {
    final uri = await _authorizedUri('/list_references', queryParameters:
          documentType != null ? {'document_type': documentType} : {});
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load references: ${response.body}');
    }
  }

  Future<List<Map<String, String>>> getDocumentSubtypes({
    required String documentType,
  }) async {
    final uri = await _authorizedUri(
      '/document_subtypes',
      queryParameters: {'document_type': documentType},
    );
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode != 200) {
      return [];
    }
    final data = jsonDecode(response.body);
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return {
            'id': (map['id'] ?? '').toString(),
            'label': (map['label'] ?? '').toString(),
          };
        })
        .where((item) => (item['id'] ?? '').isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    final response = await http.get(
      await _authorizedUri('/clients/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load clients: ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Login failed');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> signup({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Signup failed');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getAuthSettings() async {
    final response = await http.get(
      await _authorizedUri('/auth/settings'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load login settings: ${response.body}');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> updateAuthSettings({
    required String currentUsername,
    required String currentPassword,
    required String newUsername,
    required String newPassword,
  }) async {
    final response = await http.put(
      await _authorizedUri('/auth/settings'),
      headers: await _authHeaders(
        extra: {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({
        'current_username': currentUsername,
        'current_password': currentPassword,
        'new_username': newUsername,
        'new_password': newPassword,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Failed to update login settings',
      );
    }

    return Map<String, dynamic>.from(data);
  }

  /// Retrieve the fields for a specific saved reference.
  Future<List<dynamic>> getReferenceFields(
    String documentId, {
    String? language,
  }) async {
    final uri = await _authorizedUri(
      '/get_reference/$documentId',
      queryParameters: {
        'language': language ?? _fieldLanguage,
      },
    );
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load fields: ${response.body}');
    }
  }

  /// Get the URL to preview a saved reference document.
  /// This can be used to open the document in a new browser tab.
  Future<String> getReferencePreviewUrl(String documentId) async {
    final username = await SessionService.getLoggedInUsername();
    return '$baseUrl/references/$documentId/view?username=$username';
  }
}

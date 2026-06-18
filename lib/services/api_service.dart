import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
    final firmName = await SessionService.getFirmName();
    return {
      'X-Username': username,
      'X-Firm-Name': firmName,
      ...?extra,
    };
  }

  Future<Uri> _authorizedUri(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final username = await SessionService.getLoggedInUsername();
    final firmName = await SessionService.getFirmName();
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: {
        ...?queryParameters,
        'username': username,
        'firm_name': firmName,
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
    final firmName = await SessionService.getFirmName();
    final url =
        '$baseUrl/download/$filename?username=$username&firm_name=$firmName';

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
    List<dynamic>? extractedFields,
  }) async {
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
    if (extractedFields != null) {
      request.fields['extracted_fields'] = jsonEncode(extractedFields);
    }
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
    final uri = await _authorizedUri('/list_references',
        queryParameters:
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

  Future<Map<String, dynamic>> masterLogin({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/master-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Master login failed');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Login failed');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getFirms() async {
    final response = await http.get(
      await _authorizedUri('/auth/firms'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load firms: ${response.body}');
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

  Future<Map<String, dynamic>> createFirm({
    required String firmName,
    required String adminFullName,
    required String adminEmail,
    required String adminPassword,
    required int maxTeamMembers,
    String? adminUsername,
  }) async {
    final response = await http.post(
      await _authorizedUri('/auth/firms'),
      headers: await _authHeaders(
        extra: {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({
        'firm_name': firmName,
        'admin_full_name': adminFullName,
        'admin_email': adminEmail,
        'admin_password': adminPassword,
        'max_team_members': maxTeamMembers,
        if (adminUsername != null && adminUsername.trim().isNotEmpty)
          'admin_username': adminUsername.trim(),
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(
        (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Failed to create firm',
      );
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateFirm({
    required int firmId,
    required int maxTeamMembers,
  }) async {
    final response = await http.put(
      await _authorizedUri('/auth/firms/$firmId'),
      headers: await _authHeaders(
        extra: {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({
        'max_team_members': maxTeamMembers,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Failed to update firm',
      );
    }

    return Map<String, dynamic>.from(data);
  }

  Future<void> deleteFirm(int firmId) async {
    final response = await http.delete(
      await _authorizedUri('/auth/firms/$firmId'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(
        (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Failed to delete firm',
      );
    }
  }

  Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
    required String firmName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        'firm_name': firmName,
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

  Future<Map<String, dynamic>> getFirmBranding() async {
    final response = await http.get(
      await _authorizedUri('/auth/firm-branding'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load app branding: ${response.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> getMailboxStatus() async {
    final response = await http.get(
      await _authorizedUri('/auth/mailbox/status'),
      headers: await _authHeaders(),
    );
    final data = _decodeJsonObject(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (data['error'] ?? 'Failed to load mailbox status').toString(),
      );
    }
    return data;
  }

  Future<String> getGoogleMailboxConnectUrl() async {
    final response = await http.get(
      await _authorizedUri('/auth/mailbox/google/connect-url'),
      headers: await _authHeaders(),
    );
    final data = _decodeJsonObject(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (data['error'] ?? 'Failed to start Gmail connection').toString(),
      );
    }
    final authUrl = (data['auth_url'] ?? '').toString();
    if (authUrl.trim().isEmpty) {
      throw Exception('The server did not return a Gmail connect URL.');
    }
    return authUrl;
  }

  Future<void> disconnectMailbox() async {
    final response = await http.delete(
      await _authorizedUri('/auth/mailbox'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      final data = _decodeJsonObject(response.body);
      throw Exception(
        (data['error'] ?? 'Failed to disconnect mailbox').toString(),
      );
    }
  }

  Future<Map<String, dynamic>> updateFirmBranding({
    required String appDisplayName,
    String? appLogoData,
    bool clearLogo = false,
  }) async {
    final response = await http.put(
      await _authorizedUri('/auth/firm-branding'),
      headers: await _authHeaders(
        extra: {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({
        'app_display_name': appDisplayName,
        if (appLogoData != null) 'app_logo_data': appLogoData,
        'clear_logo': clearLogo,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Failed to update app branding',
      );
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateAuthSettings({
    required String currentUsername,
    required String currentEmail,
    required String currentPassword,
    required String newUsername,
    required String newEmail,
    required String newFullName,
    required String newPassword,
  }) async {
    final response = await http.put(
      await _authorizedUri('/auth/settings'),
      headers: await _authHeaders(
        extra: {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({
        'current_username': currentUsername,
        'current_email': currentEmail,
        'current_password': currentPassword,
        'new_username': newUsername,
        'new_email': newEmail,
        'new_full_name': newFullName,
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

  Future<List<Map<String, dynamic>>> getTeamUsers() async {
    final response = await http.get(
      await _authorizedUri('/auth/team'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load team members: ${response.body}');
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

  Future<Map<String, dynamic>> getTeamSummary() async {
    final response = await http.get(
      await _authorizedUri('/auth/team/summary'),
      headers: await _authHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Failed to load team summary',
      );
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> createTeamUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      await _authorizedUri('/auth/team'),
      headers: await _authHeaders(
        extra: {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(
        (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Failed to create team member',
      );
    }

    return Map<String, dynamic>.from(data);
  }

  Future<void> deleteTeamUser(int userId) async {
    final response = await http.delete(
      await _authorizedUri('/auth/team/$userId'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(
        (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Failed to delete team member',
      );
    }
  }

  Future<Map<String, dynamic>> fetchCasesByAdvocate({
    required String advocates,
    String? courtCodes,
    String? filingDateFrom,
    String? filingDateTo,
    String? caseStatus,
    String? caseType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParameters = <String, String>{
      'advocates': advocates.trim(),
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    void addIfPresent(String key, String? value) {
      final normalized = (value ?? '').trim();
      if (normalized.isNotEmpty) {
        queryParameters[key] = normalized;
      }
    }

    addIfPresent('courtCodes', courtCodes);
    addIfPresent('filingDateFrom', filingDateFrom);
    addIfPresent('filingDateTo', filingDateTo);
    addIfPresent('caseStatus', caseStatus);
    addIfPresent('caseType', caseType);

    final response = await http.get(
      await _authorizedUri(
        '/ecourts/cases-by-advocate',
        queryParameters: queryParameters,
      ),
      headers: await _authHeaders(),
    );

    final data = _decodeJsonObject(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (data['error'] ?? data['message'] ?? 'Failed to fetch cases')
            .toString(),
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> fetchCaseByCnr(String cnr) async {
    final response = await http.get(
      await _authorizedUri('/ecourts/case/${Uri.encodeComponent(cnr.trim())}'),
      headers: await _authHeaders(),
    );

    final data = _decodeJsonObject(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (data['error'] ?? data['message'] ?? 'Failed to fetch case detail')
            .toString(),
      );
    }

    return data;
  }

  Map<String, dynamic> _decodeJsonObject(String responseBody) {
    if (responseBody.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception('Unexpected response format');
  }

  Future<Map<String, dynamic>> uploadSmartLegalDocument(
    PlatformFile file,
  ) async {
    final uri =
        Uri.parse('${AppConfig.smartLegalBaseUrl}/api/documents/upload');
    final request = http.MultipartRequest('POST', uri);

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Unable to read the selected file');
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'document',
          bytes,
          filename: file.name,
        ),
      );
    } else {
      final filePath = file.path;
      if (filePath == null || filePath.isEmpty) {
        throw Exception('Unable to read the selected file');
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          'document',
          filePath,
          filename: file.name,
        ),
      );
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final data = _decodeJsonObject(responseBody);

    if (response.statusCode != 201) {
      throw Exception(
        (data['error'] ?? data['message'] ?? 'Failed to upload document')
            .toString(),
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> getSmartLegalWordDraft(String documentId) async {
    final response = await http.get(
      Uri.parse(
        '${AppConfig.smartLegalBaseUrl}/api/documents/$documentId/word-draft',
      ),
    );
    final data = _decodeJsonObject(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        (data['error'] ?? data['message'] ?? 'Failed to extract text')
            .toString(),
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> generateSmartLegalPdf(
    String documentId, {
    required String html,
    List<Map<String, dynamic>>? pageSizes,
    String? fontFamily,
    double? fontSize,
    double? lineSpacing,
  }) async {
    final Map<String, dynamic> body = {'html': html};
    if (pageSizes != null && pageSizes.isNotEmpty) {
      body['pageSizes'] = pageSizes;
    }
    if (fontFamily != null && fontFamily.trim().isNotEmpty) {
      body['fontFamily'] = fontFamily.trim();
    }
    if (fontSize != null) {
      body['fontSize'] = fontSize;
    }
    if (lineSpacing != null) {
      body['lineSpacing'] = lineSpacing;
    }
    final response = await http.post(
      Uri.parse(
        '${AppConfig.smartLegalBaseUrl}/api/documents/$documentId/generate-word-pdf',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decodeJsonObject(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        (data['error'] ?? data['message'] ?? 'Failed to generate PDF')
            .toString(),
      );
    }

    return data;
  }

  Future<String> getSmartLegalSourceUrl(String documentId) async {
    final username = await SessionService.getLoggedInUsername();
    final firmName = await SessionService.getFirmName();
    return Uri.parse(
      '${AppConfig.smartLegalBaseUrl}/api/documents/$documentId/source',
    ).replace(
      queryParameters: {
        'username': username,
        'firm_name': firmName,
      },
    ).toString();
  }

  Future<void> downloadPdfBytes(String filename, Uint8List bytes) async {
    if (kIsWeb) {
      final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = filename
        ..click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
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
    final firmName = await SessionService.getFirmName();
    return '$baseUrl/references/$documentId/view?username=$username&firm_name=$firmName';
  }
}

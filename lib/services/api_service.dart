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

class ApiService {
  static const String baseUrl = AppConfig.backendBaseUrl;
  static String _fieldLanguage = 'English';

  static void setFieldLanguage(String language) {
    _fieldLanguage = language.trim().isEmpty ? 'English' : language;
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
    var uri = Uri.parse('$baseUrl/extract_fields');
    var request = http.MultipartRequest('POST', uri);

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

    final uri = Uri.parse('$baseUrl/extract_fields');
    final response = await http.post(uri, body: body);

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
    var uri = Uri.parse('$baseUrl/generate-document');
    var request = http.MultipartRequest('POST', uri);

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
    final url = '$baseUrl/download/$filename';

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

  /// Retrieve the content of a document (for editing).
  Future<String> getDocumentContent(String filename) async {
    final url = Uri.parse('$baseUrl/document-content/$filename');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'];
    } else {
      throw Exception('Failed to load document content');
    }
  }

  /// Update a document after editing.
  Future<void> updateDocument(String filename, String content) async {
    final url = Uri.parse('$baseUrl/update-document/$filename');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'content': content}),
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
    var uri = Uri.parse('$baseUrl/upload_reference');
    var request = http.MultipartRequest('POST', uri);

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
    final uri = Uri.parse('$baseUrl/list_references').replace(
      queryParameters:
          documentType != null ? {'document_type': documentType} : {},
    );
    final response = await http.get(uri);
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
    final uri = Uri.parse('$baseUrl/document_subtypes').replace(
      queryParameters: {'document_type': documentType},
    );
    final response = await http.get(uri);
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

  /// Retrieve the fields for a specific saved reference.
  Future<List<dynamic>> getReferenceFields(
    String documentId, {
    String? language,
  }) async {
    final uri = Uri.parse('$baseUrl/get_reference/$documentId').replace(
      queryParameters: {
        'language': language ?? _fieldLanguage,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load fields: ${response.body}');
    }
  }

  /// Get the URL to preview a saved reference document.
  /// This can be used to open the document in a new browser tab.
  String getReferencePreviewUrl(String documentId) {
    return '$baseUrl/references/$documentId/view';
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000'; // Change as needed

  // -------------------------------------------------------------------------
  // Existing methods
  // -------------------------------------------------------------------------

  /// Extract fields from a reference document using Gemini.
  Future<List<dynamic>> extractFieldsFromReference(
    PlatformFile file, {
    required String documentType,
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
    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to extract fields: $responseBody');
    }
  }

  /// Generate a final document using either a new file or a saved reference.
  Future<Map<String, dynamic>> generateDocument({
    required String documentType,
    required Map<String, String> fields,
    PlatformFile? referenceFile,
    String? referenceId,
  }) async {
    var uri = Uri.parse('$baseUrl/generate-document');
    var request = http.MultipartRequest('POST', uri);

    request.fields['document_type'] = documentType;
    request.fields['fields'] = jsonEncode(fields);

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
    } else {
      throw Exception('Either referenceFile or referenceId must be provided');
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
    String documentType,
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

  /// Retrieve the fields for a specific saved reference.
  Future<List<dynamic>> getReferenceFields(String documentId) async {
    final uri = Uri.parse('$baseUrl/get_reference/$documentId');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load fields: ${response.body}');
    }
  }
}

// import 'dart:convert';
// import 'dart:io';
// import 'package:file_picker/file_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';
// import 'package:path/path.dart' as path;
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:universal_html/html.dart' as html;
// import 'package:path_provider/path_provider.dart';

// class ApiService {
//   static const String baseUrl = 'http://127.0.0.1:5000'; // Change as needed

//   Future<List<dynamic>> extractFieldsFromReference(PlatformFile file,
//       {required String documentType}) async {
//     var uri = Uri.parse('$baseUrl/extract_fields');
//     var request = http.MultipartRequest('POST', uri);

//     if (kIsWeb) {
//       // Web: use bytes
//       request.files.add(
//         http.MultipartFile.fromBytes(
//           'file',
//           file.bytes!,
//           filename: file.name,
//           contentType: MediaType('application',
//               'vnd.openxmlformats-officedocument.wordprocessingml.document'),
//         ),
//       );
//     } else {
//       // Mobile/Desktop: use file path
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'file',
//           file.path!,
//           filename: file.name,
//         ),
//       );
//     }

//     request.fields['document_type'] = documentType;

//     var response = await request.send();
//     var responseBody = await response.stream.bytesToString();

//     if (response.statusCode == 200) {
//       return jsonDecode(responseBody);
//     } else {
//       throw Exception('Failed to extract fields: $responseBody');
//     }
//   }

//   Future<Map<String, dynamic>> generateDocument({
//     required String documentType,
//     required Map<String, String> fields,
//     required PlatformFile referenceFile,
//   }) async {
//     var uri = Uri.parse('$baseUrl/generate-document');
//     var request = http.MultipartRequest('POST', uri);

//     // Add fields as JSON
//     request.fields['document_type'] = documentType;
//     request.fields['fields'] = jsonEncode(fields);

//     // Attach the reference file
//     if (kIsWeb) {
//       request.files.add(
//         http.MultipartFile.fromBytes(
//           'reference_file',
//           referenceFile.bytes!,
//           filename: referenceFile.name,
//         ),
//       );
//     } else {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'reference_file',
//           referenceFile.path!,
//           filename: referenceFile.name,
//         ),
//       );
//     }

//     var response = await request.send();
//     var responseBody = await response.stream.bytesToString();

//     if (response.statusCode == 200) {
//       return jsonDecode(responseBody);
//     } else {
//       throw Exception('Failed to generate document: $responseBody');
//     }
//   }

//   Future<void> downloadGeneratedDocument(String filename) async {
//     final url = '$baseUrl/download/$filename';

//     if (kIsWeb) {
//       // Web: trigger download via anchor tag
//       html.AnchorElement anchor = html.AnchorElement(href: url);
//       anchor.download = filename;
//       anchor.click();
//     } else {
//       // Mobile/Desktop: save file using path_provider
//       var response = await http.get(Uri.parse(url));
//       if (response.statusCode == 200) {
//         final directory = await getApplicationDocumentsDirectory();
//         final file = File('${directory.path}/$filename');
//         await file.writeAsBytes(response.bodyBytes);
//         // Optionally open the file
//       } else {
//         throw Exception('Download failed');
//       }
//     }
//   }

//   Future<String> getDocumentContent(String filename) async {
//     final url = Uri.parse('$baseUrl/document-content/$filename');
//     final response = await http.get(url);
//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       return data['content'];
//     } else {
//       throw Exception('Failed to load document content');
//     }
//   }

//   Future<void> updateDocument(String filename, String content) async {
//     final url = Uri.parse('$baseUrl/update-document/$filename');
//     final response = await http.post(
//       url,
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'content': content}),
//     );
//     if (response.statusCode != 200) {
//       throw Exception('Failed to update document');
//     }
//   }
// }

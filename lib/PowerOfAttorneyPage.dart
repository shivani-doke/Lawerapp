import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Simple model for a dynamic document field
class DocumentField {
  final String name;
  final String label;
  final String type;
  final String? hint;
  final bool required;

  DocumentField({
    required this.name,
    required this.label,
    this.type = 'text',
    this.hint,
    this.required = true,
  });
}

class PowerOfAttorneyPage extends StatefulWidget {
  const PowerOfAttorneyPage({super.key});

  @override
  State<PowerOfAttorneyPage> createState() => _PowerOfAttorneyPageState();
}

class _PowerOfAttorneyPageState extends State<PowerOfAttorneyPage> {
  static const Color accentColor = Color(0xffE0A800);

  // Dynamic fields (from extraction or default)
  List<DocumentField> _fields = [];
  final Map<String, TextEditingController> _fieldControllers = {};

  // Reference document (used for both extraction and generation)
  PlatformFile? _referenceFile;

  // UI state
  bool _isGenerating = false;
  bool _isExtracting = false;

  // Generated document info
  String? _generatedFilePath;
  String? _documentContent; // plain text of the document
  bool _isEditing = false; // whether we are in edit mode
  final TextEditingController _editorController = TextEditingController();

  @override
  void dispose() {
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    _editorController.dispose();
    super.dispose();
  }

  // Fallback default fields (used when extraction fails or no file is uploaded)
  void _resetToDefaultFields() {
    _fields = [
      DocumentField(
          name: 'principal',
          label: "Principal's Full Name",
          hint: 'Person granting authority'),
      DocumentField(
          name: 'agent',
          label: "Agent's Full Name",
          hint: 'Person receiving authority'),
      DocumentField(
          name: 'purpose',
          label: 'Purpose / Scope of Authority',
          type: 'multiline',
          hint: 'Describe the powers being granted...'),
      DocumentField(name: 'date', label: 'Date of Execution', type: 'date'),
      DocumentField(
          name: 'conditions',
          label: 'Conditions & Limitations',
          type: 'multiline',
          hint: 'Any restrictions on the authority...'),
    ];
    _rebuildControllers();
  }

  // Rebuild text controllers when fields change
  void _rebuildControllers() {
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    _fieldControllers.clear();
    for (var field in _fields) {
      _fieldControllers[field.name] = TextEditingController();
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _resetToDefaultFields();
  }

  // Pick a reference file (DOCX, PDF, TXT) for field extraction
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf', 'txt'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        _referenceFile = result.files.first;
        _isExtracting = true;
        // Clear any previously generated document
        _generatedFilePath = null;
        _documentContent = null;
      });

      try {
        final extractedFields = await ApiService().extractFieldsFromReference(
          _referenceFile!,
          documentType: 'power_of_attorney',
        );

        setState(() {
          _fields = extractedFields.map<DocumentField>((json) {
            return DocumentField(
              name: json['name'],
              label: json['label'],
              type: json['type'] ?? 'text',
              hint: json['hint'],
              required: json['required'] ?? true,
            );
          }).toList();
          _isExtracting = false;
        });

        _rebuildControllers();
      } catch (e) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Field extraction failed: $e\nUsing default fields.')),
        );
      }
    }
  }

  // Clear the uploaded file and revert to default fields
  void _clearFile() {
    setState(() {
      _referenceFile = null;
      _resetToDefaultFields();
      _generatedFilePath = null;
      _documentContent = null;
    });
  }

  // Generate document using Gemini (reference file + field values)
  Future<void> _generateDocument() async {
    // Check required fields
    final missingFields = _fields.where((f) {
      final value = _fieldControllers[f.name]?.text ?? '';
      return f.required && value.isEmpty;
    }).toList();

    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please fill all required fields: ${missingFields.map((f) => f.label).join(', ')}'),
        ),
      );
      return;
    }

    if (_referenceFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload a reference document first')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedFilePath = null;
      _documentContent = null;
    });

    try {
      final fields = {
        for (var field in _fields)
          field.name: _fieldControllers[field.name]?.text ?? '',
      };

      final response = await ApiService().generateDocument(
        documentType: 'power_of_attorney',
        fields: fields,
        referenceFile: _referenceFile!,
      );

      final filename = response['file_path'];
      setState(() {
        _generatedFilePath = filename;
        _isGenerating = false;
      });

      // Automatically fetch the content for viewing/editing
      await _loadDocumentContent(filename);
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Fetch the plain text content of the generated document
  Future<void> _loadDocumentContent(String filename) async {
    try {
      final content = await ApiService().getDocumentContent(filename);
      setState(() {
        _documentContent = content;
        _editorController.text = content;
        _isEditing = false; // start in view mode
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load document: $e')),
      );
    }
  }

  // Save edited content back to the server
  Future<void> _saveDocument() async {
    if (_generatedFilePath == null) return;
    setState(() => _isEditing = false);
    try {
      await ApiService()
          .updateDocument(_generatedFilePath!, _editorController.text);
      // Refresh content after save
      await _loadDocumentContent(_generatedFilePath!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  // Download the generated DOCX file
  Future<void> _downloadDocument() async {
    if (_generatedFilePath == null) return;

    try {
      await ApiService().downloadGeneratedDocument(_generatedFilePath!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  // Date picker for date fields
  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = "${picked.day.toString().padLeft(2, '0')}-"
          "${picked.month.toString().padLeft(2, '0')}-"
          "${picked.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xfff5f6f8),
      padding: const EdgeInsets.all(30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE – Field input form
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "AUTHORIZATION",
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Power of Attorney",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Show loading indicator while extracting fields
                    if (_isExtracting)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ))
                    else
                      ..._fields.map((field) => _buildField(field)),

                    const SizedBox(height: 20),

                    // File picker row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: Text(
                              _referenceFile != null
                                  ? 'File: ${_referenceFile!.name}'
                                  : 'Upload Reference Document',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: accentColor, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              foregroundColor: accentColor,
                            ),
                          ),
                        ),
                        if (_referenceFile != null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _clearFile,
                          ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Generate button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isGenerating ||
                                _isExtracting ||
                                _referenceFile == null)
                            ? null
                            : _generateDocument,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(_isGenerating
                            ? 'Generating...'
                            : 'Generate Document'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 30),

          // RIGHT SIDE – Document viewer/editor
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: _documentContent == null
                  ? _buildPlaceholder()
                  : _buildDocumentEditor(),
            ),
          ),
        ],
      ),
    );
  }

  // Build an input field based on its type
  Widget _buildField(DocumentField field) {
    final controller = _fieldControllers[field.name]!;

    if (field.type == 'date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label + (field.required ? ' *' : '')),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              readOnly: true,
              onTap: () => _selectDate(controller),
              decoration: InputDecoration(
                hintText: field.hint ?? 'dd-mm-yyyy',
                suffixIcon: const Icon(Icons.calendar_today),
                filled: true,
                fillColor: const Color(0xfff9fafb),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (field.type == 'multiline') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label + (field.required ? ' *' : '')),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: field.hint,
                filled: true,
                fillColor: const Color(0xfff9fafb),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label + (field.required ? ' *' : '')),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: field.hint,
                filled: true,
                fillColor: const Color(0xfff9fafb),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // Placeholder shown before any document is generated
  Widget _buildPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 50, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            "Ready to Generate",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Fill in the details on the left, then click\n\"Generate Document\" to create your Power of Attorney.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Document viewer/editor panel
  Widget _buildDocumentEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Generated Document",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                // Edit / Save toggle
                if (!_isEditing)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                  ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _saveDocument,
                  ),
                // Always show download button
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _downloadDocument,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff9fafb),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isEditing
                ? TextField(
                    controller: _editorController,
                    maxLines: null, // unlimited lines
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Edit your document...',
                    ),
                  )
                : SingleChildScrollView(
                    child: Text(
                      _documentContent ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:universal_html/html.dart' as html;
// import 'package:universal_io/io.dart'; // cross‑platform File
// import '../services/api_service.dart';
// import 'package:flutter/foundation.dart' show kIsWeb;

// class PowerOfAttorneyPage extends StatefulWidget {
//   const PowerOfAttorneyPage({super.key});

//   @override
//   State<PowerOfAttorneyPage> createState() => _PowerOfAttorneyPageState();
// }

// class _PowerOfAttorneyPageState extends State<PowerOfAttorneyPage> {
//   static const Color accentColor = Color(0xffE0A800);

//   final TextEditingController principalController = TextEditingController();
//   final TextEditingController agentController = TextEditingController();
//   final TextEditingController purposeController = TextEditingController();
//   final TextEditingController dateController = TextEditingController();
//   final TextEditingController conditionsController = TextEditingController();

//   PlatformFile? _referenceFile;
//   bool _isGenerating = false;
//   String? _generatedText;
//   late TextEditingController _generatedController;

//   @override
//   void dispose() {
//     principalController.dispose();
//     agentController.dispose();
//     purposeController.dispose();
//     dateController.dispose();
//     conditionsController.dispose();
//     super.dispose();
//     if (_generatedText != null) {
//       _generatedController.dispose();
//     }
//   }

//   Future<void> _pickFile() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: ['docx', 'txt', 'pdf'],
//     );
//     if (result != null) {
//       setState(() {
//         _referenceFile = result.files.first;
//       });
//     }
//   }

//   void _clearFile() {
//     setState(() {
//       _referenceFile = null;
//     });
//   }

//   Future<void> _generateDocument() async {
//     if (principalController.text.isEmpty ||
//         agentController.text.isEmpty ||
//         purposeController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please fill all required fields')),
//       );
//       return;
//     }

//     setState(() {
//       _isGenerating = true;
//       _generatedText = null;
//     });

//     try {
//       final fields = {
//         'principal': principalController.text,
//         'agent': agentController.text,
//         'purpose': purposeController.text,
//         'date': dateController.text,
//         'conditions': conditionsController.text,
//       };

//       final response = await ApiService().generateDocument(
//         documentType: 'power_of_attorney',
//         fields: fields,
//         referenceFile: _referenceFile,
//       );

//       setState(() {
//         _generatedText = response['generated_text'];
//         _generatedController = TextEditingController(text: _generatedText);
//         _isGenerating = false;
//       });
//     } catch (e) {
//       setState(() => _isGenerating = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     }
//   }

//   Future<void> _downloadDocument() async {
//     if (_generatedText == null) return;

//     if (kIsWeb) {
//       // Web: create a blob and trigger download
//       final blob = html.Blob([_generatedText!], 'text/plain');
//       final url = html.Url.createObjectUrlFromBlob(blob);
//       final anchor = html.AnchorElement(href: url)
//         ..target = 'blank'
//         ..download =
//             'PowerOfAttorney_${DateTime.now().millisecondsSinceEpoch}.txt';
//       anchor.click();
//       html.Url.revokeObjectUrl(url);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Download started')),
//       );
//     } else {
//       // Mobile/Desktop: use file system
//       final directory = await getApplicationDocumentsDirectory();
//       final fileName =
//           'PowerOfAttorney_${DateTime.now().millisecondsSinceEpoch}.txt';
//       final file = File('${directory.path}/$fileName');
//       await file.writeAsString(_generatedText!);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Saved to ${file.path}')),
//       );
//     }
//   }

//   void _editDocument() {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Edit Document'),
//         content: SizedBox(
//           width: 700,
//           child: TextField(
//             controller: _generatedController,
//             maxLines: 20,
//             decoration: const InputDecoration(
//               border: OutlineInputBorder(),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               setState(() {
//                 _generatedText = _generatedController.text;
//               });
//               Navigator.pop(ctx);
//             },
//             child: const Text('Save'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _selectDate() async {
//     final DateTime now = DateTime.now();
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: now,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//     );
//     if (picked != null) {
//       setState(() {
//         dateController.text = "${picked.day.toString().padLeft(2, '0')}-"
//             "${picked.month.toString().padLeft(2, '0')}-"
//             "${picked.year}";
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: const Color(0xfff5f6f8),
//       padding: const EdgeInsets.all(30),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // LEFT SIDE FORM
//           Expanded(
//             flex: 2,
//             child: Container(
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(color: Colors.grey.shade200),
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       "AUTHORIZATION",
//                       style: TextStyle(
//                         color: accentColor,
//                         fontWeight: FontWeight.w600,
//                         fontSize: 12,
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     const Text(
//                       "Power of Attorney",
//                       style: TextStyle(
//                         fontSize: 26,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 20),

//                     _inputField("Principal's Full Name", principalController,
//                         hint: "Person granting authority"),
//                     _inputField("Agent's Full Name", agentController,
//                         hint: "Person receiving authority"),
//                     _multiLineField(
//                         "Purpose / Scope of Authority", purposeController,
//                         hint: "Describe the powers being granted..."),
//                     Padding(
//                       padding: const EdgeInsets.only(bottom: 18),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text("Date of Execution"),
//                           const SizedBox(height: 6),
//                           TextField(
//                             controller: dateController,
//                             readOnly: true,
//                             onTap: _selectDate,
//                             decoration: InputDecoration(
//                               hintText: "dd-mm-yyyy",
//                               suffixIcon: const Icon(Icons.calendar_today),
//                               filled: true,
//                               fillColor: const Color(0xfff9fafb),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     _multiLineField(
//                         "Conditions & Limitations", conditionsController,
//                         hint: "Any restrictions on the authority..."),

//                     const SizedBox(height: 20),

//                     // Reference file picker
//                     Row(
//                       children: [
//                         Expanded(
//                           child: OutlinedButton.icon(
//                             onPressed: _pickFile,
//                             icon: const Icon(Icons.attach_file),
//                             label: Text(
//                               _referenceFile != null
//                                   ? 'File: ${_referenceFile!.name}'
//                                   : 'Add Reference Document',
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             style: OutlinedButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(vertical: 16),
//                               side: BorderSide(color: accentColor, width: 1.5),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               foregroundColor: accentColor,
//                             ),
//                           ),
//                         ),
//                         if (_referenceFile != null)
//                           IconButton(
//                             icon: const Icon(Icons.close),
//                             onPressed: _clearFile,
//                           ),
//                       ],
//                     ),

//                     const SizedBox(height: 15),

//                     // Generate button
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton.icon(
//                         onPressed: _isGenerating ? null : _generateDocument,
//                         icon: _isGenerating
//                             ? const SizedBox(
//                                 width: 20,
//                                 height: 20,
//                                 child: CircularProgressIndicator(
//                                   color: Colors.white,
//                                   strokeWidth: 2,
//                                 ),
//                               )
//                             : const Icon(Icons.auto_awesome),
//                         label: Text(_isGenerating
//                             ? 'Generating...'
//                             : 'Generate Document with AI'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: accentColor,
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           const SizedBox(width: 30),

//           // RIGHT SIDE PREVIEW
//           Expanded(
//             flex: 2,
//             child: Container(
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: const [
//                   BoxShadow(
//                     color: Colors.black12,
//                     blurRadius: 10,
//                     offset: Offset(0, 6),
//                   ),
//                 ],
//               ),
//               child: _generatedText == null
//                   ? _buildPlaceholder()
//                   : _buildGeneratedPreview(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPlaceholder() {
//     return const Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.auto_awesome, size: 50, color: Colors.grey),
//           SizedBox(height: 20),
//           Text(
//             "Ready to Generate",
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             "Fill in the details on the left, then click\n\"Generate Document with AI\" to create your Power of Attorney.",
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.grey),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildGeneratedPreview() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           "Generated Document",
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 10),
//         Expanded(
//           child: Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: const Color(0xfff9fafb),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: SingleChildScrollView(
//               child: Text(
//                 _generatedText!,
//                 style: const TextStyle(fontSize: 14),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 16),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.end,
//           children: [
//             TextButton.icon(
//               onPressed: _editDocument,
//               icon: const Icon(Icons.edit),
//               label: const Text('Edit'),
//             ),
//             const SizedBox(width: 12),
//             ElevatedButton.icon(
//               onPressed: _downloadDocument,
//               icon: const Icon(Icons.download),
//               label: const Text('Download'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: accentColor,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _inputField(String label, TextEditingController controller,
//       {String? hint}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 18),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(label),
//           const SizedBox(height: 6),
//           TextField(
//             controller: controller,
//             decoration: InputDecoration(
//               hintText: hint,
//               filled: true,
//               fillColor: const Color(0xfff9fafb),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _multiLineField(String label, TextEditingController controller,
//       {String? hint}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 18),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(label),
//           const SizedBox(height: 6),
//           TextField(
//             controller: controller,
//             maxLines: 3,
//             decoration: InputDecoration(
//               hintText: hint,
//               filled: true,
//               fillColor: const Color(0xfff9fafb),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
































































// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'dart:io' show File; // Still used for download, but not for upload
// import '../services/api_service.dart';

// class PowerOfAttorneyPage extends StatefulWidget {
//   const PowerOfAttorneyPage({super.key});

//   @override
//   State<PowerOfAttorneyPage> createState() => _PowerOfAttorneyPageState();
// }

// class _PowerOfAttorneyPageState extends State<PowerOfAttorneyPage> {
//   // Text controllers
//   final TextEditingController principalController = TextEditingController();
//   final TextEditingController agentController = TextEditingController();
//   final TextEditingController purposeController = TextEditingController();
//   final TextEditingController dateController = TextEditingController();
//   final TextEditingController conditionsController = TextEditingController();

//   // State variables
//   PlatformFile? _referenceFile; // Changed from File? to PlatformFile?
//   bool _isGenerating = false;
//   String? _generatedText;

//   @override
//   void dispose() {
//     principalController.dispose();
//     agentController.dispose();
//     purposeController.dispose();
//     dateController.dispose();
//     conditionsController.dispose();
//     super.dispose();
//   }

//   /// Pick a reference document (docx, txt, pdf)
//   Future<void> _pickFile() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: ['docx', 'txt', 'pdf'],
//     );
//     if (result != null) {
//       setState(() {
//         _referenceFile = result.files.first; // Now a PlatformFile
//       });
//     }
//   }

//   /// Call backend to generate the document
//   Future<void> _generateDocument() async {
//     // Basic validation
//     if (principalController.text.isEmpty ||
//         agentController.text.isEmpty ||
//         purposeController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please fill all required fields')),
//       );
//       return;
//     }

//     setState(() {
//       _isGenerating = true;
//       _generatedText = null;
//     });

//     try {
//       final fields = {
//         'principal': principalController.text,
//         'agent': agentController.text,
//         'purpose': purposeController.text,
//         'date': dateController.text,
//         'conditions': conditionsController.text,
//       };

//       final response = await ApiService().generateDocument(
//         documentType: 'power_of_attorney',
//         fields: fields,
//         referenceFile: _referenceFile, // Pass PlatformFile directly
//       );

//       setState(() {
//         _generatedText = response['generated_text'];
//         _isGenerating = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isGenerating = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     }
//   }

//   /// Save generated text as a .txt file (can be extended to .docx)
//   Future<void> _downloadDocument() async {
//     if (_generatedText == null) return;

//     final directory = await getApplicationDocumentsDirectory();
//     final fileName =
//         'PowerOfAttorney_${DateTime.now().millisecondsSinceEpoch}.txt';
//     final file =
//         File('${directory.path}/$fileName'); // Uses dart:io (works on mobile)
//     await file.writeAsString(_generatedText!);

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Saved to ${file.path}')),
//     );
//   }

//   /// Open an editable view
//   void _editDocument() {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Edit Document'),
//         content: TextField(
//           maxLines: 15,
//           controller: TextEditingController(text: _generatedText),
//           decoration: const InputDecoration(
//             border: OutlineInputBorder(),
//             hintText: 'Edit your document here...',
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               // You could save the edited version
//               Navigator.pop(ctx);
//             },
//             child: const Text('Save'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: const Color(0xfff5f6f8),
//       padding: const EdgeInsets.all(30),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           /// ================= LEFT SIDE FORM =================
//           Expanded(
//             flex: 2,
//             child: Container(
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(color: Colors.grey.shade200),
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       "AUTHORIZATION",
//                       style: TextStyle(
//                         color: Color(0xffE0A800),
//                         fontWeight: FontWeight.w600,
//                         fontSize: 12,
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     const Text(
//                       "Power of Attorney",
//                       style: TextStyle(
//                         fontSize: 26,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 20),

//                     _inputField("Principal's Full Name", principalController,
//                         hint: "Person granting authority"),
//                     _inputField("Agent's Full Name", agentController,
//                         hint: "Person receiving authority"),
//                     _multiLineField(
//                         "Purpose / Scope of Authority", purposeController,
//                         hint: "Describe the powers being granted..."),
//                     _inputField("Date of Execution", dateController,
//                         hint: "dd-mm-yyyy"),
//                     _multiLineField(
//                         "Conditions & Limitations", conditionsController,
//                         hint: "Any restrictions on the authority..."),

//                     const SizedBox(height: 20),

//                     /// Reference file button with file name display
//                     SizedBox(
//                       width: double.infinity,
//                       child: OutlinedButton.icon(
//                         onPressed: _pickFile,
//                         icon: const Icon(Icons.attach_file),
//                         label: Text(
//                           _referenceFile != null
//                               ? 'File: ${_referenceFile!.name}' // Use .name instead of .path
//                               : 'Add Reference Document',
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         style: OutlinedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                           side: const BorderSide(
//                               color: Color(0xffE0A800), width: 1.5),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           foregroundColor: const Color(0xffE0A800),
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 15),

//                     /// Generate button with loading state
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton.icon(
//                         onPressed: _isGenerating ? null : _generateDocument,
//                         icon: _isGenerating
//                             ? Container(
//                                 width: 20,
//                                 height: 20,
//                                 child: const CircularProgressIndicator(
//                                   color: Colors.white,
//                                   strokeWidth: 2,
//                                 ),
//                               )
//                             : const Icon(Icons.auto_awesome),
//                         label: Text(_isGenerating
//                             ? 'Generating...'
//                             : 'Generate Document with AI'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xffE0A800),
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           const SizedBox(width: 30),

//           /// ================= RIGHT SIDE PREVIEW =================
//           Expanded(
//             flex: 2,
//             child: Container(
//               padding: const EdgeInsets.all(24),
//               height: 700,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(color: Colors.grey.shade200),
//               ),
//               child: _generatedText == null
//                   ? _buildPlaceholder()
//                   : _buildGeneratedPreview(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Placeholder when no document has been generated
//   Widget _buildPlaceholder() {
//     return const Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.auto_awesome, size: 50, color: Colors.grey),
//           SizedBox(height: 20),
//           Text(
//             "Ready to Generate",
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             "Fill in the details on the left, then click\n\"Generate Document with AI\" to create your Power of Attorney.",
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.grey),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Preview of the generated document with action buttons
//   Widget _buildGeneratedPreview() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           "Generated Document",
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 10),
//         Expanded(
//           child: Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: const Color(0xfff9fafb),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: SingleChildScrollView(
//               child: Text(
//                 _generatedText!,
//                 style: const TextStyle(fontSize: 14),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 16),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.end,
//           children: [
//             TextButton.icon(
//               onPressed: _editDocument,
//               icon: const Icon(Icons.edit),
//               label: const Text('Edit'),
//             ),
//             const SizedBox(width: 12),
//             ElevatedButton.icon(
//               onPressed: _downloadDocument,
//               icon: const Icon(Icons.download),
//               label: const Text('Download'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xffE0A800),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _inputField(String label, TextEditingController controller,
//       {String? hint}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 18),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(label),
//           const SizedBox(height: 6),
//           TextField(
//             controller: controller,
//             decoration: InputDecoration(
//               hintText: hint,
//               filled: true,
//               fillColor: const Color(0xfff9fafb),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _multiLineField(String label, TextEditingController controller,
//       {String? hint}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 18),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(label),
//           const SizedBox(height: 6),
//           TextField(
//             controller: controller,
//             maxLines: 3,
//             decoration: InputDecoration(
//               hintText: hint,
//               filled: true,
//               fillColor: const Color(0xfff9fafb),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
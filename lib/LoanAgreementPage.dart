import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Simple model for a dynamic document field (reused)
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

class LoanAgreementPage extends StatefulWidget {
  const LoanAgreementPage({super.key});

  @override
  State<LoanAgreementPage> createState() => _LoanAgreementPageState();
}

class _LoanAgreementPageState extends State<LoanAgreementPage> {
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

  // Default fields for a Loan Agreement (used when extraction fails or no file)
  void _resetToDefaultFields() {
    _fields = [
      DocumentField(
          name: 'lender',
          label: "Lender's Full Name",
          hint: 'Person or institution providing the loan'),
      DocumentField(
          name: 'borrower',
          label: "Borrower's Full Name",
          hint: 'Person receiving the loan'),
      DocumentField(
          name: 'loan_amount', label: "Loan Amount", hint: 'e.g. ₹5,00,000'),
      DocumentField(
          name: 'interest_rate',
          label: "Interest Rate (%)",
          hint: 'e.g. 10% per annum'),
      DocumentField(
          name: 'repayment_terms',
          label: "Repayment Terms",
          type: 'multiline',
          hint: 'EMI amount, due dates, tenure, etc.'),
      DocumentField(
          name: 'collateral',
          label: "Collateral / Security (if any)",
          type: 'multiline',
          required: false,
          hint: 'Assets pledged as security'),
      DocumentField(
          name: 'date',
          label: "Date of Agreement",
          type: 'date',
          hint: 'dd-mm-yyyy'),
      DocumentField(
          name: 'witnesses',
          label: "Witnesses (if any)",
          type: 'multiline',
          required: false,
          hint: 'Names and addresses of witnesses'),
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
          documentType: 'loan_agreement', // document type for loan agreement
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
        documentType: 'loan_agreement',
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
          // LEFT SIDE – Field input form (with Loan Agreement header)
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
                      "FINANCE",
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Loan Agreement",
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
                                  : 'Add Reference Document',
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
                            : 'Generate Document with AI'),
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
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
            "Fill in the details on the left, then click\n\"Generate Document with AI\" to create your Loan Agreement.",
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

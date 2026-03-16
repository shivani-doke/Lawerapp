import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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

  factory DocumentField.fromJson(Map<String, dynamic> json) {
    return DocumentField(
      name: json['name'],
      label: json['label'],
      type: json['type'] ?? 'text',
      hint: json['hint'],
      required: json['required'] ?? true,
    );
  }
}

class WillTestamentPage extends StatefulWidget {
  const WillTestamentPage({super.key});

  @override
  State<WillTestamentPage> createState() => _WillTestamentPageState();
}

class _WillTestamentPageState extends State<WillTestamentPage> {
  static const Color accentColor = Color(0xffE0A800);

  List<DocumentField> _fields = [];
  final Map<String, TextEditingController> _fieldControllers = {};

  PlatformFile? _referenceFile;
  List<Map<String, dynamic>> _savedReferences = [];
  String? _selectedReferenceId;
  bool _isLoadingReferences = false;
  bool _isUploading = false;

  bool _isGenerating = false;
  bool _isExtracting = false;

  String? _generatedDocx;
  String? _generatedPdf;
  bool _pdfLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _fields = [];
    _loadSavedReferences();
  }

  @override
  void dispose() {
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetFields() {
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    _fieldControllers.clear();
    _fields = [];
    setState(() {});
  }

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

  Future<void> _loadSavedReferences() async {
    setState(() => _isLoadingReferences = true);
    try {
      final refs =
          await ApiService().listReferences(documentType: 'will_testament');
      setState(() {
        _savedReferences = refs;
        _isLoadingReferences = false;
      });
    } catch (e) {
      setState(() => _isLoadingReferences = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load saved references: $e')),
      );
    }
  }

  Future<void> _selectSavedReference(String? id) async {
    if (id == null) {
      setState(() {
        _selectedReferenceId = null;
        _referenceFile = null;
        _resetFields();
      });
      return;
    }
    setState(() {
      _selectedReferenceId = id;
      _isExtracting = true;
      _referenceFile = null;
    });
    try {
      final fieldsJson = await ApiService().getReferenceFields(id);
      final fields =
          fieldsJson.map((json) => DocumentField.fromJson(json)).toList();
      setState(() {
        _fields = fields;
        _isExtracting = false;
      });
      _rebuildControllers();
    } catch (e) {
      setState(() => _isExtracting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load fields: $e')),
      );
    }
  }

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
        _generatedDocx = null;
        _generatedPdf = null;
        _pdfLoadFailed = false;
        _selectedReferenceId = null;
        _resetFields();
      });

      try {
        final extractedFields = await ApiService().extractFieldsFromReference(
          _referenceFile!,
          documentType: 'will_testament',
        );

        final fields = extractedFields
            .map((json) => DocumentField.fromJson(json))
            .toList();

        setState(() => _isUploading = true);
        final uploadResult = await ApiService().uploadReference(
          _referenceFile!,
          'will_testament',
        );
        final newId = uploadResult['document_id'];

        await _loadSavedReferences();
        await _selectSavedReference(newId);

        setState(() {
          _isExtracting = false;
          _isUploading = false;
        });
      } catch (e) {
        setState(() {
          _isExtracting = false;
          _isUploading = false;
          _fields = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  void _clearFile() {
    setState(() {
      _referenceFile = null;
      _selectedReferenceId = null;
      _resetFields();
      _generatedDocx = null;
      _generatedPdf = null;
      _pdfLoadFailed = false;
    });
  }

  Future<void> _generateDocument() async {
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

    if (_selectedReferenceId == null && _referenceFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select or upload a reference document')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _pdfLoadFailed = false;
    });

    try {
      final fields = {
        for (var field in _fields)
          field.name: _fieldControllers[field.name]?.text ?? '',
      };

      final response = await ApiService().generateDocument(
        documentType: 'will_testament',
        fields: fields,
        referenceFile: _selectedReferenceId == null ? _referenceFile : null,
        referenceId: _selectedReferenceId,
      );

      setState(() {
        _generatedDocx = response['docx_file'];
        _generatedPdf = response['pdf_file'];
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

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
                      "WILL & TESTAMENT",
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Will & Testament",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isLoadingReferences)
                      const Center(child: CircularProgressIndicator())
                    else if (_savedReferences.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: _selectedReferenceId,
                          hint: const Text('Select a saved document'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Upload new...'),
                            ),
                            ..._savedReferences.map((ref) {
                              return DropdownMenuItem(
                                value: ref['id'],
                                child: Text(
                                    '${ref['original_name']} (${ref['document_type']})'),
                              );
                            }),
                          ],
                          onChanged: _selectSavedReference,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xfff9fafb),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (_isExtracting || _isUploading)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_fields.isNotEmpty)
                      ..._fields.map((field) => _buildField(field))
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Select or upload a reference document to see fields',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: Text(
                              _referenceFile != null
                                  ? 'File: ${_referenceFile!.name}'
                                  : 'Upload New Reference Document',
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isGenerating ||
                                _isExtracting ||
                                _isUploading ||
                                (_selectedReferenceId == null &&
                                    _referenceFile == null))
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
              child: _generatedPdf == null
                  ? _buildPlaceholder()
                  : _buildPdfViewer(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    final pdfViewUrl =
        "${ApiService.baseUrl}/view/${_generatedPdf}?t=${DateTime.now().millisecondsSinceEpoch}";
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
                IconButton(
                  tooltip: "Download PDF",
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () async {
                    await ApiService()
                        .downloadGeneratedDocument(_generatedPdf!);
                  },
                ),
                IconButton(
                  tooltip: "Download DOCX",
                  icon: const Icon(Icons.description),
                  onPressed: () async {
                    await ApiService()
                        .downloadGeneratedDocument(_generatedDocx!);
                  },
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _pdfLoadFailed
                ? _buildFallbackButton(pdfViewUrl)
                : SfPdfViewer.network(
                    pdfViewUrl,
                    canShowScrollHead: true,
                    canShowScrollStatus: true,
                    onDocumentLoadFailed:
                        (PdfDocumentLoadFailedDetails details) {
                      setState(() {
                        _pdfLoadFailed = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Open to load PDF: ${details.error}')),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackButton(String url) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.picture_as_pdf,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            "Click to View PDF.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              html.window.open(url, '_blank');
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text("Open"),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            "Fill in the details on the left, then click\n\"Generate Document\" to create your Will & Testament.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

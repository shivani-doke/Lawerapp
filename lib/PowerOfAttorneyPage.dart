import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'web_preview_iframe_stub.dart'
    if (dart.library.html) 'web_preview_iframe_web.dart' as web_preview;

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

class PowerOfAttorneyPage extends StatefulWidget {
  const PowerOfAttorneyPage({super.key});

  @override
  State<PowerOfAttorneyPage> createState() => _PowerOfAttorneyPageState();
}

class _PowerOfAttorneyPageState extends State<PowerOfAttorneyPage> {
  static const Color accentColor = Color(0xffE0A800);

  // Dynamic fields (from extraction)
  List<DocumentField> _fields = [];
  final Map<String, TextEditingController> _fieldControllers = {};

  // Reference document (used for both extraction and generation)
  PlatformFile? _referenceFile;

  // Saved references management
  List<Map<String, dynamic>> _savedReferences = [];
  String? _selectedReferenceId;
  bool _isLoadingReferences = false;
  bool _isUploading = false;

  // UI state
  bool _isGenerating = false;
  bool _isExtracting = false;

  // Generated document info
  String? _generatedDocx;
  String? _generatedPdf;
  String? _generatedPdfViewType;
  String? _generatedPdfViewUrl;

  // Track PDF load failure for fallback button
  bool _pdfLoadFailed = false;

  // Format toggle state (true = table format, false = blank template)
  bool _useTableFormat = true;

  @override
  void initState() {
    super.initState();
    _fields = []; // No default fields
    _loadSavedReferences();
  }

  @override
  void dispose() {
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Clear all fields and controllers
  void _resetFields() {
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    _fieldControllers.clear();
    _fields = [];
    setState(() {});
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

  // Load saved references from server
  Future<void> _loadSavedReferences() async {
    setState(() => _isLoadingReferences = true);
    try {
      final refs =
          await ApiService().listReferences(documentType: 'power_of_attorney');
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

  // Select a saved reference and load its fields
  Future<void> _selectSavedReference(String id) async {
    setState(() {
      _selectedReferenceId = id;
      _isExtracting = true;
      _referenceFile = null; // Clear any local file
      _pdfLoadFailed = false; // Reset PDF failure if any
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

  // Preview the selected reference document in a small in-app popup
  void _previewReference() {
    if (_selectedReferenceId == null) return;
    final previewUrl =
        '${ApiService.baseUrl}/references/$_selectedReferenceId/view';
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 820,
          height: 600,
          child: _ReferencePreviewDialog(
            previewUrl: previewUrl,
            accentColor: accentColor,
          ),
        ),
      ),
    );
  }

  // Pick a new reference file, upload it, and save it on the server
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
        _generatedPdfViewType = null;
        _generatedPdfViewUrl = null;
        _pdfLoadFailed = false;
        _selectedReferenceId = null; // Deselect any saved reference
        _resetFields();
      });

      try {
        // 1. Extract fields using Gemini
        final extractedFields = await ApiService().extractFieldsFromReference(
          _referenceFile!,
          documentType: 'power_of_attorney',
        );

        final fields = extractedFields
            .map((json) => DocumentField.fromJson(json))
            .toList();

        // 2. Upload the file to server and get new ID
        setState(() => _isUploading = true);
        final uploadResult = await ApiService().uploadReference(
          _referenceFile!,
          'power_of_attorney',
        );
        final newId = uploadResult['document_id'];

        // 3. Immediately show the fields we just extracted
        setState(() {
          _fields = fields;
          _selectedReferenceId = newId;
          _referenceFile = null;
          _isExtracting = false;
          _isUploading = false;
        });

        // 4. Create controllers for the new fields
        _rebuildControllers();

        // 5. Refresh saved references list in background
        _loadSavedReferences();
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

  // Clear the uploaded file and any selection
  void _clearFile() {
    setState(() {
      _referenceFile = null;
      _selectedReferenceId = null;
      _resetFields();
      _generatedDocx = null;
      _generatedPdf = null;
      _generatedPdfViewType = null;
      _generatedPdfViewUrl = null;
      _pdfLoadFailed = false;
    });
  }

  // Generate document using either saved reference or newly uploaded file
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

    if (_selectedReferenceId == null && _referenceFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select or upload a reference document')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _pdfLoadFailed = false; // Reset PDF failure on new generation
    });

    try {
      final fields = {
        for (var field in _fields)
          field.name: _fieldControllers[field.name]?.text ?? '',
      };

      final response = await ApiService().generateDocument(
        documentType: 'power_of_attorney',
        fields: fields,
        referenceFile: _selectedReferenceId == null ? _referenceFile : null,
        referenceId: _selectedReferenceId,
        format: _useTableFormat ? 'table' : 'blank',
      );

      final generatedPdf = response['pdf_file'] as String?;
      final generatedPdfViewUrl = generatedPdf == null
          ? null
          : "${ApiService.baseUrl}/view/$generatedPdf?t=${DateTime.now().millisecondsSinceEpoch}";
      final generatedPdfViewType = generatedPdf == null
          ? null
          : 'generated-preview-${DateTime.now().microsecondsSinceEpoch}';

      if (kIsWeb &&
          generatedPdfViewUrl != null &&
          generatedPdfViewType != null) {
        web_preview.registerPreviewIframe(
          generatedPdfViewType,
          generatedPdfViewUrl,
        );
      }

      setState(() {
        _generatedDocx = response['docx_file'];
        _generatedPdf = generatedPdf;
        _generatedPdfViewType = generatedPdfViewType;
        _generatedPdfViewUrl = generatedPdfViewUrl;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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

                    // Saved references dropdown
                    if (_isLoadingReferences)
                      const Center(child: CircularProgressIndicator())
                    else if (_savedReferences.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedReferenceId,
                            hint: const Text('Select an existing document'),
                            items: _savedReferences
                                .map<DropdownMenuItem<String>>((ref) {
                              return DropdownMenuItem<String>(
                                value: ref['id'] as String,
                                child: Text(
                                    '${ref['original_name']} (${ref['document_type']})'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _selectSavedReference(value);
                              }
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xfff9fafb),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          // Preview button (styled exactly like Generate button)
                          if (_selectedReferenceId != null) ...[
                            const SizedBox(
                                height: 16), // Spacing above preview button
                            ElevatedButton.icon(
                              onPressed: _previewReference,
                              icon: const Icon(Icons.visibility),
                              label: const Text('Preview Document'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                minimumSize: const Size(double.infinity, 48),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                    // Extra spacing between preview button and fields (when reference selected)
                    if (_selectedReferenceId != null)
                      const SizedBox(height: 16),

                    // UPLOAD BUTTON – shown only when no saved document is selected
                    if (_selectedReferenceId == null) ...[
                      // Add spacing only if saved references exist above
                      if (_savedReferences.isNotEmpty)
                        const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(
                                      color: accentColor, width: 1.5),
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
                      ),
                    ],

                    // Show loading indicator while extracting fields
                    if (_isExtracting || _isUploading)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_fields.isNotEmpty) ...[
                      // Build dynamic fields
                      ..._fields.map((field) => _buildField(field)),
                      // Format selection toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            const Text('Document Format:'),
                            const SizedBox(width: 16),
                            ChoiceChip(
                              label: const Text('Table Format'),
                              selected: _useTableFormat,
                              onSelected: (selected) =>
                                  setState(() => _useTableFormat = selected),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Blank Template'),
                              selected: !_useTableFormat,
                              onSelected: (selected) =>
                                  setState(() => _useTableFormat = !selected),
                            ),
                          ],
                        ),
                      ),
                    ] else
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

                    // Generate button
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
              child: _generatedPdf == null
                  ? _buildPlaceholder()
                  : _buildPdfViewer(),
            ),
          ),
        ],
      ),
    );
  }

  // PDF Viewer
  Widget _buildPdfViewer() {
    final pdfViewUrl = _generatedPdfViewUrl ??
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
                  tooltip: "Maximize Preview",
                  icon: const Icon(Icons.open_in_full),
                  onPressed: () {
                    _openGeneratedPreviewDialog(pdfViewUrl);
                  },
                ),
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
            child: _buildGeneratedPreviewContent(pdfViewUrl),
          ),
        ),
      ],
    );
  }

  void _openGeneratedPreviewDialog(String pdfViewUrl) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: MediaQuery.of(dialogContext).size.width * 0.9,
          height: MediaQuery.of(dialogContext).size.height * 0.9,
          child: _GeneratedPreviewDialog(
            previewUrl: pdfViewUrl,
            accentColor: accentColor,
            generatedPdf: _generatedPdf,
            generatedDocx: _generatedDocx,
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratedPreviewContent(String pdfViewUrl) {
    if (_pdfLoadFailed) {
      return _buildFallbackButton(pdfViewUrl);
    }

    if (kIsWeb && _generatedPdfViewType != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: web_preview.buildPreviewIframe(_generatedPdfViewType!),
      );
    }

    return SfPdfViewer.network(
      pdfViewUrl,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        setState(() {
          _pdfLoadFailed = true;
        });
      },
    );
  }

  // Fallback button when PDF fails to load
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
            "Click to open in browser.",
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

  // Placeholder before any document is generated
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
}

class _ReferencePreviewDialog extends StatefulWidget {
  final String previewUrl;
  final Color accentColor;

  const _ReferencePreviewDialog({
    required this.previewUrl,
    required this.accentColor,
  });

  @override
  State<_ReferencePreviewDialog> createState() => _ReferencePreviewDialogState();
}

class _ReferencePreviewDialogState extends State<_ReferencePreviewDialog> {
  bool _loadFailed = false;
  late final String _previewUrlWithTimestamp;
  late final String _iframeViewType;

  @override
  void initState() {
    super.initState();
    _previewUrlWithTimestamp =
        '${widget.previewUrl}?t=${DateTime.now().millisecondsSinceEpoch}';
    _iframeViewType =
        'reference-preview-${DateTime.now().microsecondsSinceEpoch}';

    if (kIsWeb) {
      web_preview.registerPreviewIframe(_iframeViewType, _previewUrlWithTimestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Reference Preview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _loadFailed
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 72,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Preview unavailable inside the app.",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                html.window.open(
                                    _previewUrlWithTimestamp, '_blank');
                              },
                              icon: const Icon(Icons.open_in_browser),
                              label: const Text("Open in Browser"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.accentColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : kIsWeb
                        ? web_preview.buildPreviewIframe(_iframeViewType)
                        : SfPdfViewer.network(
                            _previewUrlWithTimestamp,
                            canShowScrollHead: true,
                            canShowScrollStatus: true,
                            onDocumentLoadFailed:
                                (PdfDocumentLoadFailedDetails details) {
                              setState(() {
                                _loadFailed = true;
                              });
                            },
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedPreviewDialog extends StatefulWidget {
  final String previewUrl;
  final Color accentColor;
  final String? generatedPdf;
  final String? generatedDocx;

  const _GeneratedPreviewDialog({
    required this.previewUrl,
    required this.accentColor,
    required this.generatedPdf,
    required this.generatedDocx,
  });

  @override
  State<_GeneratedPreviewDialog> createState() => _GeneratedPreviewDialogState();
}

class _GeneratedPreviewDialogState extends State<_GeneratedPreviewDialog> {
  bool _loadFailed = false;
  late final String _previewUrlWithTimestamp;
  late final String _iframeViewType;

  @override
  void initState() {
    super.initState();
    _previewUrlWithTimestamp =
        '${widget.previewUrl}${widget.previewUrl.contains('?') ? '&' : '?'}dialog=${DateTime.now().millisecondsSinceEpoch}';
    _iframeViewType =
        'generated-preview-${DateTime.now().microsecondsSinceEpoch}';

    if (kIsWeb) {
      web_preview.registerPreviewIframe(_iframeViewType, _previewUrlWithTimestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Generated Document',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.generatedPdf != null)
                IconButton(
                  tooltip: 'Download PDF',
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () async {
                    await ApiService()
                        .downloadGeneratedDocument(widget.generatedPdf!);
                  },
                ),
              if (widget.generatedDocx != null)
                IconButton(
                  tooltip: 'Download DOCX',
                  icon: const Icon(Icons.description),
                  onPressed: () async {
                    await ApiService()
                        .downloadGeneratedDocument(widget.generatedDocx!);
                  },
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _loadFailed
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              size: 72,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Preview unavailable inside the app.",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                html.window.open(
                                    _previewUrlWithTimestamp, '_blank');
                              },
                              icon: const Icon(Icons.open_in_browser),
                              label: const Text("Open in Browser"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.accentColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : kIsWeb
                        ? web_preview.buildPreviewIframe(_iframeViewType)
                        : SfPdfViewer.network(
                            _previewUrlWithTimestamp,
                            canShowScrollHead: true,
                            canShowScrollStatus: true,
                            onDocumentLoadFailed:
                                (PdfDocumentLoadFailedDetails details) {
                              setState(() {
                                _loadFailed = true;
                              });
                            },
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

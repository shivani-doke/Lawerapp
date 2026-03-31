import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import '../services/api_service.dart';
import 'upload_context.dart';
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
  final List<String> options;
  final bool repeatable;
  final List<DocumentField> fields;

  DocumentField({
    required this.name,
    required this.label,
    this.type = 'text',
    this.hint,
    this.required = true,
    this.options = const [],
    this.repeatable = false,
    this.fields = const [],
  });

  factory DocumentField.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final rawFields = json['fields'];
    final parsedName = (json['name'] ?? '').toString().trim();
    final parsedLabel = (json['label'] ?? parsedName).toString().trim();
    final parsedType = (json['type'] ?? 'text').toString().trim();

    return DocumentField(
      name: parsedName,
      label: parsedLabel.isEmpty ? parsedName : parsedLabel,
      type: parsedType.isEmpty ? 'text' : parsedType,
      hint: json['hint']?.toString(),
      required: json['required'] == true,
      options: rawOptions is List
          ? rawOptions.map((e) => e.toString()).toList()
          : const [],
      repeatable: json['repeatable'] == true,
      fields: rawFields is List
          ? rawFields
              .whereType<Map>()
              .map((e) => DocumentField.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class VendorAgreementPage extends StatefulWidget {
  const VendorAgreementPage({super.key});

  @override
  State<VendorAgreementPage> createState() => _VendorAgreementPageState();
}

class _VendorAgreementPageState extends State<VendorAgreementPage> {
  static const Color accentColor = Color(0xffE0A800);

  // Dynamic fields (from extraction)
  List<DocumentField> _fields = [];
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, String> _dropdownValues = {};
  final Map<String, bool> _boolValues = {};
  final Map<String, Set<String>> _multiselectValues = {};
  final Map<String, List<Map<String, TextEditingController>>>
      _groupFieldControllers = {};
  final Map<String, List<Map<String, String>>> _groupDropdownValues = {};
  final Map<String, List<Map<String, bool>>> _groupBoolValues = {};
  final Map<String, List<Map<String, Set<String>>>> _groupMultiselectValues =
      {};

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
  late final bool _openedFromUploads;

  @override
  void initState() {
    super.initState();
    _openedFromUploads =
        UploadNavigationContext.consumeReferenceOnlyMode('vendor_agreement');
    _fields = []; // No default fields
    _loadSavedReferences(autoSelectFirst: !_openedFromUploads);
    if (!_openedFromUploads) {
      _loadDefaultFields();
    }
  }

  @override
  void dispose() {
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    _disposeGroupControllers();
    super.dispose();
  }

  void _disposeGroupControllers() {
    for (final groupRows in _groupFieldControllers.values) {
      for (final row in groupRows) {
        for (final controller in row.values) {
          controller.dispose();
        }
      }
    }
    _groupFieldControllers.clear();
    _groupDropdownValues.clear();
    _groupBoolValues.clear();
    _groupMultiselectValues.clear();
  }

  Map<String, TextEditingController> _createGroupControllerRow(
      DocumentField groupField) {
    final controllers = <String, TextEditingController>{};
    for (final nestedField in groupField.fields) {
      if (nestedField.type == 'dropdown' ||
          nestedField.type == 'boolean' ||
          nestedField.type == 'multiselect' ||
          (nestedField.type == 'group' && nestedField.fields.isNotEmpty)) {
        continue;
      }
      controllers[nestedField.name] = TextEditingController();
    }
    return controllers;
  }

  Map<String, String> _createGroupDropdownRow(DocumentField groupField) {
    final values = <String, String>{};
    for (final nestedField in groupField.fields) {
      if (nestedField.type == 'dropdown') {
        values[nestedField.name] =
            nestedField.options.isNotEmpty ? nestedField.options.first : '';
      }
    }
    return values;
  }

  Map<String, bool> _createGroupBoolRow(DocumentField groupField) {
    final values = <String, bool>{};
    for (final nestedField in groupField.fields) {
      if (nestedField.type == 'boolean') {
        values[nestedField.name] = false;
      }
    }
    return values;
  }

  Map<String, Set<String>> _createGroupMultiselectRow(DocumentField groupField) {
    final values = <String, Set<String>>{};
    for (final nestedField in groupField.fields) {
      if (nestedField.type == 'multiselect') {
        values[nestedField.name] = <String>{};
      }
    }
    return values;
  }

  void _initializeGroupField(DocumentField field) {
    if (field.type != 'group' || field.fields.isEmpty) {
      return;
    }

    _groupFieldControllers[field.name] = [_createGroupControllerRow(field)];
    _groupDropdownValues[field.name] = [_createGroupDropdownRow(field)];
    _groupBoolValues[field.name] = [_createGroupBoolRow(field)];
    _groupMultiselectValues[field.name] = [_createGroupMultiselectRow(field)];
  }

  void _addGroupRow(DocumentField field) {
    if (field.type != 'group' || field.fields.isEmpty) {
      return;
    }

    setState(() {
      _groupFieldControllers.putIfAbsent(field.name, () => []);
      _groupDropdownValues.putIfAbsent(field.name, () => []);
      _groupBoolValues.putIfAbsent(field.name, () => []);
      _groupMultiselectValues.putIfAbsent(field.name, () => []);

      _groupFieldControllers[field.name]!.add(_createGroupControllerRow(field));
      _groupDropdownValues[field.name]!.add(_createGroupDropdownRow(field));
      _groupBoolValues[field.name]!.add(_createGroupBoolRow(field));
      _groupMultiselectValues[field.name]!
          .add(_createGroupMultiselectRow(field));
    });
  }

  void _removeGroupRow(DocumentField field, int index) {
    final controllerRows = _groupFieldControllers[field.name];
    final dropdownRows = _groupDropdownValues[field.name];
    final boolRows = _groupBoolValues[field.name];
    final multiselectRows = _groupMultiselectValues[field.name];

    if (controllerRows == null ||
        dropdownRows == null ||
        boolRows == null ||
        multiselectRows == null ||
        index < 0 ||
        index >= controllerRows.length ||
        controllerRows.length <= 1) {
      return;
    }

    setState(() {
      for (final controller in controllerRows[index].values) {
        controller.dispose();
      }
      controllerRows.removeAt(index);
      dropdownRows.removeAt(index);
      boolRows.removeAt(index);
      multiselectRows.removeAt(index);
    });
  }

  bool _isTopLevelFieldMissing(DocumentField field) {
    if (!field.required) {
      return false;
    }

    if (field.type == 'dropdown') {
      final value = _dropdownValues[field.name] ?? '';
      return value.trim().isEmpty;
    }
    if (field.type == 'boolean') {
      return false;
    }
    if (field.type == 'multiselect') {
      final values = _multiselectValues[field.name] ?? <String>{};
      return values.isEmpty;
    }

    final value = _fieldControllers[field.name]?.text ?? '';
    return value.trim().isEmpty;
  }

  bool _isGroupSubFieldMissing(
    DocumentField groupField,
    DocumentField subField,
    int rowIndex,
  ) {
    if (!subField.required) {
      return false;
    }

    if (subField.type == 'dropdown') {
      final value =
          _groupDropdownValues[groupField.name]?[rowIndex][subField.name] ?? '';
      return value.trim().isEmpty;
    }
    if (subField.type == 'boolean') {
      return false;
    }
    if (subField.type == 'multiselect') {
      final values = _groupMultiselectValues[groupField.name]?[rowIndex]
              [subField.name] ??
          <String>{};
      return values.isEmpty;
    }

    final value = _groupFieldControllers[groupField.name]?[rowIndex]
            [subField.name]
            ?.text ??
        '';
    return value.trim().isEmpty;
  }

  bool _isGroupRowEmpty(DocumentField groupField, int rowIndex) {
    for (final subField in groupField.fields) {
      if (subField.type == 'dropdown') {
        final value =
            _groupDropdownValues[groupField.name]?[rowIndex][subField.name] ??
                '';
        if (value.trim().isNotEmpty) {
          return false;
        }
        continue;
      }
      if (subField.type == 'boolean') {
        final value =
            _groupBoolValues[groupField.name]?[rowIndex][subField.name] ??
                false;
        if (value) {
          return false;
        }
        continue;
      }
      if (subField.type == 'multiselect') {
        final values = _groupMultiselectValues[groupField.name]?[rowIndex]
                [subField.name] ??
            <String>{};
        if (values.isNotEmpty) {
          return false;
        }
        continue;
      }

      final value = _groupFieldControllers[groupField.name]?[rowIndex]
              [subField.name]
              ?.text ??
          '';
      if (value.trim().isNotEmpty) {
        return false;
      }
    }

    return true;
  }

  List<String> _collectMissingRequiredFields() {
    final missingFields = <String>[];

    for (final field in _fields) {
      if (field.type == 'group' && field.fields.isNotEmpty) {
        final rows = _groupFieldControllers[field.name] ?? const [];
        if (field.required && rows.isEmpty) {
          missingFields.add(field.label);
          continue;
        }

        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
          final rowIsEmpty = _isGroupRowEmpty(field, rowIndex);
          if (!field.required && rowIsEmpty) {
            continue;
          }

          final hasMissingRequiredSubField =
              field.fields.any((subField) => _isGroupSubFieldMissing(
                    field,
                    subField,
                    rowIndex,
                  ));
          if (hasMissingRequiredSubField) {
            missingFields.add(field.label);
            break;
          }
        }
        continue;
      }

      if (_isTopLevelFieldMissing(field)) {
        missingFields.add(field.label);
      }
    }

    return missingFields;
  }

  dynamic _serializeTopLevelFieldValue(DocumentField field) {
    if (field.type == 'dropdown') {
      return _dropdownValues[field.name] ?? '';
    }
    if (field.type == 'boolean') {
      return _boolValues[field.name] ?? false;
    }
    if (field.type == 'multiselect') {
      return (_multiselectValues[field.name] ?? <String>{}).toList();
    }
    if (field.type == 'group' && field.fields.isNotEmpty) {
      final rows = _groupFieldControllers[field.name] ?? const [];
      final serializedRows = <Map<String, dynamic>>[];

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        if (_isGroupRowEmpty(field, rowIndex)) {
          continue;
        }

        final rowData = <String, dynamic>{};
        for (final subField in field.fields) {
          if (subField.type == 'dropdown') {
            rowData[subField.name] =
                _groupDropdownValues[field.name]?[rowIndex][subField.name] ??
                    '';
          } else if (subField.type == 'boolean') {
            rowData[subField.name] =
                _groupBoolValues[field.name]?[rowIndex][subField.name] ??
                    false;
          } else if (subField.type == 'multiselect') {
            rowData[subField.name] = (_groupMultiselectValues[field.name]?[rowIndex]
                        [subField.name] ??
                    <String>{})
                .toList();
          } else {
            rowData[subField.name] = _groupFieldControllers[field.name]?[rowIndex]
                    [subField.name]
                    ?.text ??
                '';
          }
        }
        serializedRows.add(rowData);
      }

      if (field.repeatable) {
        return serializedRows;
      }
      return serializedRows.isNotEmpty
          ? serializedRows.first
          : <String, dynamic>{};
    }

    return _fieldControllers[field.name]?.text ?? '';
  }

  // Clear all fields and controllers
  void _resetFields() {
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    _fieldControllers.clear();
    _dropdownValues.clear();
    _boolValues.clear();
    _multiselectValues.clear();
    _disposeGroupControllers();
    _fields = [];
    setState(() {});
  }

  // Rebuild field state when fields change
  void _rebuildControllers() {
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    _fieldControllers.clear();
    _dropdownValues.clear();
    _boolValues.clear();
    _multiselectValues.clear();
    _disposeGroupControllers();

    for (var field in _fields) {
      if (field.type == 'group' && field.fields.isNotEmpty) {
        _initializeGroupField(field);
      } else if (field.type == 'dropdown') {
        _dropdownValues[field.name] =
            field.options.isNotEmpty ? field.options.first : '';
      } else if (field.type == 'boolean') {
        _boolValues[field.name] = false;
      } else if (field.type == 'multiselect') {
        _multiselectValues[field.name] = <String>{};
      } else {
        _fieldControllers[field.name] = TextEditingController();
      }
    }
    setState(() {});
  }

  // Load saved references from server
  Future<void> _loadSavedReferences({bool autoSelectFirst = true}) async {
    setState(() => _isLoadingReferences = true);
    try {
      final refs =
          await ApiService().listReferences(documentType: 'vendor_agreement');
      setState(() {
        _savedReferences = refs;
        _isLoadingReferences = false;
      });

      if (autoSelectFirst &&
          _savedReferences.isNotEmpty &&
          _selectedReferenceId == null) {
        final autoSelectedId = _savedReferences.first['id']?.toString();
        if (autoSelectedId != null && autoSelectedId.isNotEmpty) {
          await _selectSavedReference(autoSelectedId);
        }
      }
    } catch (e) {
      setState(() => _isLoadingReferences = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load saved references: $e')),
      );
    }
  }

  Future<void> _loadDefaultFields() async {
    try {
      final fieldsJson = await ApiService().getFieldsByDocumentType(
        documentType: 'vendor_agreement',
      );
      final fields = _parseDocumentFields(fieldsJson);

      if (!mounted) return;
      setState(() {
        _fields = fields;
      });
      _rebuildControllers();
    } catch (_) {
      // Silent fallback: user can still upload/select reference.
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
      final fields = _parseDocumentFields(fieldsJson);
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
          documentType: 'vendor_agreement',
        );

        final fields = _parseDocumentFields(extractedFields);

        // 2. Upload the file to server and get new ID
        setState(() => _isUploading = true);
        final uploadResult = await ApiService().uploadReference(
          _referenceFile!,
          'vendor_agreement',
        );
        final newId = uploadResult['document_id']?.toString();
        if (newId == null || newId.isEmpty) {
          throw Exception('Upload succeeded but no document ID was returned');
        }
        final uploadedReference = <String, dynamic>{
          'id': newId,
          'original_name': _referenceFile!.name,
          'document_type': 'vendor_agreement',
          'timestamp': DateTime.now().toIso8601String(),
        };

        // 3. Immediately show the fields we just extracted and add the
        // uploaded file to the dropdown so the selected value is valid.
        setState(() {
          _fields = fields;
          _selectedReferenceId = newId;
          _savedReferences = [
            uploadedReference,
            ..._savedReferences.where((ref) => ref['id'] != newId),
          ];
          _referenceFile = null;
          _isExtracting = false;
          _isUploading = false;
        });

        // 4. Create controllers for the new fields
        _rebuildControllers();

        // 5. Refresh saved references list in background
        _loadSavedReferences(autoSelectFirst: false);
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
    final missingFields = _collectMissingRequiredFields();

    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please fill all required fields: ${missingFields.join(', ')}'),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _pdfLoadFailed = false; // Reset PDF failure on new generation
    });

    try {
      final fields = <String, dynamic>{
        for (var field in _fields) field.name: _serializeTopLevelFieldValue(field),
      };

      final response = await ApiService().generateDocument(
        documentType: 'vendor_agreement',
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

  List<DocumentField> _parseDocumentFields(dynamic raw) {
    if (raw is! List) return [];
    final parsed = <DocumentField>[];

    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      // Flat field format: {name, label, type, ...}
      if (map.containsKey('name') && map.containsKey('label')) {
        final field = DocumentField.fromJson(map);
        if (field.name.isNotEmpty && field.label.isNotEmpty) {
          parsed.add(field);
        }
        continue;
      }

      // Sectioned format: {section: "...", fields: [{...}, ...]}
      final nested = map['fields'];
      if (nested is List) {
        parsed.addAll(_parseDocumentFields(nested));
      }
    }

    return parsed;
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
                      "DOCUMENT",
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Vendor Agreement",
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
                            'Fields will appear here after loading defaults or selecting a reference document',
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
                        onPressed: (_isGenerating || _isExtracting || _isUploading)
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
                            : (_selectedReferenceId == null && _referenceFile == null)
                                ? 'Generate AI Draft'
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

  Widget _buildGroupField(DocumentField field) {
    final controllerRows = _groupFieldControllers[field.name] ?? const [];
    final rowCount = controllerRows.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xfff9fafb),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    field.label + (field.required ? ' *' : ''),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (field.repeatable)
                  Text(
                    '$rowCount item${rowCount == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
            if (field.hint != null && field.hint!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(field.hint!, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            ...List.generate(rowCount, (rowIndex) {
              return Container(
                margin: EdgeInsets.only(bottom: rowIndex == rowCount - 1 ? 0 : 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (field.repeatable)
                      Row(
                        children: [
                          Text(
                            '${field.label} ${rowIndex + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          if (rowCount > 1)
                            IconButton(
                              tooltip: 'Remove item',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeGroupRow(field, rowIndex),
                            ),
                        ],
                      ),
                    ...field.fields.map(
                      (nestedField) => _buildGroupSubField(
                        groupField: field,
                        subField: nestedField,
                        rowIndex: rowIndex,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (field.repeatable) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _addGroupRow(field),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSubField({
    required DocumentField groupField,
    required DocumentField subField,
    required int rowIndex,
  }) {
    final type = subField.type;
    final isRequired = subField.required;

    if (type == 'dropdown') {
      final options = subField.options;
      final current =
          _groupDropdownValues[groupField.name]?[rowIndex][subField.name];
      final selected = (current != null && options.contains(current))
          ? current
          : (options.isNotEmpty ? options.first : null);
      if (selected != null) {
        _groupDropdownValues[groupField.name]?[rowIndex][subField.name] =
            selected;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subField.label + (isRequired ? ' *' : '')),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selected,
              items: options
                  .map((option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _groupDropdownValues[groupField.name]?[rowIndex]
                      [subField.name] = value ?? '';
                });
              },
              decoration: InputDecoration(
                hintText: subField.hint,
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

    if (type == 'boolean') {
      final current =
          _groupBoolValues[groupField.name]?[rowIndex][subField.name] ?? false;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xfff9fafb),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SwitchListTile(
            title: Text(subField.label + (isRequired ? ' *' : '')),
            subtitle: subField.hint != null ? Text(subField.hint!) : null,
            value: current,
            onChanged: (value) {
              setState(() {
                _groupBoolValues[groupField.name]?[rowIndex][subField.name] =
                    value;
              });
            },
          ),
        ),
      );
    }

    if (type == 'multiselect') {
      final selected = _groupMultiselectValues[groupField.name]?[rowIndex]
          .putIfAbsent(subField.name, () => <String>{});
      final options = subField.options;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subField.label + (isRequired ? ' *' : '')),
            if (subField.hint != null) ...[
              const SizedBox(height: 4),
              Text(subField.hint!, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final active = selected?.contains(option) ?? false;
                return FilterChip(
                  label: Text(option),
                  selected: active,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        selected?.add(option);
                      } else {
                        selected?.remove(option);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    final controller = _groupFieldControllers[groupField.name]?[rowIndex]
        .putIfAbsent(subField.name, () => TextEditingController());

    if (type == 'date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subField.label + (isRequired ? ' *' : '')),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              readOnly: true,
              onTap: controller == null ? null : () => _selectDate(controller),
              decoration: InputDecoration(
                hintText: subField.hint ?? 'dd-mm-yyyy',
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
    }

    if (type == 'textarea' || type == 'multiline') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subField.label + (isRequired ? ' *' : '')),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: subField.hint,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subField.label + (isRequired ? ' *' : '')),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType:
                type == 'number' ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: subField.hint,
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

  // Build an input field based on its type
  Widget _buildField(DocumentField field) {
    final type = field.type;
    final isRequired = field.required;

    if (type == 'group' && field.fields.isNotEmpty) {
      return _buildGroupField(field);
    }

    if (type == 'dropdown') {
      final options = field.options;
      final current = _dropdownValues[field.name];
      final selected = (current != null && options.contains(current))
          ? current
          : (options.isNotEmpty ? options.first : null);
      if (selected != null) {
        _dropdownValues[field.name] = selected;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label + (isRequired ? ' *' : '')),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selected,
              items: options
                  .map((o) => DropdownMenuItem<String>(
                        value: o,
                        child: Text(o),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _dropdownValues[field.name] = value ?? '';
                });
              },
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

    if (type == 'boolean') {
      final current = _boolValues[field.name] ?? false;
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xfff9fafb),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SwitchListTile(
            title: Text(field.label + (isRequired ? ' *' : '')),
            subtitle: field.hint != null ? Text(field.hint!) : null,
            value: current,
            onChanged: (value) {
              setState(() {
                _boolValues[field.name] = value;
              });
            },
          ),
        ),
      );
    }

    if (type == 'multiselect') {
      final options = field.options;
      final selected =
          _multiselectValues.putIfAbsent(field.name, () => <String>{});

      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label + (isRequired ? ' *' : '')),
            if (field.hint != null) ...[
              const SizedBox(height: 4),
              Text(field.hint!, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final active = selected.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: active,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        selected.add(option);
                      } else {
                        selected.remove(option);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    final controller = _fieldControllers[field.name] ??= TextEditingController();

    if (type == 'date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label + (isRequired ? ' *' : '')),
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
    }

    if (type == 'textarea' || type == 'multiline' || type == 'group') {
      String? hint = field.hint;
      if (type == 'group' && (hint == null || hint.isEmpty)) {
        hint = 'Enter JSON array, e.g. [{"item":"value"}]';
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label + (isRequired ? ' *' : '')),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              maxLines: type == 'group' ? 5 : 3,
              decoration: InputDecoration(
                hintText: hint,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label + (isRequired ? ' *' : '')),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType:
                type == 'number' ? TextInputType.number : TextInputType.text,
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







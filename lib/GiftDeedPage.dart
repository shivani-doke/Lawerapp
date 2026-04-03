import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import '../services/api_service.dart';
import 'widgets/voice_dictation_button.dart';
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

class GiftDeedPage extends StatefulWidget {
  const GiftDeedPage({super.key});

  @override
  State<GiftDeedPage> createState() => _GiftDeedPageState();
}

class _GiftDeedPageState extends State<GiftDeedPage> {
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
  static const List<String> _supportedLanguages = [
    'English',
    'Hindi',
    'Marathi',
  ];
  String _selectedLanguage = _supportedLanguages.first;
  static const List<String> _supportedFontFamilies = ['Times New Roman', 'Arial', 'Calibri', 'Cambria', 'Georgia', 'Garamond', 'Verdana', 'Tahoma', 'Trebuchet MS', 'Nirmala UI', 'Mangal'];
  static const List<int> _supportedFontSizes = [10, 12, 14, 16, 18, 20, 22];
  String _selectedFontFamily = _supportedFontFamilies.first;
  int _selectedFontSize = 14;
  static const List<String> _supportedPaperSizes = ['A4', 'Letter', 'Legal'];
  static const List<String> _supportedLineSpacings = ['Single', '1.15', '1.5', 'Double'];
  static const List<String> _supportedMarginSizes = ['Normal', 'Narrow', 'Moderate', 'Wide'];
  String _selectedPaperSize = _supportedPaperSizes.first;
  String _selectedLineSpacing = _supportedLineSpacings.first;
  String _selectedMarginSize = _supportedMarginSizes.first;
  late final bool _openedFromUploads;

  @override
  void initState() {
    super.initState();
    ApiService.setFieldLanguage(_selectedLanguage);
    _openedFromUploads =
        UploadNavigationContext.consumeReferenceOnlyMode('gift_deed');
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
          await ApiService().listReferences(documentType: 'gift_deed');
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
        documentType: 'gift_deed',
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
          documentType: 'gift_deed',
        );

        final fields = _parseDocumentFields(extractedFields);

        // 2. Upload the file to server and get new ID
        setState(() => _isUploading = true);
        final uploadResult = await ApiService().uploadReference(
          _referenceFile!,
          'gift_deed',
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

      fields.addAll({
        'paper_size': _selectedPaperSize,
        'line_spacing': _selectedLineSpacing,
        'margin_size': _selectedMarginSize,
      });

      final response = await ApiService().generateDocument(
        documentType: 'gift_deed',
        fields: fields,
        referenceFile: _selectedReferenceId == null ? _referenceFile : null,
        referenceId: _selectedReferenceId,
        format: _useTableFormat ? 'table' : 'blank',
        language: _selectedLanguage,
        fontFamily: _selectedFontFamily,
        fontSize: _selectedFontSize,
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


  Widget _buildDocumentLanguageSettings() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Document Language:'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            items: _supportedLanguages
                .map((language) => DropdownMenuItem<String>(
                      value: language,
                      child: Text(language),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedLanguage = value);
              ApiService.setFieldLanguage(value);
              if (_selectedReferenceId != null) {
                _selectSavedReference(_selectedReferenceId!);
              } else {
                _loadDefaultFields();
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
        ],
      ),
    );
  }

  Widget _buildDocumentLayoutSettings() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paper Size:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedPaperSize,
                  items: _supportedPaperSizes
                      .map((paperSize) => DropdownMenuItem<String>(
                            value: paperSize,
                            child: Text(paperSize),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedPaperSize = value);
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xfff9fafb),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Line Spacing:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedLineSpacing,
                  items: _supportedLineSpacings
                      .map((lineSpacing) => DropdownMenuItem<String>(
                            value: lineSpacing,
                            child: Text(lineSpacing),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedLineSpacing = value);
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xfff9fafb),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Margin:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedMarginSize,
                  items: _supportedMarginSizes
                      .map((marginSize) => DropdownMenuItem<String>(
                            value: marginSize,
                            child: Text(marginSize),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedMarginSize = value);
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xfff9fafb),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                      'DOCUMENT',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gift Deed',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isLoadingReferences)
                      const Center(child: CircularProgressIndicator())
                    else if (_savedReferences.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedReferenceId,
                            hint: const Text('Select an existing document'),
                            items: _savedReferences.map<DropdownMenuItem<String>>((ref) {
                              return DropdownMenuItem<String>(
                                value: ref['id'] as String,
                                child: Text('${ref['original_name']} (${ref['document_type']})'),
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
                          if (_selectedReferenceId != null) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _previewReference,
                              icon: const Icon(Icons.visibility),
                              label: const Text('Preview Document'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                minimumSize: const Size(double.infinity, 48),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    if (_selectedReferenceId != null)
                      const SizedBox(height: 16),
                    if (_selectedReferenceId == null) ...[
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
                      ),
                    ],
                    if (_isExtracting || _isUploading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_fields.isNotEmpty) ...[
                      _buildDocumentLanguageSettings(),
                      ..._fields.map((field) => _buildField(field)),
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
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Font Family:'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _selectedFontFamily,
                                    items: _supportedFontFamilies.map((fontFamily) => DropdownMenuItem<String>(
                                      value: fontFamily,
                                      child: Text(fontFamily),
                                    )).toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedFontFamily = value);
                                    },
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xfff9fafb),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Font Size:'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int>(
                                    value: _selectedFontSize,
                                    items: _supportedFontSizes.map((fontSize) => DropdownMenuItem<int>(
                                      value: fontSize,
                                      child: Text(fontSize.toString()),
                                    )).toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedFontSize = value);
                                    },
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xfff9fafb),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDocumentLayoutSettings(),
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

  // Placeholder before any document is generated


  Widget _buildField(DocumentField field) {
    if (field.type == 'group' && field.fields.isNotEmpty) {
      return _buildGroupField(field);
    }

    final isRequired = field.required;
    final label = isRequired ? '${field.label} *' : field.label;

    Widget input;
    switch (field.type) {
      case 'dropdown':
        final items = field.options
            .map((option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ))
            .toList();
        final currentValue = _dropdownValues[field.name];
        final value = items.any((item) => item.value == currentValue)
            ? currentValue
            : (items.isNotEmpty ? items.first.value : null);
        input = DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: (selected) {
            if (selected == null) return;
            setState(() => _dropdownValues[field.name] = selected);
          },
          decoration: InputDecoration(
            hintText: field.hint,
            filled: true,
            fillColor: const Color(0xfff9fafb),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        break;
      case 'boolean':
        input = Container(
          decoration: BoxDecoration(
            color: const Color(0xfff9fafb),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: CheckboxListTile(
            value: _boolValues[field.name] ?? false,
            onChanged: (selected) {
              setState(() => _boolValues[field.name] = selected ?? false);
            },
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(field.hint ?? 'Yes'),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        );
        break;
      case 'multiselect':
        final selectedValues = _multiselectValues.putIfAbsent(field.name, () => <String>{});
        input = Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xfff9fafb),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: field.options.map((option) {
              final isSelected = selectedValues.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                selectedColor: accentColor.withValues(alpha: 0.18),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedValues.add(option);
                    } else {
                      selectedValues.remove(option);
                    }
                  });
                },
              );
            }).toList(),
          ),
        );
        break;
      case 'date':
        final controller = _fieldControllers.putIfAbsent(
          field.name,
          () => TextEditingController(),
        );
        input = TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () => _selectDate(controller),
          decoration: InputDecoration(
            hintText: field.hint ?? 'DD-MM-YYYY',
            suffixIcon: const Icon(Icons.calendar_today),
            filled: true,
            fillColor: const Color(0xfff9fafb),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        break;
      case 'textarea':
        final controller = _fieldControllers.putIfAbsent(
          field.name,
          () => TextEditingController(),
        );
        input = TextFormField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: field.hint,
            suffixIcon: VoiceFieldMicIcon(
              language: _selectedLanguage,
              controller: controller,
            ),
            filled: true,
            fillColor: const Color(0xfff9fafb),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        break;
      case 'number':
        final controller = _fieldControllers.putIfAbsent(
          field.name,
          () => TextEditingController(),
        );
        input = TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: field.hint,
            suffixIcon: VoiceFieldMicIcon(
              language: _selectedLanguage,
              controller: controller,
            ),
            filled: true,
            fillColor: const Color(0xfff9fafb),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        break;
      default:
        final controller = _fieldControllers.putIfAbsent(
          field.name,
          () => TextEditingController(),
        );
        input = TextFormField(
          controller: controller,
          maxLines: field.type == 'long_text' ? 4 : 1,
          decoration: InputDecoration(
            hintText: field.hint,
            suffixIcon: VoiceFieldMicIcon(
              language: _selectedLanguage,
              controller: controller,
            ),
            filled: true,
            fillColor: const Color(0xfff9fafb),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          input,
        ],
      ),
    );
  }

  Widget _buildGroupField(DocumentField field) {
    final controllerRows = _groupFieldControllers[field.name] ?? const [];
    final dropdownRows = _groupDropdownValues[field.name] ?? const [];
    final boolRows = _groupBoolValues[field.name] ?? const [];
    final multiselectRows = _groupMultiselectValues[field.name] ?? const [];

    Widget buildSubField(DocumentField subField, int rowIndex) {
      final label = subField.required ? '${subField.label} *' : subField.label;
      Widget input;

      switch (subField.type) {
        case 'dropdown':
          final row = rowIndex < dropdownRows.length ? dropdownRows[rowIndex] : <String, String>{};
          final items = subField.options
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ))
              .toList();
          final currentValue = row[subField.name];
          final value = items.any((item) => item.value == currentValue)
              ? currentValue
              : (items.isNotEmpty ? items.first.value : null);
          input = DropdownButtonFormField<String>(
            value: value,
            items: items,
            onChanged: (selected) {
              if (selected == null) return;
              setState(() {
                _groupDropdownValues[field.name]![rowIndex][subField.name] = selected;
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
          );
          break;
        case 'boolean':
          final row = rowIndex < boolRows.length ? boolRows[rowIndex] : <String, bool>{};
          input = Container(
            decoration: BoxDecoration(
              color: const Color(0xfff9fafb),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: CheckboxListTile(
              value: row[subField.name] ?? false,
              onChanged: (selected) {
                setState(() {
                  _groupBoolValues[field.name]![rowIndex][subField.name] = selected ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(subField.hint ?? 'Yes'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          );
          break;
        case 'multiselect':
          final row = rowIndex < multiselectRows.length
              ? multiselectRows[rowIndex]
              : <String, Set<String>>{};
          final selectedValues = row.putIfAbsent(subField.name, () => <String>{});
          input = Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff9fafb),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subField.options.map((option) {
                final isSelected = selectedValues.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  selectedColor: accentColor.withValues(alpha: 0.18),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedValues.add(option);
                      } else {
                        selectedValues.remove(option);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          );
          break;
        case 'date':
          final controller = _groupFieldControllers[field.name]![rowIndex][subField.name]!;
          input = TextFormField(
            controller: controller,
            readOnly: true,
            onTap: () => _selectDate(controller),
            decoration: InputDecoration(
              hintText: subField.hint ?? 'DD-MM-YYYY',
              suffixIcon: const Icon(Icons.calendar_today),
              filled: true,
              fillColor: const Color(0xfff9fafb),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          break;
        case 'textarea':
          final controller =
              _groupFieldControllers[field.name]![rowIndex][subField.name]!;
          input = TextFormField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: subField.hint,
              suffixIcon: VoiceFieldMicIcon(
                language: _selectedLanguage,
                controller: controller,
              ),
              filled: true,
              fillColor: const Color(0xfff9fafb),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          break;
        case 'number':
          final controller =
              _groupFieldControllers[field.name]![rowIndex][subField.name]!;
          input = TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: subField.hint,
              suffixIcon: VoiceFieldMicIcon(
                language: _selectedLanguage,
                controller: controller,
              ),
              filled: true,
              fillColor: const Color(0xfff9fafb),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          break;
        default:
          final controller =
              _groupFieldControllers[field.name]![rowIndex][subField.name]!;
          input = TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: subField.hint,
              suffixIcon: VoiceFieldMicIcon(
                language: _selectedLanguage,
                controller: controller,
              ),
              filled: true,
              fillColor: const Color(0xfff9fafb),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          break;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            input,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xfffcfcfd),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    field.required ? '${field.label} *' : field.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (field.repeatable)
                  TextButton.icon(
                    onPressed: () => _addGroupRow(field),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(controllerRows.length, (rowIndex) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (field.repeatable || controllerRows.length > 1)
                      Row(
                        children: [
                          Text(
                            '${field.label} ${rowIndex + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          if (controllerRows.length > 1)
                            IconButton(
                              onPressed: () => _removeGroupRow(field, rowIndex),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove',
                            ),
                        ],
                      ),
                    ...field.fields.map((subField) => buildSubField(subField, rowIndex)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackButton(String url) {
    return ElevatedButton.icon(
      onPressed: () {
        html.window.open(url, '_blank');
      },
      icon: const Icon(Icons.open_in_browser),
      label: const Text('Open in Browser'),
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    final previewUrl = _generatedPdfViewUrl;
    final previewType = _generatedPdfViewType;

    if (previewUrl == null || previewType == null) {
      return _buildPlaceholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Generated Document Preview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (_generatedPdf != null)
              IconButton(
                tooltip: 'Download PDF',
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () async {
                  await ApiService().downloadGeneratedDocument(_generatedPdf!);
                },
              ),
            if (_generatedDocx != null)
              IconButton(
                tooltip: 'Download DOCX',
                icon: const Icon(Icons.description),
                onPressed: () async {
                  await ApiService().downloadGeneratedDocument(_generatedDocx!);
                },
              ),
            IconButton(
              tooltip: 'Open large preview',
              icon: const Icon(Icons.open_in_full),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => Dialog(
                    insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SizedBox(
                      width: 900,
                      height: 650,
                      child: _GeneratedPreviewDialog(
                        previewUrl: previewUrl,
                        accentColor: accentColor,
                        generatedPdf: _generatedPdf,
                        generatedDocx: _generatedDocx,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _pdfLoadFailed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'Preview unavailable inside the app.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        _buildFallbackButton(previewUrl),
                      ],
                    ),
                  )
                : kIsWeb
                    ? web_preview.buildPreviewIframe(previewType)
                    : SfPdfViewer.network(
                        previewUrl,
                        canShowScrollHead: true,
                        canShowScrollStatus: true,
                        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                          setState(() {
                            _pdfLoadFailed = true;
                          });
                        },
                      ),
          ),
        ),
      ],
    );
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

















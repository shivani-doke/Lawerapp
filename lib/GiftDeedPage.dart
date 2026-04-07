import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import '../services/api_service.dart';
import 'upload_context.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'widgets/dynamic_document_form.dart';
import 'web_preview_iframe_stub.dart'
    if (dart.library.html) 'web_preview_iframe_web.dart' as web_preview;

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
  final Map<String, String> _validationErrors = {};

  // Reference document (used for both extraction and generation)
  PlatformFile? _referenceFile;

  // Saved references management
  List<Map<String, dynamic>> _savedReferences = [];
  String? _selectedReferenceId;
  bool _isLoadingReferences = false;
  bool _isUploading = false;
  List<Map<String, dynamic>> _clients = [];
  bool _isLoadingClients = false;
  final Map<String, List<String?>> _linkedClientNamesByGroup = {};
  final Map<String, List<String?>> _linkedClientIdsByGroup = {};

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
    _loadClients();
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
    _linkedClientNamesByGroup.clear();
    _linkedClientIdsByGroup.clear();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoadingClients = true);
    try {
      final clients = await ApiService().getClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _isLoadingClients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingClients = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load clients: $e')),
      );
    }
  }

  DocumentField? _findFieldByName(String fieldName) {
    for (final field in _fields) {
      if (field.name == fieldName) {
        return field;
      }
    }
    return null;
  }

  void _applyClientToGiftParty({
    required String groupName,
    required Map<String, dynamic> client,
    required int rowIndex,
  }) {
    final groupField = _findFieldByName(groupName);
    final rows = _groupFieldControllers[groupName];

    if (groupField == null ||
        groupField.type != 'group' ||
        rows == null ||
        rows.length <= rowIndex) {
      return;
    }

    final controllerRow = rows[rowIndex];
    final mappedValues = <String, String>{
      'name': (client['name'] ?? '').toString(),
      'age': (client['age'] ?? '').toString(),
      'occupation': (client['occupation'] ?? '').toString(),
      'address': (client['address'] ?? '').toString(),
      'pan': (client['pan_number'] ?? '').toString(),
      'aadhaar': (client['aadhar_number'] ?? '').toString(),
    };

    setState(() {
      _linkedClientNamesByGroup.putIfAbsent(groupName, () => <String?>[]);
      _linkedClientIdsByGroup.putIfAbsent(groupName, () => <String?>[]);
      while (_linkedClientNamesByGroup[groupName]!.length <= rowIndex) {
        _linkedClientNamesByGroup[groupName]!.add(null);
      }
      while (_linkedClientIdsByGroup[groupName]!.length <= rowIndex) {
        _linkedClientIdsByGroup[groupName]!.add(null);
      }
      _linkedClientNamesByGroup[groupName]![rowIndex] =
          (client['name'] ?? '').toString();
      _linkedClientIdsByGroup[groupName]![rowIndex] =
          (client['id'] ?? '').toString();

      mappedValues.forEach((fieldName, value) {
        final controller = controllerRow[fieldName];
        if (controller != null && value.isNotEmpty) {
          controller.text = value;
          _validationErrors.remove(_groupValidationKey(
            groupField,
            rowIndex,
            groupField.fields.firstWhere((subField) => subField.name == fieldName),
          ));
        }
      });
    });
  }

  String? _giftClientAssignmentLabel({
    required String clientId,
    required String currentGroupName,
    required int currentRowIndex,
  }) {
    for (final entry in _linkedClientIdsByGroup.entries) {
      final groupName = entry.key;
      final linkedIds = entry.value;
      for (var rowIndex = 0; rowIndex < linkedIds.length; rowIndex++) {
        final linkedId = linkedIds[rowIndex];
        if (linkedId == null || linkedId.isEmpty || linkedId != clientId) {
          continue;
        }
        if (groupName == currentGroupName && rowIndex == currentRowIndex) {
          continue;
        }
        final partyLabel = groupName == 'donor_details' ? 'Donor' : 'Donee';
        return '$partyLabel ${rowIndex + 1}';
      }
    }
    return null;
  }

  String _groupValidationKey(
    DocumentField groupField,
    int rowIndex,
    DocumentField subField,
  ) {
    return '${groupField.name}.$rowIndex.${subField.name}';
  }

  bool _usesChoiceState(String type) {
    return type == 'dropdown' || type == 'radio';
  }

  Map<String, TextEditingController> _createGroupControllerRow(
      DocumentField groupField) {
    final controllers = <String, TextEditingController>{};
    for (final nestedField in groupField.fields) {
      if (_usesChoiceState(nestedField.type) ||
          nestedField.type == 'boolean' ||
          nestedField.type == 'multiselect' ||
          (nestedField.type == 'group' && nestedField.fields.isNotEmpty)) {
        continue;
      }
      controllers[nestedField.name] = TextEditingController(
        text: nestedField.defaultValue?.toString() ?? '',
      );
    }
    return controllers;
  }

  Map<String, String> _createGroupDropdownRow(DocumentField groupField) {
    final values = <String, String>{};
    for (final nestedField in groupField.fields) {
      if (_usesChoiceState(nestedField.type)) {
        final defaultValue = nestedField.defaultValue?.toString();
        values[nestedField.name] =
            defaultValue != null && nestedField.options.contains(defaultValue)
                ? defaultValue
                : (nestedField.options.isNotEmpty ? nestedField.options.first : '');
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
    _linkedClientNamesByGroup[field.name] = [null];
    _linkedClientIdsByGroup[field.name] = [null];
  }

  void _addGroupRow(DocumentField field) {
    if (field.type != 'group' || field.fields.isEmpty) {
      return;
    }

    final maxItems = field.maxItems;
    final currentCount = _groupFieldControllers[field.name]?.length ?? 0;
    if (maxItems != null && currentCount >= maxItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${field.label} allows a maximum of $maxItems entries.'),
        ),
      );
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
      _linkedClientNamesByGroup.putIfAbsent(field.name, () => <String?>[]);
      _linkedClientNamesByGroup[field.name]!.add(null);
      _linkedClientIdsByGroup.putIfAbsent(field.name, () => <String?>[]);
      _linkedClientIdsByGroup[field.name]!.add(null);
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

    final minItems = field.minItems;
    if (minItems != null && controllerRows.length <= minItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${field.label} requires at least $minItems entries.'),
        ),
      );
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
      if (_linkedClientNamesByGroup[field.name] != null &&
          _linkedClientNamesByGroup[field.name]!.length > index) {
        _linkedClientNamesByGroup[field.name]!.removeAt(index);
      }
      if (_linkedClientIdsByGroup[field.name] != null &&
          _linkedClientIdsByGroup[field.name]!.length > index) {
        _linkedClientIdsByGroup[field.name]!.removeAt(index);
      }
      final keyPrefix = '${field.name}.$index.';
      _validationErrors.removeWhere((key, value) => key.startsWith(keyPrefix));
    });
  }

  dynamic _getTopLevelFieldValue(DocumentField field) {
    if (_usesChoiceState(field.type)) {
      return _dropdownValues[field.name] ?? '';
    }
    if (field.type == 'boolean') {
      return _boolValues[field.name] ?? false;
    }
    if (field.type == 'multiselect') {
      return _multiselectValues[field.name] ?? <String>{};
    }
    return _fieldControllers[field.name]?.text ?? '';
  }

  dynamic _getGroupFieldValue(
    DocumentField groupField,
    DocumentField subField,
    int rowIndex,
  ) {
    if (_usesChoiceState(subField.type)) {
      return _groupDropdownValues[groupField.name]?[rowIndex][subField.name] ?? '';
    }
    if (subField.type == 'boolean') {
      return _groupBoolValues[groupField.name]?[rowIndex][subField.name] ?? false;
    }
    if (subField.type == 'multiselect') {
      return _groupMultiselectValues[groupField.name]?[rowIndex][subField.name] ??
          <String>{};
    }
    return _groupFieldControllers[groupField.name]?[rowIndex][subField.name]?.text ?? '';
  }

  double? _parseNumericValue(dynamic rawValue) {
    if (rawValue == null) return null;
    final normalized = rawValue
        .toString()
        .replaceAll(',', '')
        .replaceAll('%', '')
        .replaceAll(RegExp(r'[^\d.\-]'), '')
        .trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  bool _matchesShowIfCondition(
    dynamic actualValue,
    String operator,
    String expectedToken,
  ) {
    final actualNumber = _parseNumericValue(actualValue);
    final expectedNumber = double.tryParse(expectedToken);

    if (actualNumber != null && expectedNumber != null) {
      switch (operator) {
        case '<':
          return actualNumber < expectedNumber;
        case '<=':
          return actualNumber <= expectedNumber;
        case '>':
          return actualNumber > expectedNumber;
        case '>=':
          return actualNumber >= expectedNumber;
        case '!=':
          return actualNumber != expectedNumber;
        case '=':
        case '==':
          return actualNumber == expectedNumber;
      }
    }

    final normalizedActual = (actualValue ?? '').toString().trim().toLowerCase();
    final normalizedExpected = expectedToken.trim().toLowerCase();

    switch (operator) {
      case '!=':
        return normalizedActual != normalizedExpected;
      case '=':
      case '==':
        return normalizedActual == normalizedExpected;
      default:
        return false;
    }
  }

  bool _isFieldVisible(
    DocumentField field, {
    DocumentField? groupField,
    int? rowIndex,
  }) {
    final condition = field.showIf?.trim();
    if (condition == null || condition.isEmpty) {
      return true;
    }

    final match = RegExp(r'^\s*([a-zA-Z0-9_]+)\s*(<=|>=|==|!=|=|<|>)\s*(.+?)\s*$')
        .firstMatch(condition);
    if (match == null) {
      return true;
    }

    final targetFieldName = match.group(1)!;
    final operator = match.group(2)!;
    var expectedToken = match.group(3)!.trim();
    if ((expectedToken.startsWith('"') && expectedToken.endsWith('"')) ||
        (expectedToken.startsWith("'") && expectedToken.endsWith("'"))) {
      expectedToken = expectedToken.substring(1, expectedToken.length - 1);
    }

    dynamic actualValue;
    if (groupField != null && rowIndex != null) {
      final matches = groupField.fields.where((nested) => nested.name == targetFieldName);
      if (matches.isEmpty) {
        return true;
      }
      actualValue = _getGroupFieldValue(groupField, matches.first, rowIndex);
    } else {
      final matches = _fields.where((candidate) => candidate.name == targetFieldName);
      if (matches.isEmpty) {
        return true;
      }
      actualValue = _getTopLevelFieldValue(matches.first);
    }

    return _matchesShowIfCondition(actualValue, operator, expectedToken);
  }

  bool _isFieldValueEmpty(dynamic value) {
    if (value is Set) return value.isEmpty;
    if (value is List) return value.isEmpty;
    if (value is String) return value.trim().isEmpty;
    return value == null;
  }

  String? _validateFieldValue(DocumentField field, dynamic rawValue) {
    if (!_isFieldVisible(field) || _isFieldValueEmpty(rawValue)) {
      return null;
    }

    final value = rawValue.toString().trim();
    final validation = field.validation?.trim().toLowerCase();

    if (validation == 'pan' &&
        !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(value.toUpperCase())) {
      return 'Enter a valid PAN number.';
    }

    if (validation == 'aadhaar' &&
        !RegExp(r'^\d{12}$').hasMatch(value.replaceAll(' ', ''))) {
      return 'Enter a valid 12-digit Aadhaar number.';
    }

    if (field.type == 'percentage') {
      final parsed = _parseNumericValue(value);
      if (parsed == null || parsed < 0 || parsed > 100) {
        return 'Enter a percentage between 0 and 100.';
      }
    }

    if (field.type == 'currency' && _parseNumericValue(value) == null) {
      return 'Enter a valid amount.';
    }

    return null;
  }

  String? _validateGroupFieldValue(
    DocumentField groupField,
    DocumentField subField,
    int rowIndex,
  ) {
    if (!_isFieldVisible(subField, groupField: groupField, rowIndex: rowIndex)) {
      return null;
    }
    return _validateFieldValue(subField, _getGroupFieldValue(groupField, subField, rowIndex));
  }

  Map<String, String> _collectValidationErrors() {
    final errors = <String, String>{};

    for (final field in _fields) {
      if (!_isFieldVisible(field)) {
        continue;
      }

      if (field.type == 'group' && field.fields.isNotEmpty) {
        final rows = _groupFieldControllers[field.name] ?? const [];
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
          if (_isGroupRowEmpty(field, rowIndex)) {
            continue;
          }
          for (final subField in field.fields) {
            final error = _validateGroupFieldValue(field, subField, rowIndex);
            if (error != null) {
              errors[_groupValidationKey(field, rowIndex, subField)] = error;
            }
          }
        }
        continue;
      }

      final error = _validateFieldValue(field, _getTopLevelFieldValue(field));
      if (error != null) {
        errors[field.name] = error;
      }
    }

    return errors;
  }

  bool _isTopLevelFieldMissing(DocumentField field) {
    if (!_isFieldVisible(field) || !field.required) {
      return false;
    }
    return _isFieldValueEmpty(_getTopLevelFieldValue(field));
  }

  bool _isGroupSubFieldMissing(
    DocumentField groupField,
    DocumentField subField,
    int rowIndex,
  ) {
    if (!_isFieldVisible(subField, groupField: groupField, rowIndex: rowIndex) ||
        !subField.required) {
      return false;
    }
    return _isFieldValueEmpty(_getGroupFieldValue(groupField, subField, rowIndex));
  }

  bool _isGroupRowEmpty(DocumentField groupField, int rowIndex) {
    for (final subField in groupField.fields) {
      if (!_isFieldVisible(subField, groupField: groupField, rowIndex: rowIndex)) {
        continue;
      }
      if (!_isFieldValueEmpty(_getGroupFieldValue(groupField, subField, rowIndex))) {
        return false;
      }
    }

    return true;
  }

  List<String> _collectMissingRequiredFields() {
    final missingFields = <String>[];

    for (final field in _fields) {
      if (!_isFieldVisible(field)) {
        continue;
      }
      if (field.type == 'group' && field.fields.isNotEmpty) {
        final rows = _groupFieldControllers[field.name] ?? const [];
        final minItems = field.minItems ?? (field.required ? 1 : 0);
        final visibleRowCount = List.generate(rows.length, (index) => index)
            .where((rowIndex) => !_isGroupRowEmpty(field, rowIndex))
            .length;

        if (minItems > 0 && visibleRowCount < minItems) {
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
    if (!_isFieldVisible(field)) {
      return null;
    }
    if (_usesChoiceState(field.type)) {
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
          if (!_isFieldVisible(subField, groupField: field, rowIndex: rowIndex)) {
            continue;
          }
          if (_usesChoiceState(subField.type)) {
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
    _validationErrors.clear();
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
    _validationErrors.clear();
    _disposeGroupControllers();

    for (var field in _fields) {
      if (field.type == 'group' && field.fields.isNotEmpty) {
        _initializeGroupField(field);
      } else if (_usesChoiceState(field.type)) {
        final defaultValue = field.defaultValue?.toString();
        _dropdownValues[field.name] =
            defaultValue != null && field.options.contains(defaultValue)
                ? defaultValue
                : (field.options.isNotEmpty ? field.options.first : '');
      } else if (field.type == 'boolean') {
        _boolValues[field.name] = field.defaultValue == true;
      } else if (field.type == 'multiselect') {
        _multiselectValues[field.name] = <String>{};
      } else {
        _fieldControllers[field.name] = TextEditingController(
          text: field.defaultValue?.toString() ?? '',
        );
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
      final fields = parseDocumentFields(fieldsJson);

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
      final fields = parseDocumentFields(fieldsJson);
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

        final fields = parseDocumentFields(extractedFields);

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
    final validationErrors = _collectValidationErrors();

    setState(() {
      _validationErrors
        ..clear()
        ..addAll(validationErrors);
    });

    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please fill all required fields: ${missingFields.join(', ')}'),
        ),
      );
      return;
    }

    if (validationErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the highlighted field values.'),
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
        for (var field in _fields)
          if (_isFieldVisible(field)) field.name: _serializeTopLevelFieldValue(field),
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

  Future<void> _showClientAutofillDialog({
    required DocumentField field,
    required int rowIndex,
  }) async {
    if (_isLoadingClients) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clients are still loading. Please wait.')),
      );
      return;
    }

    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No clients available for autofill yet.')),
      );
      return;
    }

    final selectedClient = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        final searchController = TextEditingController();
        var filteredClients = List<Map<String, dynamic>>.from(_clients);

        return StatefulBuilder(
          builder: (context, setModalState) {
            void applySearch(String query) {
              final normalized = query.trim().toLowerCase();
              setModalState(() {
                filteredClients = _clients.where((client) {
                  final name = (client['name'] ?? '').toString().toLowerCase();
                  final phone = (client['phone'] ?? '').toString().toLowerCase();
                  final pan = (client['pan_number'] ?? '').toString().toLowerCase();
                  final aadhar =
                      (client['aadhar_number'] ?? '').toString().toLowerCase();
                  return normalized.isEmpty ||
                      name.contains(normalized) ||
                      phone.contains(normalized) ||
                      pan.contains(normalized) ||
                      aadhar.contains(normalized);
                }).toList();
              });
            }

            return AlertDialog(
              title: Text('Autofill ${field.label}'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: applySearch,
                      decoration: const InputDecoration(
                        hintText: 'Search by name, phone, PAN, or Aadhar',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filteredClients.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No matching clients found.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredClients.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final client = filteredClients[index];
                                final clientId =
                                    (client['id'] ?? '').toString();
                                final assignmentLabel = clientId.isEmpty
                                    ? null
                                    : _giftClientAssignmentLabel(
                                        clientId: clientId,
                                        currentGroupName: field.name,
                                        currentRowIndex: rowIndex,
                                      );
                                final isAssignedElsewhere =
                                    assignmentLabel != null;
                                final clientName =
                                    (client['name'] ?? 'Unnamed Client').toString();
                                final phone =
                                    (client['phone'] ?? '').toString().trim();
                                final occupation =
                                    (client['occupation'] ?? '').toString().trim();
                                final subtitleParts = [
                                  if (phone.isNotEmpty) phone,
                                  if (occupation.isNotEmpty) occupation,
                                  if (assignmentLabel != null)
                                    'Already linked to $assignmentLabel',
                                ];
                                return ListTile(
                                  title: Text(clientName),
                                  subtitle: subtitleParts.isEmpty
                                      ? null
                                      : Text(subtitleParts.join(' • ')),
                                  trailing: isAssignedElsewhere
                                      ? const Icon(Icons.block, color: Colors.grey)
                                      : const Icon(Icons.chevron_right),
                                  enabled: !isAssignedElsewhere,
                                  onTap: isAssignedElsewhere
                                      ? null
                                      : () => Navigator.of(dialogContext).pop(client),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedClient == null) {
      return;
    }

    final selectedClientId = (selectedClient['id'] ?? '').toString();
    final assignmentLabel = selectedClientId.isEmpty
        ? null
        : _giftClientAssignmentLabel(
            clientId: selectedClientId,
            currentGroupName: field.name,
            currentRowIndex: rowIndex,
          );
    if (assignmentLabel != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This client is already linked to $assignmentLabel. Please choose a different client.',
          ),
        ),
      );
      return;
    }

    _applyClientToGiftParty(
      groupName: field.name,
      client: selectedClient,
      rowIndex: rowIndex,
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

  Widget? _buildGiftGroupRowHeader(
    BuildContext context,
    DocumentField field,
    int rowIndex,
  ) {
    final supportsClientAutofill =
        field.name == 'donor_details' || field.name == 'donee_details';

    if (!supportsClientAutofill) {
      return null;
    }

    final linkedClients = _linkedClientNamesByGroup[field.name];
    final linkedClientName =
        linkedClients != null && linkedClients.length > rowIndex
            ? linkedClients[rowIndex]
            : null;

    return Row(
      children: [
        Expanded(
          child: linkedClientName == null || linkedClientName.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  'Linked client: $linkedClientName',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
        ),
        TextButton.icon(
          onPressed: () => _showClientAutofillDialog(
            field: field,
            rowIndex: rowIndex,
          ),
          icon: const Icon(Icons.person_search, size: 18),
          label: const Text('Autofill from Client'),
        ),
      ],
    );
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
                      DynamicDocumentForm(
                        fields: _fields,
                        accentColor: accentColor,
                        selectedLanguage: _selectedLanguage,
                        fieldControllers: _fieldControllers,
                        dropdownValues: _dropdownValues,
                        boolValues: _boolValues,
                        multiselectValues: _multiselectValues,
                        groupFieldControllers: _groupFieldControllers,
                        groupDropdownValues: _groupDropdownValues,
                        groupBoolValues: _groupBoolValues,
                        groupMultiselectValues: _groupMultiselectValues,
                        validationErrors: _validationErrors,
                        isFieldVisible: _isFieldVisible,
                        groupValidationKey: _groupValidationKey,
                        onSelectDate: _selectDate,
                        onTopLevelChoiceChanged: (field, selected) {
                          setState(() {
                            _dropdownValues[field.name] = selected;
                            _validationErrors.remove(field.name);
                          });
                        },
                        onTopLevelBoolChanged: (field, selected) {
                          setState(() {
                            _boolValues[field.name] = selected;
                            _validationErrors.remove(field.name);
                          });
                        },
                        onTopLevelMultiselectChanged:
                            (field, option, selected) {
                          setState(() {
                            final values = _multiselectValues.putIfAbsent(
                              field.name,
                              () => <String>{},
                            );
                            if (selected) {
                              values.add(option);
                            } else {
                              values.remove(option);
                            }
                            _validationErrors.remove(field.name);
                          });
                        },
                        onTopLevelTextChanged: (field, value) {
                          setState(() => _validationErrors.remove(field.name));
                        },
                        onGroupChoiceChanged:
                            (groupField, rowIndex, subField, selected) {
                          setState(() {
                            _groupDropdownValues[groupField.name]![rowIndex]
                                [subField.name] = selected;
                            _validationErrors.remove(
                              _groupValidationKey(
                                groupField,
                                rowIndex,
                                subField,
                              ),
                            );
                          });
                        },
                        onGroupBoolChanged:
                            (groupField, rowIndex, subField, selected) {
                          setState(() {
                            _groupBoolValues[groupField.name]![rowIndex]
                                [subField.name] = selected;
                            _validationErrors.remove(
                              _groupValidationKey(
                                groupField,
                                rowIndex,
                                subField,
                              ),
                            );
                          });
                        },
                        onGroupMultiselectChanged:
                            (groupField, rowIndex, subField, option, selected) {
                          setState(() {
                            final rowValues = _groupMultiselectValues[
                                groupField.name]![rowIndex];
                            final values = rowValues.putIfAbsent(
                              subField.name,
                              () => <String>{},
                            );
                            if (selected) {
                              values.add(option);
                            } else {
                              values.remove(option);
                            }
                            _validationErrors.remove(
                              _groupValidationKey(
                                groupField,
                                rowIndex,
                                subField,
                              ),
                            );
                          });
                        },
                        onGroupTextChanged:
                            (groupField, rowIndex, subField, value) {
                          setState(() {
                            _validationErrors.remove(
                              _groupValidationKey(
                                groupField,
                                rowIndex,
                                subField,
                              ),
                            );
                          });
                        },
                        onAddGroupRow: _addGroupRow,
                        onRemoveGroupRow: _removeGroupRow,
                        buildGroupRowHeader: _buildGiftGroupRowHeader,
                      ),
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

















import 'package:flutter/material.dart';

import 'voice_dictation_button.dart';

class DocumentField {
  final String name;
  final String label;
  final String type;
  final String? hint;
  final bool required;
  final List<String> options;
  final bool repeatable;
  final List<DocumentField> fields;
  final String? validation;
  final dynamic defaultValue;
  final String? showIf;
  final int? minItems;
  final int? maxItems;

  DocumentField({
    required this.name,
    required this.label,
    this.type = 'text',
    this.hint,
    this.required = true,
    this.options = const [],
    this.repeatable = false,
    this.fields = const [],
    this.validation,
    this.defaultValue,
    this.showIf,
    this.minItems,
    this.maxItems,
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
      validation: json['validation']?.toString(),
      defaultValue: json['default'],
      showIf: json['show_if']?.toString(),
      minItems: json['min'] is num ? (json['min'] as num).toInt() : null,
      maxItems: json['max'] is num ? (json['max'] as num).toInt() : null,
      fields: rawFields is List
          ? rawFields
              .whereType<Map>()
              .map((e) => DocumentField.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

List<DocumentField> parseDocumentFields(dynamic raw) {
  if (raw is! List) return [];
  final parsed = <DocumentField>[];

  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);

    if (map.containsKey('name') && map.containsKey('label')) {
      final field = DocumentField.fromJson(map);
      if (field.name.isNotEmpty && field.label.isNotEmpty) {
        parsed.add(field);
      }
      continue;
    }

    final nested = map['fields'];
    if (nested is List) {
      parsed.addAll(parseDocumentFields(nested));
    }
  }

  return parsed;
}

typedef FieldVisibilityResolver = bool Function(
  DocumentField field, {
  DocumentField? groupField,
  int? rowIndex,
});

typedef GroupValidationKeyBuilder = String Function(
  DocumentField groupField,
  int rowIndex,
  DocumentField subField,
);

typedef GroupRowHeaderBuilder = Widget? Function(
  BuildContext context,
  DocumentField field,
  int rowIndex,
);

class DynamicDocumentForm extends StatelessWidget {
  final List<DocumentField> fields;
  final Color accentColor;
  final String selectedLanguage;
  final Map<String, TextEditingController> fieldControllers;
  final Map<String, String> dropdownValues;
  final Map<String, bool> boolValues;
  final Map<String, Set<String>> multiselectValues;
  final Map<String, List<Map<String, TextEditingController>>>
      groupFieldControllers;
  final Map<String, List<Map<String, String>>> groupDropdownValues;
  final Map<String, List<Map<String, bool>>> groupBoolValues;
  final Map<String, List<Map<String, Set<String>>>> groupMultiselectValues;
  final Map<String, String> validationErrors;
  final FieldVisibilityResolver isFieldVisible;
  final GroupValidationKeyBuilder groupValidationKey;
  final Future<void> Function(TextEditingController controller) onSelectDate;
  final void Function(DocumentField field, String selected)
      onTopLevelChoiceChanged;
  final void Function(DocumentField field, bool selected) onTopLevelBoolChanged;
  final void Function(DocumentField field, String option, bool selected)
      onTopLevelMultiselectChanged;
  final void Function(DocumentField field, String value) onTopLevelTextChanged;
  final void Function(
    DocumentField groupField,
    int rowIndex,
    DocumentField subField,
    String selected,
  ) onGroupChoiceChanged;
  final void Function(
    DocumentField groupField,
    int rowIndex,
    DocumentField subField,
    bool selected,
  ) onGroupBoolChanged;
  final void Function(
    DocumentField groupField,
    int rowIndex,
    DocumentField subField,
    String option,
    bool selected,
  ) onGroupMultiselectChanged;
  final void Function(
    DocumentField groupField,
    int rowIndex,
    DocumentField subField,
    String value,
  ) onGroupTextChanged;
  final void Function(DocumentField field) onAddGroupRow;
  final void Function(DocumentField field, int rowIndex) onRemoveGroupRow;
  final GroupRowHeaderBuilder? buildGroupRowHeader;

  const DynamicDocumentForm({
    super.key,
    required this.fields,
    required this.accentColor,
    required this.selectedLanguage,
    required this.fieldControllers,
    required this.dropdownValues,
    required this.boolValues,
    required this.multiselectValues,
    required this.groupFieldControllers,
    required this.groupDropdownValues,
    required this.groupBoolValues,
    required this.groupMultiselectValues,
    required this.validationErrors,
    required this.isFieldVisible,
    required this.groupValidationKey,
    required this.onSelectDate,
    required this.onTopLevelChoiceChanged,
    required this.onTopLevelBoolChanged,
    required this.onTopLevelMultiselectChanged,
    required this.onTopLevelTextChanged,
    required this.onGroupChoiceChanged,
    required this.onGroupBoolChanged,
    required this.onGroupMultiselectChanged,
    required this.onGroupTextChanged,
    required this.onAddGroupRow,
    required this.onRemoveGroupRow,
    this.buildGroupRowHeader,
  });

  bool _usesChoiceState(String type) => type == 'dropdown' || type == 'radio';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: fields.map((field) => _buildField(context, field)).toList(),
    );
  }

  Widget _buildField(BuildContext context, DocumentField field) {
    if (!isFieldVisible(field)) {
      return const SizedBox.shrink();
    }
    if (field.type == 'group' && field.fields.isNotEmpty) {
      return _buildGroupField(context, field);
    }

    final isRequired = field.required;
    final label = isRequired ? '${field.label} *' : field.label;
    final errorText = validationErrors[field.name];

    Widget input;
    switch (field.type) {
      case 'dropdown':
        final items = field.options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              ),
            )
            .toList();
        final currentValue = dropdownValues[field.name];
        final value = items.any((item) => item.value == currentValue)
            ? currentValue
            : (items.isNotEmpty ? items.first.value : null);
        input = DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: (selected) {
            if (selected == null) return;
            onTopLevelChoiceChanged(field, selected);
          },
          decoration: _inputDecoration(
            hintText: field.hint,
            errorText: errorText,
          ),
        );
        break;
      case 'radio':
        final currentValue = dropdownValues[field.name];
        input = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: _containerDecoration(),
          child: Column(
            children: field.options.map((option) {
              return RadioListTile<String>(
                value: option,
                groupValue: currentValue,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(option),
                onChanged: (selected) {
                  if (selected == null) return;
                  onTopLevelChoiceChanged(field, selected);
                },
              );
            }).toList(),
          ),
        );
        break;
      case 'boolean':
        input = Container(
          decoration: _containerDecoration(),
          child: CheckboxListTile(
            value: boolValues[field.name] ?? false,
            onChanged: (selected) {
              onTopLevelBoolChanged(field, selected ?? false);
            },
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(field.hint ?? 'Yes'),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        );
        break;
      case 'multiselect':
        final selectedValues =
            multiselectValues.putIfAbsent(field.name, () => <String>{});
        input = Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: _containerDecoration(),
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
                  onTopLevelMultiselectChanged(field, option, selected);
                },
              );
            }).toList(),
          ),
        );
        break;
      case 'date':
        final controller = fieldControllers.putIfAbsent(
          field.name,
          () => TextEditingController(text: field.defaultValue?.toString() ?? ''),
        );
        input = TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () => onSelectDate(controller),
          decoration: _inputDecoration(
            hintText: field.hint ?? 'DD-MM-YYYY',
            errorText: errorText,
            suffixIcon: const Icon(Icons.calendar_today),
          ),
        );
        break;
      case 'textarea':
        final controller = fieldControllers.putIfAbsent(
          field.name,
          () => TextEditingController(text: field.defaultValue?.toString() ?? ''),
        );
        input = TextFormField(
          controller: controller,
          maxLines: 4,
          onChanged: (value) => onTopLevelTextChanged(field, value),
          decoration: _inputDecoration(
            hintText: field.hint,
            errorText: errorText,
            suffixIcon: VoiceFieldMicIcon(
              language: selectedLanguage,
              controller: controller,
            ),
          ),
        );
        break;
      case 'number':
      case 'percentage':
      case 'currency':
        final controller = fieldControllers.putIfAbsent(
          field.name,
          () => TextEditingController(text: field.defaultValue?.toString() ?? ''),
        );
        input = TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) => onTopLevelTextChanged(field, value),
          decoration: _inputDecoration(
            hintText: field.hint,
            errorText: errorText,
            prefixText: field.type == 'currency' ? 'Rs. ' : null,
            suffixText: field.type == 'percentage' ? '%' : null,
            suffixIcon: VoiceFieldMicIcon(
              language: selectedLanguage,
              controller: controller,
            ),
          ),
        );
        break;
      default:
        final controller = fieldControllers.putIfAbsent(
          field.name,
          () => TextEditingController(text: field.defaultValue?.toString() ?? ''),
        );
        input = TextFormField(
          controller: controller,
          maxLines: field.type == 'long_text' ? 4 : 1,
          onChanged: (value) => onTopLevelTextChanged(field, value),
          decoration: _inputDecoration(
            hintText: field.hint,
            errorText: errorText,
            suffixIcon: VoiceFieldMicIcon(
              language: selectedLanguage,
              controller: controller,
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          input,
        ],
      ),
    );
  }

  Widget _buildGroupField(BuildContext context, DocumentField field) {
    if (!isFieldVisible(field)) {
      return const SizedBox.shrink();
    }
    final controllerRows = groupFieldControllers[field.name] ??
        const <Map<String, TextEditingController>>[];
    final dropdownRows =
        groupDropdownValues[field.name] ?? const <Map<String, String>>[];
    final boolRows =
        groupBoolValues[field.name] ?? const <Map<String, bool>>[];
    final multiselectRows = groupMultiselectValues[field.name] ??
        const <Map<String, Set<String>>>[];

    Widget buildSubField(DocumentField subField, int rowIndex) {
      if (!isFieldVisible(subField, groupField: field, rowIndex: rowIndex)) {
        return const SizedBox.shrink();
      }
      final label = subField.required ? '${subField.label} *' : subField.label;
      final errorText =
          validationErrors[groupValidationKey(field, rowIndex, subField)];
      Widget input;

      switch (subField.type) {
        case 'dropdown':
          final row = rowIndex < dropdownRows.length
              ? dropdownRows[rowIndex]
              : <String, String>{};
          final items = subField.options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
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
              onGroupChoiceChanged(field, rowIndex, subField, selected);
            },
            decoration: _inputDecoration(
              hintText: subField.hint,
              errorText: errorText,
            ),
          );
          break;
        case 'radio':
          final row = rowIndex < dropdownRows.length
              ? dropdownRows[rowIndex]
              : <String, String>{};
          final currentValue = row[subField.name];
          input = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: _containerDecoration(),
            child: Column(
              children: subField.options.map((option) {
                return RadioListTile<String>(
                  value: option,
                  groupValue: currentValue,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(option),
                  onChanged: (selected) {
                    if (selected == null) return;
                    onGroupChoiceChanged(field, rowIndex, subField, selected);
                  },
                );
              }).toList(),
            ),
          );
          break;
        case 'boolean':
          final row =
              rowIndex < boolRows.length ? boolRows[rowIndex] : <String, bool>{};
          input = Container(
            decoration: _containerDecoration(),
            child: CheckboxListTile(
              value: row[subField.name] ?? false,
              onChanged: (selected) {
                onGroupBoolChanged(
                  field,
                  rowIndex,
                  subField,
                  selected ?? false,
                );
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
            decoration: _containerDecoration(),
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
                    onGroupMultiselectChanged(
                      field,
                      rowIndex,
                      subField,
                      option,
                      selected,
                    );
                  },
                );
              }).toList(),
            ),
          );
          break;
        case 'date':
          final controller =
              groupFieldControllers[field.name]![rowIndex][subField.name]!;
          input = TextFormField(
            controller: controller,
            readOnly: true,
            onTap: () => onSelectDate(controller),
            decoration: _inputDecoration(
              hintText: subField.hint ?? 'DD-MM-YYYY',
              errorText: errorText,
              suffixIcon: const Icon(Icons.calendar_today),
            ),
          );
          break;
        case 'textarea':
          final controller =
              groupFieldControllers[field.name]![rowIndex][subField.name]!;
          input = TextFormField(
            controller: controller,
            maxLines: 4,
            onChanged: (value) =>
                onGroupTextChanged(field, rowIndex, subField, value),
            decoration: _inputDecoration(
              hintText: subField.hint,
              errorText: errorText,
              suffixIcon: VoiceFieldMicIcon(
                language: selectedLanguage,
                controller: controller,
              ),
            ),
          );
          break;
        case 'number':
        case 'percentage':
        case 'currency':
          final controller =
              groupFieldControllers[field.name]![rowIndex][subField.name]!;
          input = TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) =>
                onGroupTextChanged(field, rowIndex, subField, value),
            decoration: _inputDecoration(
              hintText: subField.hint,
              errorText: errorText,
              prefixText: subField.type == 'currency' ? 'Rs. ' : null,
              suffixText: subField.type == 'percentage' ? '%' : null,
              suffixIcon: VoiceFieldMicIcon(
                language: selectedLanguage,
                controller: controller,
              ),
            ),
          );
          break;
        default:
          final controller =
              groupFieldControllers[field.name]![rowIndex][subField.name]!;
          input = TextFormField(
            controller: controller,
            maxLines: subField.type == 'long_text' ? 4 : 1,
            onChanged: (value) =>
                onGroupTextChanged(field, rowIndex, subField, value),
            decoration: _inputDecoration(
              hintText: subField.hint,
              errorText: errorText,
              suffixIcon: VoiceFieldMicIcon(
                language: selectedLanguage,
                controller: controller,
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    onPressed: field.maxItems != null &&
                            controllerRows.length >= field.maxItems!
                        ? null
                        : () => onAddGroupRow(field),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${field.label} ${rowIndex + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (buildGroupRowHeader != null)
                                  ...[
                                    const SizedBox(height: 4),
                                    buildGroupRowHeader!(
                                          context,
                                          field,
                                          rowIndex,
                                        ) ??
                                        const SizedBox.shrink(),
                                  ],
                              ],
                            ),
                          ),
                          if (controllerRows.length > 1)
                            IconButton(
                              onPressed: () => onRemoveGroupRow(field, rowIndex),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove',
                            ),
                        ],
                      ),
                    ...field.fields.map(
                      (subField) => buildSubField(subField, rowIndex),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    String? errorText,
    Widget? suffixIcon,
    String? prefixText,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      suffixText: suffixText,
      filled: true,
      fillColor: const Color(0xfff9fafb),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  BoxDecoration _containerDecoration() {
    return BoxDecoration(
      color: const Color(0xfff9fafb),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    );
  }
}

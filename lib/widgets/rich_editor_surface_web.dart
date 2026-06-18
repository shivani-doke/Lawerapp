// ignore_for_file: undefined_prefixed_name

import 'dart:async';

import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

typedef RichEditorChanged = void Function(String html, String plainText);

class RichEditorController {
  Future<String> Function()? _getHtml;
  String Function()? _getPlainText;
  void Function(String html)? _setHtml;
  void Function(String command, [String? value])? _execCommand;
  void Function(String findText, String replaceText)? _replaceAll;
  void Function()? _focus;

  Future<String> getHtml() async => _getHtml?.call() ?? '';
  String getPlainText() => _getPlainText?.call() ?? '';
  void setHtml(String html) => _setHtml?.call(html);
  void execCommand(String command, [String? value]) =>
      _execCommand?.call(command, value);
  void replaceAll(String findText, String replaceText) =>
      _replaceAll?.call(findText, replaceText);
  void focus() => _focus?.call();
}

class RichEditorSurface extends StatefulWidget {
  const RichEditorSurface({
    super.key,
    required this.controller,
    required this.initialHtml,
    required this.onChanged,
    required this.fontFamily,
    required this.fontSize,
    required this.lineSpacing,
  });

  final RichEditorController controller;
  final String initialHtml;
  final RichEditorChanged onChanged;
  final String fontFamily;
  final double fontSize;
  final double lineSpacing;

  @override
  State<RichEditorSurface> createState() => _RichEditorSurfaceState();
}

class _RichEditorSurfaceState extends State<RichEditorSurface> {
  static int _nextId = 0;
  static const String _blockSelector = 'p, div, li, blockquote, h1, h2, h3';

  late final String _viewType;
  late final html.DivElement _container;
  late final html.DivElement _editor;
  late String _documentFontFamily;
  late double _documentFontSize;
  late double _documentLineSpacing;
  html.Range? _savedSelectionRange;
  bool _hasPendingContentSync = false;
  StreamSubscription<html.Event>? _inputSubscription;
  StreamSubscription<html.Event>? _selectionChangeSubscription;
  StreamSubscription<html.KeyboardEvent>? _keyDownSubscription;
  StreamSubscription<html.Event>? _mouseUpSubscription;
  StreamSubscription<html.Event>? _clickSubscription;
  StreamSubscription<html.KeyboardEvent>? _keyUpSubscription;

  @override
  void initState() {
    super.initState();
    _viewType = 'generated-rich-editor-${_nextId++}';
    _documentFontFamily = widget.fontFamily;
    _documentFontSize = widget.fontSize;
    _documentLineSpacing = widget.lineSpacing;
    _container = html.DivElement()
      ..tabIndex = -1
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflowY = 'auto'
      ..style.overflowX = 'hidden'
      ..style.backgroundColor = 'transparent';
    _container.style.setProperty('scrollbar-gutter', 'stable');
    _container.style.setProperty('-webkit-overflow-scrolling', 'touch');
    _container.style.setProperty('overscroll-behavior', 'contain');
    _container.style.touchAction = 'pan-y';
    _editor = html.DivElement()
      ..contentEditable = 'true'
      ..tabIndex = 0
      ..spellcheck = true
      ..style.width = '100%'
      ..style.minHeight = '100%'
      ..style.outline = 'none'
      ..style.whiteSpace = 'pre-wrap'
      ..style.overflowWrap = 'break-word'
      ..style.boxSizing = 'border-box'
      ..style.paddingLeft = '24px'
      ..style.paddingRight = '44px'
      ..style.paddingTop = '24px'
      ..style.paddingBottom = '140px'
      ..style.color = '#111827';
    _editor.style.touchAction = 'pan-y';
    _container.children.add(_editor);
    _applyEditorSurfaceStyle();

    _setHtml(widget.initialHtml);

    _inputSubscription = _editor.onInput.listen((_) => _notifyChanged());
    _selectionChangeSubscription =
        html.document.onSelectionChange.listen((_) => _captureSelection());
    _editor.onMouseDown.listen((_) => _focusEditor());
    _clickSubscription = _editor.onClick.listen((_) => _focusEditor());
    _mouseUpSubscription = _editor.onMouseUp.listen((_) => _captureSelection());
    _keyUpSubscription = _editor.onKeyUp.listen((_) => _captureSelection());
    _keyDownSubscription = _editor.onKeyDown.listen((event) {
      if (event.key == 'Tab') {
        event.preventDefault();
        event.stopPropagation();
        _execCommand('insertHTML', '&nbsp;&nbsp;&nbsp;&nbsp;');
        return;
      }
      // Allow the browser to handle regular space input so users can type
      // normally between words. Intercepting space here caused issues
      // with contentEditable text entry.
    });

    ui.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _container);

    widget.controller._getHtml = () async => _editor.innerHtml ?? '';
    widget.controller._getPlainText = () => _editor.text ?? '';
    widget.controller._setHtml = _setHtml;
    widget.controller._execCommand = _execCommand;
    widget.controller._replaceAll = _replaceAll;
    widget.controller._focus = _focusEditor;
  }

  @override
  void didUpdateWidget(covariant RichEditorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontFamily != widget.fontFamily ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineSpacing != widget.lineSpacing) {
      _documentFontFamily = widget.fontFamily;
      _documentFontSize = widget.fontSize;
      _documentLineSpacing = widget.lineSpacing;
      _applyEditorSurfaceStyle();
      _applyFontFamilyToEditor(_documentFontFamily);
      _applyDocumentStyles();
      _scheduleContentSync();
    }
    if (oldWidget.initialHtml != widget.initialHtml &&
        widget.initialHtml != (_editor.innerHtml ?? '')) {
      _setHtml(widget.initialHtml);
    }
  }

  @override
  void dispose() {
    _inputSubscription?.cancel();
    _selectionChangeSubscription?.cancel();
    _keyDownSubscription?.cancel();
    _mouseUpSubscription?.cancel();
    _clickSubscription?.cancel();
    _keyUpSubscription?.cancel();
    super.dispose();
  }

  void _setHtml(String htmlContent) {
    _editor.setInnerHtml(
      htmlContent.isEmpty ? '<p></p>' : htmlContent,
      treeSanitizer: html.NodeTreeSanitizer.trusted,
    );
    _normalizeRootNodes();
    _applyDocumentStyles();
    _scheduleContentSync();
  }

  void _scheduleContentSync() {
    if (_hasPendingContentSync) return;
    _hasPendingContentSync = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hasPendingContentSync = false;
      if (!mounted) return;
      widget.onChanged(_editor.innerHtml ?? '', _editor.text ?? '');
    });
  }

  void _focusEditor() {
    final active = html.document.activeElement;
    if (active is html.Element &&
        !identical(active, _editor) &&
        !_editor.contains(active)) {
      active.blur();
    }
    _container.focus();
    _editor.focus();
    Timer.run(() => _editor.focus());
  }

  void _execCommand(String command, [String? value]) {
    _restoreSelection();
    _editor.focus();
    if (_shouldRequireSelection(command) && !_hasExpandedSelection()) {
      if (command == 'fontName') {
        _applyFontFamilyToEditor(value ?? _documentFontFamily);
        _normalizeRootNodes();
        _applyDocumentStyles();
        _notifyChanged();
      }
      return;
    }

    if (command == 'fontSizePx') {
      if (!_wrapSelectionWithInlineStyle({'font-size': value ?? '14pt'}))
        return;
    } else if (command == 'fontName') {
      final fontFamily = value ?? 'Times New Roman';
      if (!_wrapSelectionWithInlineStyle({'font-family': fontFamily})) {
        _applyFontFamilyToEditor(fontFamily);
        return;
      }
    } else if (command == 'lineHeight') {
      if (!_applyBlockStyleToSelection((element) {
        element.style.lineHeight = value ?? '1.35';
      }, applyToAllWhenWholeDocumentSelected: true)) {
        return;
      }
    } else if (_isAlignmentCommand(command)) {
      if (!_applyAlignmentToSelection(command)) return;
    } else {
      html.document.execCommand(command, false, value);
    }
    _normalizeRootNodes();
    _applyDocumentStyles();
    _notifyChanged();
  }

  void _replaceAll(String findText, String replaceText) {
    if (findText.isEmpty) return;
    final escaped = RegExp.escape(findText);
    final updated = (_editor.innerHtml ?? '')
        .replaceAll(RegExp(escaped, caseSensitive: false), replaceText);
    _setHtml(updated);
    _notifyChanged();
  }

  void _notifyChanged() {
    _captureSelection();
    widget.onChanged(_editor.innerHtml ?? '', _editor.text ?? '');
  }

  void _insertTextAtCaret(String text) {
    final range = _getEditorRange(allowCollapsed: true);
    if (range == null) return;
    range.deleteContents();
    final node = html.Text(text);
    range.insertNode(node);

    final selection = _getSelection();
    if (selection == null) return;
    final nextRange = html.document.createRange();
    nextRange.setStartAfter(node);
    nextRange.collapse(true);
    selection
      ..removeAllRanges()
      ..addRange(nextRange);
    _savedSelectionRange = nextRange.cloneRange();
    _normalizeRootNodes();
    _applyDocumentStyles();
    _notifyChanged();
  }

  double get _displayLineHeight {
    return _documentLineSpacing;
  }

  void _applyEditorSurfaceStyle() {
    _editor.style.fontFamily = _documentFontFamily;
    _editor.style.fontSize = '${_documentFontSize}pt';
    _editor.style.lineHeight = '$_displayLineHeight';
  }

  void _applyFontFamilyToEditor(String fontFamily) {
    _documentFontFamily = fontFamily;
    _editor.style.fontFamily = fontFamily;

    for (final element in _editor.querySelectorAll('*')) {
      if (element is! html.Element) continue;
      element.style.fontFamily = fontFamily;
      if (element.tagName.toLowerCase() == 'font') {
        element.setAttribute('face', fontFamily);
      }
    }
  }

  void _normalizeRootNodes() {
    final originalNodes = List<html.Node>.from(_editor.nodes);
    if (originalNodes.isEmpty) return;

    final rebuiltNodes = <html.Node>[];
    final bufferedInlineNodes = <html.Node>[];
    var changed = false;

    void flushInlineNodes() {
      if (bufferedInlineNodes.isEmpty) return;
      final paragraph = html.ParagraphElement();
      for (final node in bufferedInlineNodes) {
        paragraph.append(node);
      }
      rebuiltNodes.add(paragraph);
      bufferedInlineNodes.clear();
      changed = true;
    }

    for (final node in originalNodes) {
      if (_isIgnorableWhitespace(node)) {
        changed = true;
        continue;
      }
      if (_isBlockNode(node)) {
        flushInlineNodes();
        rebuiltNodes.add(node);
      } else {
        bufferedInlineNodes.add(node);
      }
    }
    flushInlineNodes();

    if (!changed) return;

    while (_editor.firstChild != null) {
      _editor.firstChild!.remove();
    }
    for (final node in rebuiltNodes) {
      _editor.append(node);
    }
  }

  bool _isIgnorableWhitespace(html.Node node) {
    if (node.nodeType != html.Node.TEXT_NODE) return false;
    final text = node.text ?? '';
    if (text.contains('\u00A0')) return false;
    return text.trim().isEmpty;
  }

  bool _isBlockNode(html.Node node) {
    if (node is! html.Element) return false;
    final tag = node.tagName.toLowerCase();
    return <String>{
      'p',
      'div',
      'h1',
      'h2',
      'h3',
      'blockquote',
      'ul',
      'ol',
      'li',
      'table',
      'hr',
    }.contains(tag);
  }

  bool _isAlignmentCommand(String command) {
    return command == 'justifyLeft' ||
        command == 'justifyCenter' ||
        command == 'justifyRight' ||
        command == 'justifyFull';
  }

  bool _shouldRequireSelection(String command) {
    return command == 'bold' ||
        command == 'italic' ||
        command == 'underline' ||
        command == 'strikeThrough' ||
        command == 'insertUnorderedList' ||
        command == 'insertOrderedList' ||
        command == 'justifyLeft' ||
        command == 'justifyCenter' ||
        command == 'justifyRight' ||
        command == 'justifyFull' ||
        command == 'indent' ||
        command == 'outdent' ||
        command == 'formatBlock' ||
        command == 'removeFormat' ||
        command == 'fontName' ||
        command == 'fontSizePx';
  }

  html.Selection? _getSelection() => html.window.getSelection();

  void _captureSelection() {
    final selection = _getSelection();
    if (selection == null || selection.rangeCount == 0) return;
    final range = selection.getRangeAt(0);
    if (!_isNodeInsideEditor(range.startContainer) ||
        !_isNodeInsideEditor(range.endContainer)) {
      return;
    }
    _savedSelectionRange = range.cloneRange();
  }

  void _restoreSelection() {
    final savedRange = _savedSelectionRange;
    final selection = _getSelection();
    if (savedRange == null || selection == null) return;
    if ((selection.rangeCount ?? 0) > 0) {
      final currentRange = selection.getRangeAt(0);
      if (_isNodeInsideEditor(currentRange.startContainer) &&
          _isNodeInsideEditor(currentRange.endContainer) &&
          currentRange.collapsed != true) {
        return;
      }
    }
    selection
      ..removeAllRanges()
      ..addRange(savedRange);
  }

  bool _isNodeInsideEditor(html.Node? node) {
    if (node == null) return false;
    if (identical(node, _editor)) return true;
    final parent = node is html.Element ? node : node.parent;
    return parent != null && _editor.contains(parent);
  }

  html.Range? _getSelectedRange() {
    final selection = _getSelection();
    html.Range? range;
    if (selection != null && (selection.rangeCount ?? 0) > 0) {
      final currentRange = selection.getRangeAt(0);
      if (_isNodeInsideEditor(currentRange.startContainer) &&
          _isNodeInsideEditor(currentRange.endContainer)) {
        range = currentRange;
      }
    }
    range ??= _savedSelectionRange;
    if (range == null || range.collapsed == true) return null;
    if (!_isNodeInsideEditor(range.startContainer) ||
        !_isNodeInsideEditor(range.endContainer)) {
      return null;
    }
    return range;
  }

  html.Range? _getEditorRange({bool allowCollapsed = false}) {
    final selection = _getSelection();
    html.Range? range;
    if (selection != null && (selection.rangeCount ?? 0) > 0) {
      final currentRange = selection.getRangeAt(0);
      if (_isNodeInsideEditor(currentRange.startContainer) &&
          _isNodeInsideEditor(currentRange.endContainer)) {
        range = currentRange;
      }
    }
    range ??= _savedSelectionRange;
    if (range == null) return null;
    if (!allowCollapsed && range.collapsed == true) return null;
    if (!_isNodeInsideEditor(range.startContainer) ||
        !_isNodeInsideEditor(range.endContainer)) {
      return null;
    }
    return range;
  }

  bool _hasExpandedSelection() => _getSelectedRange() != null;

  void _selectNodeContents(html.Node node) {
    final selection = _getSelection();
    if (selection == null) return;
    final range = html.document.createRange();
    range.selectNodeContents(node);
    selection
      ..removeAllRanges()
      ..addRange(range);
    _savedSelectionRange = range.cloneRange();
  }

  bool _wrapSelectionWithInlineStyle(Map<String, String> styles) {
    final range = _getSelectedRange();
    if (range == null) return false;

    final wrapper = html.SpanElement();
    styles.forEach((key, value) {
      wrapper.style.setProperty(key, value);
    });

    final fragment = range.extractContents();
    if ((fragment.text ?? '').isEmpty && fragment.nodes.isEmpty) {
      return false;
    }
    wrapper.append(fragment);
    range.insertNode(wrapper);
    _selectNodeContents(wrapper);
    return true;
  }

  bool _wrapSelectionWithBlockStyle(Map<String, String> styles) {
    final range = _getSelectedRange();
    if (range == null) return false;

    final wrapper = html.DivElement();
    styles.forEach((key, value) {
      wrapper.style.setProperty(key, value);
    });

    final fragment = range.extractContents();
    if ((fragment.text ?? '').isEmpty && fragment.nodes.isEmpty) {
      return false;
    }

    wrapper.append(fragment);
    range.insertNode(wrapper);
    _selectNodeContents(wrapper);
    return true;
  }

  bool _rangeIntersectsElement(html.Range range, html.Element element) {
    final elementRange = html.document.createRange();
    elementRange.selectNodeContents(element);

    final startsBeforeElementEnds =
        range.compareBoundaryPoints(html.Range.START_TO_END, elementRange) < 0;
    final endsAfterElementStarts =
        range.compareBoundaryPoints(html.Range.END_TO_START, elementRange) > 0;

    return startsBeforeElementEnds && endsAfterElementStarts;
  }

  List<html.Element> _selectedBlocks(html.Range range) {
    final blocks = <html.Element>[];
    for (final element in _editor.querySelectorAll(_blockSelector)) {
      if (element is! html.Element) continue;
      if (_rangeIntersectsElement(range, element)) {
        blocks.add(element);
      }
    }
    return blocks;
  }

  String _normalizeSelectionText(String? value) {
    return (value ?? '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isWholeDocumentSelection(html.Range range) {
    final selectedText = _normalizeSelectionText(range.toString());
    final editorText = _normalizeSelectionText(_editor.text);
    return selectedText.isNotEmpty && selectedText == editorText;
  }

  html.Element? _findClosestBlock(html.Node? node) {
    html.Node? current = node;
    while (current != null) {
      if (current is html.Element && _isBlockNode(current)) {
        return current;
      }
      if (identical(current, _editor)) {
        break;
      }
      current = current.parent;
    }
    return null;
  }

  bool _applyBlockStyleToSelection(
      void Function(html.Element element) styleBlock,
      {bool applyToAllWhenWholeDocumentSelected = false}) {
    final range = _getEditorRange(allowCollapsed: true);
    if (range == null) return false;
    if (applyToAllWhenWholeDocumentSelected && _isWholeDocumentSelection(range)) {
      var applied = false;
      for (final element in _editor.querySelectorAll(_blockSelector)) {
        if (element is! html.Element) continue;
        styleBlock(element);
        applied = true;
      }
      return applied;
    }
    final blocks = _selectedBlocks(range);
    if (blocks.isEmpty) {
      final activeBlock = _findClosestBlock(range.startContainer);
      if (activeBlock == null) return false;
      styleBlock(activeBlock);
      return true;
    }
    for (final block in blocks) {
      styleBlock(block);
    }
    return true;
  }

  bool _applyAlignmentToSelection(String command) {
    final align = switch (command) {
      'justifyCenter' => 'center',
      'justifyRight' => 'right',
      'justifyFull' => 'justify',
      _ => 'left',
    };

    return _wrapSelectionWithBlockStyle({
      'text-align': align,
      'width': '100%',
      'max-width': '100%',
      'margin': '0 0 0.85em',
    });
  }

  String? _getExplicitTextAlign(html.Element element) {
    final styleAlign = element.style.textAlign.trim().toLowerCase();
    if (styleAlign.isNotEmpty) return styleAlign;

    final alignAttr =
        (element.getAttribute('align') ?? '').trim().toLowerCase();
    if (alignAttr.isNotEmpty) return alignAttr;

    final inlineStyle = element.getAttribute('style') ?? '';
    final match = RegExp(r'text-align\s*:\s*(left|right|center|justify)',
            caseSensitive: false)
        .firstMatch(inlineStyle);
    return match?.group(1)?.toLowerCase();
  }

  String? _findNearestTextAlign(html.Element element) {
    html.Element? current = element;
    while (current != null) {
      final align = _getExplicitTextAlign(current);
      if (align != null && align.isNotEmpty) return align;
      current = current.parent;
      if (current == _editor) break;
    }
    return null;
  }

  void _applyDocumentStyles() {
    final readableLineHeight = '$_displayLineHeight';

    for (final element in _editor.querySelectorAll(_blockSelector)) {
      if (element is! html.Element) continue;
      final inlineStyle = (element.getAttribute('style') ?? '').toLowerCase();
      final hasCustomFontFamily = inlineStyle.contains('font-family:');
      final hasCustomLineHeight = inlineStyle.contains('line-height:');
      final hasCustomMargin = inlineStyle.contains('margin:') ||
          inlineStyle.contains('margin-top:') ||
          inlineStyle.contains('margin-left:') ||
          inlineStyle.contains('margin-right:') ||
          inlineStyle.contains('margin-bottom:');
      if (!hasCustomFontFamily) {
        element.style.fontFamily = _documentFontFamily;
      }
      if (!hasCustomLineHeight) {
        element.style.lineHeight = readableLineHeight;
      }

      final tag = element.tagName.toLowerCase();
      if (tag == 'h1') {
        if (!hasCustomMargin) {
          element.style.margin = '0 0 0.9em';
        }
        element.style.fontSize = '${(_documentFontSize + 10).round()}pt';
        element.style.fontWeight = '700';
      } else if (tag == 'h2') {
        if (!hasCustomMargin) {
          element.style.margin = '0 0 0.8em';
        }
        element.style.fontSize = '${(_documentFontSize + 6).round()}pt';
        element.style.fontWeight = '700';
      } else if (tag == 'h3') {
        if (!hasCustomMargin) {
          element.style.margin = '0 0 0.75em';
        }
        element.style.fontSize = '${(_documentFontSize + 3).round()}pt';
        element.style.fontWeight = '700';
      } else if (tag == 'li') {
        if (!hasCustomMargin) {
          element.style.margin = '0 0 0.35em';
        }
      } else {
        if (!hasCustomMargin) {
          element.style.margin = '0 0 0.85em';
        }
      }

      if (tag == 'p' && (element.innerHtml ?? '').trim().isEmpty) {
        element.style.minHeight = '${_documentFontSize}pt';
      }

      final resolvedAlign = _findNearestTextAlign(element);
      if (resolvedAlign != null && resolvedAlign.isNotEmpty) {
        element.style.textAlign = resolvedAlign;
      } else {
        element.style.textAlign = 'left';
      }
    }

    for (final element
        in _editor.querySelectorAll('span, strong, em, u, b, i, font')) {
      if (element is! html.Element) continue;
      final inlineStyle = (element.getAttribute('style') ?? '').toLowerCase();
      if (!inlineStyle.contains('font-family:')) {
        element.style.fontFamily = _documentFontFamily;
      }
      element.style.lineHeight = 'inherit';
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

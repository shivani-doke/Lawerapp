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
  static const double _minimumReadableLineHeight = 1.35;

  late final String _viewType;
  late final html.DivElement _container;
  late final html.DivElement _editor;
  StreamSubscription<html.Event>? _inputSubscription;
  StreamSubscription<html.KeyboardEvent>? _keyDownSubscription;

  @override
  void initState() {
    super.initState();
    _viewType = 'generated-rich-editor-${_nextId++}';
    _container = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflowY = 'auto'
      ..style.overflowX = 'hidden'
      ..style.backgroundColor = 'transparent';
    _editor = html.DivElement()
      ..contentEditable = 'true'
      ..spellcheck = true
      ..style.width = '100%'
      ..style.minHeight = '100%'
      ..style.outline = 'none'
      ..style.whiteSpace = 'pre-wrap'
      ..style.overflowWrap = 'break-word'
      ..style.paddingBottom = '48px'
      ..style.color = '#111827';
    _container.children.add(_editor);
    _applyEditorSurfaceStyle();

    _setHtml(widget.initialHtml);

    _inputSubscription = _editor.onInput.listen((_) => _notifyChanged());
    _keyDownSubscription = _editor.onKeyDown.listen((event) {
      if (event.key == 'Tab') {
        event.preventDefault();
        _execCommand('insertHTML', '&nbsp;&nbsp;&nbsp;&nbsp;');
      }
    });

    ui.platformViewRegistry.registerViewFactory(_viewType, (int _) => _container);

    widget.controller._getHtml = () async => _editor.innerHtml ?? '';
    widget.controller._getPlainText = () => _editor.text ?? '';
    widget.controller._setHtml = _setHtml;
    widget.controller._execCommand = _execCommand;
    widget.controller._replaceAll = _replaceAll;
    widget.controller._focus = () => _editor.focus();
  }

  @override
  void didUpdateWidget(covariant RichEditorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHtml != widget.initialHtml &&
        widget.initialHtml != (_editor.innerHtml ?? '')) {
      _setHtml(widget.initialHtml);
    }
    if (oldWidget.fontFamily != widget.fontFamily) {
      _applyEditorSurfaceStyle();
      _applyDocumentStyles();
    }
    if (oldWidget.fontSize != widget.fontSize) {
      _applyEditorSurfaceStyle();
      _applyDocumentStyles();
    }
    if (oldWidget.lineSpacing != widget.lineSpacing) {
      _applyEditorSurfaceStyle();
      _applyDocumentStyles();
    }
  }

  @override
  void dispose() {
    _inputSubscription?.cancel();
    _keyDownSubscription?.cancel();
    super.dispose();
  }

  void _setHtml(String htmlContent) {
    _editor.setInnerHtml(
      htmlContent.isEmpty ? '<p></p>' : htmlContent,
      treeSanitizer: html.NodeTreeSanitizer.trusted,
    );
    _normalizeRootNodes();
    _applyDocumentStyles();
  }

  void _execCommand(String command, [String? value]) {
    _editor.focus();
    html.document.execCommand(command, false, value);
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
    widget.onChanged(_editor.innerHtml ?? '', _editor.text ?? '');
  }

  double get _displayLineHeight {
    return widget.lineSpacing < _minimumReadableLineHeight
        ? _minimumReadableLineHeight
        : widget.lineSpacing;
  }

  void _applyEditorSurfaceStyle() {
    _editor.style.fontFamily = widget.fontFamily;
    _editor.style.fontSize = '${widget.fontSize}px';
    _editor.style.lineHeight = '$_displayLineHeight';
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
    return node.nodeType == html.Node.TEXT_NODE &&
        (node.text?.trim().isEmpty ?? true);
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

  void _applyDocumentStyles() {
    final readableLineHeight = '$_displayLineHeight';
    final blockSelector = 'p, div, li, blockquote, h1, h2, h3';

    for (final element in _editor.querySelectorAll(blockSelector)) {
      if (element is! html.Element) continue;
      element.style.lineHeight = readableLineHeight;

      final tag = element.tagName.toLowerCase();
      if (tag == 'h1') {
        element.style.margin = '0 0 0.9em';
        element.style.fontSize = '${(widget.fontSize + 10).round()}px';
        element.style.fontWeight = '700';
      } else if (tag == 'h2') {
        element.style.margin = '0 0 0.8em';
        element.style.fontSize = '${(widget.fontSize + 6).round()}px';
        element.style.fontWeight = '700';
      } else if (tag == 'h3') {
        element.style.margin = '0 0 0.75em';
        element.style.fontSize = '${(widget.fontSize + 3).round()}px';
        element.style.fontWeight = '700';
      } else if (tag == 'li') {
        element.style.margin = '0 0 0.35em';
      } else {
        element.style.margin = '0 0 0.85em';
      }

      if (tag == 'p' && (element.innerHtml ?? '').trim().isEmpty) {
        element.style.minHeight = '${widget.fontSize}px';
      }
    }

    for (final element in _editor.querySelectorAll('span, strong, em, u, b, i, font')) {
      if (element is! html.Element) continue;
      element.style.lineHeight = 'inherit';
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

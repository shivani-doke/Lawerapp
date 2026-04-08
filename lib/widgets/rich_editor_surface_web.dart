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
      ..style.overflowWrap = 'anywhere'
      ..style.paddingBottom = '48px'
      ..style.fontFamily = widget.fontFamily
      ..style.fontSize = '${widget.fontSize}px'
      ..style.lineHeight = '${widget.lineSpacing}'
      ..style.color = '#111827';
    _container.children.add(_editor);

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
      _editor.style.fontFamily = widget.fontFamily;
    }
    if (oldWidget.fontSize != widget.fontSize) {
      _editor.style.fontSize = '${widget.fontSize}px';
    }
    if (oldWidget.lineSpacing != widget.lineSpacing) {
      _editor.style.lineHeight = '${widget.lineSpacing}';
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

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

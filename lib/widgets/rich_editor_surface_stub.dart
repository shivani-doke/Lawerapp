import 'package:flutter/material.dart';

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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _stripHtml(widget.initialHtml));
    _controller.addListener(_notifyChanged);
    widget.controller._getHtml = () async => _controller.text;
    widget.controller._getPlainText = () => _controller.text;
    widget.controller._setHtml = (html) {
      final text = _stripHtml(html);
      if (_controller.text != text) {
        _controller.text = text;
      }
    };
    widget.controller._replaceAll = (findText, replaceText) {
      _controller.text = _controller.text.replaceAll(findText, replaceText);
    };
    widget.controller._focus = () {};
  }

  @override
  void didUpdateWidget(covariant RichEditorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHtml != widget.initialHtml) {
      final text = _stripHtml(widget.initialHtml);
      if (_controller.text != text) {
        _controller.text = text;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged(_controller.text, _controller.text);
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), '');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: null,
      minLines: 35,
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Start editing the generated document...',
      ),
      style: TextStyle(
        fontSize: widget.fontSize,
        fontFamily: widget.fontFamily,
        height: widget.lineSpacing,
        color: const Color(0xff111827),
      ),
      textAlignVertical: TextAlignVertical.top,
    );
  }
}

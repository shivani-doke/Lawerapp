import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'widgets/rich_editor_surface.dart';

class SmartLegalEditorPage extends StatefulWidget {
  const SmartLegalEditorPage({super.key});

  @override
  State<SmartLegalEditorPage> createState() => _SmartLegalEditorPageState();
}

class _SmartLegalEditorPageState extends State<SmartLegalEditorPage> {
  static const double _compactBreakpoint = 720;
  static const double _desktopCanvasWidth = 824;
  static const double _desktopCanvasHeight = 860;
  static const double _desktopCanvasMinHeight = 980;
  static const _fontSizes = <double>[
    8,
    9,
    10,
    11,
    12,
    14,
    16,
    18,
    20,
    22,
    24,
    26,
    28,
    32,
    36,
    40,
    48,
    56,
    64,
    72,
  ];
  static const _fontFamilies = <String>[
    'Times New Roman',
    'Arial',
    'Calibri',
    'Cambria',
    'Book Antiqua',
    'Bookman Old Style',
    'Candara',
    'Century Gothic',
    'Comic Sans MS',
    'Consolas',
    'Constantia',
    'Corbel',
    'Courier New',
    'Georgia',
    'Garamond',
    'Lucida Console',
    'Lucida Sans Unicode',
    'Palatino Linotype',
    'Segoe UI',
    'Sylfaen',
    'Trebuchet MS',
    'Verdana',
    'Tahoma',
    'Nirmala UI',
    'Mangal',
    'Aparajita',
    'Kokila',
    'Utsaah',
  ];
  static const _lineSpacingOptions = <MapEntry<String, double>>[
    MapEntry('Single', 1.0),
    MapEntry('1.15', 1.15),
    MapEntry('1.5', 1.5),
    MapEntry('Double', 2.0),
  ];

  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  final _editorController = RichEditorController();
  final _fontSizeFocusNode = FocusNode();
  final _fontFamilyFocusNode = FocusNode();
  final _lineSpacingFocusNode = FocusNode();
  final _pageHtml = <String>['<p></p>'];
  final _pagePlainText = <String>[''];
  final _pageSizes = <Size>[const Size(595, 842)];

  String _flowState = 'idle';
  String? _documentId;
  String? _errorMessage;
  int _currentPage = 0;
  double _fontSize = 14;
  double _margin = 24;
  double _lineSpacing = 1.0;
  String _fontFamily = 'Times New Roman';
  bool _isFindReplaceOpen = false;
  bool _isUploading = false;
  bool _isGeneratingPdf = false;

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    _fontSizeFocusNode.dispose();
    _fontFamilyFocusNode.dispose();
    _lineSpacingFocusNode.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = message.toLowerCase();
    if (lower.contains('failed to fetch') ||
        lower.contains('clientexception') ||
        lower.contains('unable to connect') ||
        lower.contains('connection refused')) {
      return 'Edit Document service is unavailable. Please make sure the backend is running and try again.';
    }
    return message;
  }

  List<String> _buildDraftPages(Map<String, dynamic> draft) {
    final html = (draft['html'] ?? '').toString();
    final plainText = (draft['content'] ?? '').toString();
    return _buildInitialPages(html, plainText);
  }

  List<Size> _buildDraftPageSizes(Map<String, dynamic> draft) {
    return [const Size(595, 842)];
  }

  List<String> _buildInitialPages(String html, String plainText) {
    final trimmedHtml = _extractBodyHtml(html).trim();
    if (trimmedHtml.isNotEmpty) return <String>[trimmedHtml];
    final normalized = _normalizeExtractedPlainText(
      plainText.replaceAll('\r\n', '\n').trimRight(),
    );
    return _paginatePlainText(normalized).map(_htmlFromPlainText).toList();
  }

  String _extractBodyHtml(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(
      r'<body[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match != null) {
      return match.group(1)?.trim() ?? '';
    }
    return trimmed;
  }

  bool _looksLikeHeadingLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length <= 40 &&
        RegExp(r"""^[A-Z0-9 .,:;()"']+$""").hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  bool _isListItemLine(String line) {
    final trimmed = line.trimLeft();
    return RegExp(
      r'^(\d+|[A-Za-z]|[IVXLC]+)[\.\)]\s+',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  bool _looksLikeStandaloneLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return true;
    return _looksLikeHeadingLine(trimmed) || _isListItemLine(trimmed);
  }

  bool _shouldJoinLines(String current, String next) {
    final trimmedCurrent = current.trimRight();
    final trimmedNext = next.trimLeft();
    if (trimmedCurrent.isEmpty || trimmedNext.isEmpty) return false;
    if (_looksLikeHeadingLine(trimmedCurrent) ||
        _looksLikeHeadingLine(trimmedNext)) {
      return false;
    }
    if (_isListItemLine(trimmedNext)) return false;
    if (trimmedCurrent.endsWith('-')) return true;
    if (RegExp(r'[.!?;:]$').hasMatch(trimmedCurrent)) return false;
    return true;
  }

  String _normalizeExtractedPlainText(String content) {
    if (content.trim().isEmpty) return '';
    final rawBlocks = content.split(RegExp(r'\n\s*\n'));
    final normalizedBlocks = <String>[];

    for (final block in rawBlocks) {
      final lines = block
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      final buffer = StringBuffer(lines.first);
      for (final line in lines.skip(1)) {
        final current = buffer.toString();
        if (_shouldJoinLines(current, line)) {
          if (current.endsWith('-')) {
            final joined = current.substring(0, current.length - 1) + line;
            buffer
              ..clear()
              ..write(joined);
          } else {
            buffer.write(' $line');
          }
        } else {
          normalizedBlocks.add(buffer.toString().trim());
          buffer
            ..clear()
            ..write(line);
        }
      }
      final finalBlock = buffer.toString().trim();
      if (finalBlock.isNotEmpty) {
        normalizedBlocks.add(finalBlock);
      }
    }

    return normalizedBlocks.join('\n\n');
  }

  List<String> _buildPlainTextPages(
      List<String> htmlPages, String fallbackText) {
    final converted = htmlPages.map(_plainTextFromHtml).toList();
    if (converted.every((page) => page.trim().isEmpty) &&
        fallbackText.trim().isNotEmpty) {
      return _paginatePlainText(fallbackText);
    }
    return converted;
  }

  List<String> _paginatePlainText(String content) {
    if (content.trim().isEmpty) return <String>[''];
    final paragraphs = content.split(RegExp(r'\n\s*\n'));
    final pages = <String>[];
    final buffer = StringBuffer();
    for (final rawParagraph in paragraphs) {
      final paragraph = rawParagraph.trim();
      if (paragraph.isEmpty) continue;
      final nextValue =
          buffer.isEmpty ? paragraph : '${buffer.toString()}\n\n$paragraph';
      if (nextValue.length > 1800 && buffer.isNotEmpty) {
        pages.add(buffer.toString());
        buffer
          ..clear()
          ..write(paragraph);
      } else {
        if (buffer.isNotEmpty) buffer.write('\n\n');
        buffer.write(paragraph);
      }
    }
    if (buffer.isNotEmpty) pages.add(buffer.toString());
    return pages.isEmpty ? <String>[''] : pages;
  }

  String _htmlFromPlainText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '<p></p>';
    final escaped = trimmed
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return escaped.split(RegExp(r'\n\s*\n')).map((p) {
      final paragraph = p.trim();
      final content = paragraph.replaceAll('\n', '<br>');
      return '<p style="text-align:left;">$content</p>';
    }).join();
  }

  String _plainTextFromHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
            RegExp(r'</(p|div|h1|h2|h3|li|ul|ol|blockquote)>',
                caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<hr[^>]*>', caseSensitive: false),
            '\n----------------------------------------\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  void _updateCurrentPage(String html, String plainText) {
    if (_currentPage >= _pageHtml.length) return;
    _pageHtml[_currentPage] = html.isEmpty ? '<p></p>' : html;
    _pagePlainText[_currentPage] = plainText;
    if (mounted) setState(() {});
  }

  Future<void> _syncCurrentPage() async {
    _updateCurrentPage(
        await _editorController.getHtml(), _editorController.getPlainText());
  }

  Future<void> _pickAndUploadFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    final file =
        (picked == null || picked.files.isEmpty) ? null : picked.files.first;
    if (file == null) return;

    setState(() {
      _flowState = 'uploading';
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final upload = await ApiService().uploadSmartLegalDocument(file);
      final id = (upload['documentId'] ?? '').toString();
      if (id.isEmpty) throw Exception('Document id missing');
      setState(() {
        _documentId = id;
        _flowState = 'extracting';
      });

      final draft = await ApiService().getSmartLegalWordDraft(id);
      final plainText = (draft['content'] ?? '').toString();
      final htmlPages = _buildDraftPages(draft);
      final plainPages = _buildPlainTextPages(htmlPages, plainText);
      final pageSizes = _buildDraftPageSizes(draft);

      if (!mounted) return;
      setState(() {
        _pageHtml
          ..clear()
          ..addAll(htmlPages);
        _pagePlainText
          ..clear()
          ..addAll(plainPages);
        _pageSizes
          ..clear()
          ..addAll(pageSizes);
        _currentPage = 0;
        _fontFamily = 'Times New Roman';
        _fontSize = 14;
        _lineSpacing = 1.0;
        _flowState = 'done';
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _flowState = 'idle';
        _isUploading = false;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  void _resetFlow() {
    setState(() {
      _flowState = 'idle';
      _documentId = null;
      _errorMessage = null;
      _currentPage = 0;
      _fontSize = 14;
      _margin = 24;
      _lineSpacing = 1.0;
      _fontFamily = 'Times New Roman';
      _isFindReplaceOpen = false;
      _isUploading = false;
      _isGeneratingPdf = false;
      _pageHtml
        ..clear()
        ..add('<p></p>');
      _pagePlainText
        ..clear()
        ..add('');
      _pageSizes
        ..clear()
        ..add(const Size(595, 842));
      _findController.clear();
      _replaceController.clear();
    });
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _pageHtml.length) return;
    _syncCurrentPage().then((_) {
      if (!mounted) return;
      setState(() => _currentPage = index);
    });
  }

  void _addPage() {
    _syncCurrentPage().then((_) {
      if (!mounted) return;
      setState(() {
        _pageHtml.add('<p></p>');
        _pagePlainText.add('');
        _currentPage = _pageHtml.length - 1;
      });
    });
  }

  void _deletePage() {
    if (_pageHtml.length == 1) return;
    setState(() {
      _pageHtml.removeAt(_currentPage);
      _pagePlainText.removeAt(_currentPage);
      if (_currentPage >= _pageHtml.length) _currentPage = _pageHtml.length - 1;
    });
  }

  void _runCommand(String command, [String? value]) {
    _editorController.execCommand(command, value);
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 60), () {
        if (!mounted) return;
        _editorController.focus();
      });
    });
  }

  String _fontSizeCommandValue(double size) {
    if (size <= 8) return '1';
    if (size <= 10) return '2';
    if (size <= 12) return '3';
    if (size <= 14) return '4';
    if (size <= 18) return '5';
    if (size <= 24) return '6';
    return '7';
  }

  String get _lineSpacingLabel {
    for (final option in _lineSpacingOptions) {
      if (option.value == _lineSpacing) return option.key;
    }
    return _lineSpacingOptions.first.key;
  }

  int get _wordCount {
    final words = _pagePlainText.join('\n\n').trim();
    if (words.isEmpty) return 0;
    return words.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  int get _charCount => _pagePlainText.join('\n\n').length;

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _compactBreakpoint;

  double _pagePadding(BuildContext context) =>
      _isCompactLayout(context) ? 12 : 20;

  void _applyTemplate(String template) {
    switch (template) {
      case 'bold':
        _runCommand('bold');
        break;
      case 'italic':
        _runCommand('italic');
        break;
      case 'underline':
        _runCommand('underline');
        break;
      case 'strike':
        _runCommand('strikeThrough');
        break;
      case 'bullet':
        _runCommand('insertUnorderedList');
        break;
      case 'number':
        _runCommand('insertOrderedList');
        break;
      case 'left':
        _runCommand('justifyLeft');
        break;
      case 'center':
        _runCommand('justifyCenter');
        break;
      case 'right':
        _runCommand('justifyRight');
        break;
      case 'indent':
        _runCommand('indent');
        break;
      case 'outdent':
        _runCommand('outdent');
        break;
      case 'h1':
        _runCommand('formatBlock', '<h1>');
        break;
      case 'h2':
        _runCommand('formatBlock', '<h2>');
        break;
      case 'paragraph':
        _runCommand('formatBlock', '<p>');
        break;
      case 'rule':
        _runCommand('insertHTML',
            '<hr style="border:none;border-top:2px solid #cbd5e1;margin:12px 0;" />');
        break;
      case 'clear':
        _runCommand('removeFormat');
        break;
      case 'find':
        setState(() => _isFindReplaceOpen = !_isFindReplaceOpen);
        break;
    }
  }

  void _undoEdit() => _runCommand('undo');
  void _redoEdit() => _runCommand('redo');

  void _replaceAll() {
    final find = _findController.text;
    if (find.isEmpty) return;
    _editorController.replaceAll(find, _replaceController.text);
  }

  String _buildContinuousPdfHtml() {
    return _pageHtml
        .map((page) => _trimEmptyHtmlBlocks(page))
        .where((page) => page.isNotEmpty)
        .join('\n');
  }

  String _trimEmptyHtmlBlocks(String html) {
    var cleaned = html.trim();
    if (cleaned.isEmpty) return '';

    final emptyBlockPattern = RegExp(
      r'^(?:<(?:p|div)[^>]*>(?:\s|&nbsp;|<br\s*/?>)*</(?:p|div)>\s*)+',
      caseSensitive: false,
    );
    final trailingEmptyBlockPattern = RegExp(
      r'(?:\s*<(?:p|div)[^>]*>(?:\s|&nbsp;|<br\s*/?>)*</(?:p|div)>)+$',
      caseSensitive: false,
    );

    cleaned = cleaned.replaceFirst(emptyBlockPattern, '');
    cleaned = cleaned.replaceFirst(trailingEmptyBlockPattern, '');
    return cleaned.trim();
  }

  Future<void> _generatePdf() async {
    final documentId = _documentId;
    if (documentId == null || documentId.isEmpty) return;
    setState(() => _isGeneratingPdf = true);
    try {
      await _syncCurrentPage();
      final mergedHtml = _buildContinuousPdfHtml();

      final result = await ApiService().generateSmartLegalPdf(
        documentId,
        html: mergedHtml,
        fontFamily: _fontFamily,
        fontSize: _fontSize,
        lineSpacing: _lineSpacing,
      );
      final pdfFilename = (result['pdfFilename'] ?? '').toString();
      if (!mounted) return;
      if (pdfFilename.isNotEmpty) {
        await ApiService().downloadGeneratedDocument(pdfFilename);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Widget _buildUploadState() {
    final isCompact = _isCompactLayout(context);
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Center(
        child: Container(
          width: isCompact ? double.infinity : 560,
          margin: EdgeInsets.all(isCompact ? 16 : 24),
          padding: EdgeInsets.all(isCompact ? 20 : 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xffE2E8F0)),
            boxShadow: const [
              BoxShadow(
                  blurRadius: 18,
                  color: Color(0x120F172A),
                  offset: Offset(0, 8))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined,
                  size: 54, color: Color(0xff4F46E5)),
              const SizedBox(height: 18),
              Text(
                'Document Editor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isCompact ? 22 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Upload a PDF or image to extract text and start editing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xff64748B))),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadFile,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file_outlined),
                label: Text(_flowState == 'uploading'
                    ? 'Uploading...'
                    : _flowState == 'extracting'
                        ? 'Extracting text...'
                        : 'Upload Document'),
              ),
              if ((_errorMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isCompact}) {
    final titleBlock = Flex(
      direction: Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: const Color(0xffE0E7FF),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.description_outlined,
              color: Color(0xff4F46E5)),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Document Editor',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff0F172A))),
              SizedBox(height: 4),
              Text('Edit text and export as PDF.',
                  style: TextStyle(
                      color: Color(0xff64748B), fontSize: 12)),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16 : 24,
        18,
        isCompact ? 16 : 24,
        16,
      ),
      child: Flex(
        direction: isCompact ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment:
            isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (isCompact)
            titleBlock
          else
            Flexible(
              fit: FlexFit.loose,
              child: titleBlock,
            ),
          SizedBox(width: isCompact ? 0 : 8, height: isCompact ? 14 : 0),
          Flex(
            direction: isCompact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment:
                isCompact ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
            children: [
              OutlinedButton(
                  onPressed: _resetFlow, child: const Text('Upload Another')),
              SizedBox(width: isCompact ? 0 : 8, height: isCompact ? 10 : 0),
              FilledButton(
                onPressed: _isGeneratingPdf ? null : _generatePdf,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize:
                      isCompact ? const Size(double.infinity, 48) : null,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isGeneratingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Generate PDF',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: const Color(0xffF8FAFC),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _compactToolbarButton('B', () => _applyTemplate('bold'),
                    fontWeight: FontWeight.w700),
                _compactToolbarButton('I', () => _applyTemplate('italic'),
                    fontStyle: FontStyle.italic),
                _compactToolbarButton('U', () => _applyTemplate('underline'),
                    decoration: TextDecoration.underline),
                _compactToolbarButton('S', () => _applyTemplate('strike'),
                    decoration: TextDecoration.lineThrough),
                _toolbarDivider(),
                _labelToolbarButton(Icons.format_list_bulleted, 'List',
                    () => _applyTemplate('bullet')),
                _labelToolbarButton(Icons.format_list_numbered, '1. List',
                    () => _applyTemplate('number')),
                _toolbarDivider(),
                _labelToolbarButton(Icons.format_align_left, 'Left',
                    () => _applyTemplate('left')),
                _labelToolbarButton(Icons.format_align_center, 'Center',
                    () => _applyTemplate('center')),
                _labelToolbarButton(Icons.format_align_right, 'Right',
                    () => _applyTemplate('right')),
                _toolbarDivider(),
                _labelToolbarButton(Icons.format_indent_increase, 'Indent',
                    () => _applyTemplate('indent')),
                _labelToolbarButton(Icons.format_indent_decrease, 'Outdent',
                    () => _applyTemplate('outdent')),
                _toolbarDivider(),
                _labelToolbarButton(Icons.undo, 'Undo', _undoEdit),
                _labelToolbarButton(Icons.redo, 'Redo', _redoEdit),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: DropdownButtonFormField<double>(
                    focusNode: _fontSizeFocusNode,
                    value: _fontSizes.contains(_fontSize.roundToDouble())
                        ? _fontSize.roundToDouble()
                        : _fontSizes.first,
                    isExpanded: true,
                    iconSize: 18,
                    decoration: _toolbarDropdownDecoration(),
                    selectedItemBuilder: (context) => _fontSizes
                        .map((_) => const Align(
                            alignment: Alignment.centerLeft,
                            child:
                                Text('Size', overflow: TextOverflow.ellipsis)))
                        .toList(),
                    items: _fontSizes
                        .map((size) => DropdownMenuItem<double>(
                            value: size, child: Text(size.toInt().toString())))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _fontSize = value);
                      _fontSizeFocusNode.unfocus();
                      _runCommand('fontSize', _fontSizeCommandValue(value));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    focusNode: _fontFamilyFocusNode,
                    value: _fontFamilies.contains(_fontFamily)
                        ? _fontFamily
                        : _fontFamilies.first,
                    isExpanded: true,
                    iconSize: 18,
                    decoration: _toolbarDropdownDecoration(),
                    selectedItemBuilder: (context) => _fontFamilies
                        .map((_) => const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Font Family',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    items: _fontFamilies
                        .map((family) => DropdownMenuItem<String>(
                            value: family,
                            child:
                                Text(family, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _fontFamilyFocusNode.unfocus();
                      setState(() => _fontFamily = value);
                      _runCommand('fontName', value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: DropdownButtonFormField<String>(
                    focusNode: _lineSpacingFocusNode,
                    value: _lineSpacingLabel,
                    isExpanded: true,
                    iconSize: 18,
                    decoration: _toolbarDropdownDecoration(),
                    items: _lineSpacingOptions
                        .map((option) => DropdownMenuItem<String>(
                            value: option.key,
                            child: Text(option.key,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _lineSpacingFocusNode.unfocus();
                      final selected = _lineSpacingOptions.firstWhere(
                          (option) => option.key == value,
                          orElse: () => _lineSpacingOptions.first);
                      setState(() => _lineSpacing = selected.value);
                      _runCommand('lineHeight', selected.value.toString());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _compactToolbarButton('H1', () => _applyTemplate('h1')),
                _compactToolbarButton('H2', () => _applyTemplate('h2')),
                _compactToolbarButton('P', () => _applyTemplate('paragraph')),
                _toolbarDivider(),
                _labelToolbarButton(Icons.horizontal_rule, 'Rule',
                    () => _applyTemplate('rule')),
                _labelToolbarButton(
                    Icons.format_clear, 'Clear', () => _applyTemplate('clear')),
                _toolbarDivider(),
                _labelToolbarButton(Icons.find_replace, 'Find & Replace',
                    () => _applyTemplate('find'),
                    active: _isFindReplaceOpen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindReplaceBar({required bool isCompact}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xffEEF2FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffC7D2FE))),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                    controller: _findController,
                    decoration: const InputDecoration(
                        hintText: 'Find...',
                        filled: true,
                        fillColor: Colors.white)),
                const SizedBox(height: 10),
                TextField(
                    controller: _replaceController,
                    decoration: const InputDecoration(
                        hintText: 'Replace...',
                        filled: true,
                        fillColor: Colors.white)),
                const SizedBox(height: 10),
                FilledButton(
                    onPressed: _replaceAll, child: const Text('Replace All')),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                      onPressed: () => setState(() => _isFindReplaceOpen = false),
                      icon: const Icon(Icons.close)),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _findController,
                        decoration: const InputDecoration(
                            hintText: 'Find...',
                            filled: true,
                            fillColor: Colors.white))),
                const SizedBox(width: 12),
                const Text('->',
                    style: TextStyle(
                        color: Color(0xff64748B), fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        controller: _replaceController,
                        decoration: const InputDecoration(
                            hintText: 'Replace...',
                            filled: true,
                            fillColor: Colors.white))),
                const SizedBox(width: 12),
                FilledButton(
                    onPressed: _replaceAll, child: const Text('Replace All')),
                const SizedBox(width: 8),
                IconButton(
                    onPressed: () => setState(() => _isFindReplaceOpen = false),
                    icon: const Icon(Icons.close)),
              ],
            ),
    );
  }

  Widget _buildEditorCanvas({required bool isCompact}) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final availableCanvasWidth =
        screenWidth - (_pagePadding(context) * 2) - (isCompact ? 24 : 76);
    final canvasWidth = isCompact
        ? availableCanvasWidth.clamp(300.0, _desktopCanvasWidth).toDouble()
        : _desktopCanvasWidth;
    final canvasHeight = isCompact
        ? (canvasWidth * (_desktopCanvasHeight / _desktopCanvasWidth))
            .clamp(540.0, _desktopCanvasHeight)
            .toDouble()
        : _desktopCanvasHeight;
    final canvasMinHeight = isCompact
        ? (canvasWidth * (_desktopCanvasMinHeight / _desktopCanvasWidth))
            .clamp(620.0, _desktopCanvasMinHeight)
            .toDouble()
        : _desktopCanvasMinHeight;
    final editorHeight =
        isCompact ? canvasMinHeight : canvasHeight;
    final sidePadding = isCompact ? 12.0 : 18.0;

    return Container(
      color: const Color(0xffF1F5F9),
      padding: EdgeInsets.fromLTRB(sidePadding, 14, sidePadding, 10),
      child: Column(
        children: [
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                        onPressed: _currentPage == 0
                            ? null
                            : () => _goToPage(_currentPage - 1),
                        child: const Text('Prev')),
                    Text('Page ${_currentPage + 1} / ${_pageHtml.length}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    OutlinedButton(
                        onPressed: _currentPage == _pageHtml.length - 1
                            ? null
                            : () => _goToPage(_currentPage + 1),
                        child: const Text('Next')),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: _addPage,
                  style: FilledButton.styleFrom(
                    foregroundColor: const Color(0xff4F46E5),
                  ),
                  child: const Text('+ Add Page'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _pageHtml.length == 1 ? null : _deletePage,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xffDC2626),
                      side: const BorderSide(color: Color(0xffFECACA))),
                  child: const Text('- Delete Page'),
                ),
              ],
            )
          else
            Row(
              children: [
                OutlinedButton(
                    onPressed: _currentPage == 0
                        ? null
                        : () => _goToPage(_currentPage - 1),
                    child: const Text('Prev')),
                const SizedBox(width: 12),
                Text('Page ${_currentPage + 1} / ${_pageHtml.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                OutlinedButton(
                    onPressed: _currentPage == _pageHtml.length - 1
                        ? null
                        : () => _goToPage(_currentPage + 1),
                    child: const Text('Next')),
                const Spacer(),
                OutlinedButton(
                  onPressed: _addPage,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff4F46E5),
                      side: const BorderSide(color: Color(0xffC7D2FE)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12)),
                  child: const Text('+ Add Page'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _pageHtml.length == 1 ? null : _deletePage,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xffDC2626),
                      side: const BorderSide(color: Color(0xffFECACA)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12)),
                  child: const Text('- Delete Page'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: canvasWidth,
                constraints: BoxConstraints(minHeight: canvasMinHeight),
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact
                      ? _margin.clamp(12.0, 18.0).toDouble()
                      : _margin,
                  vertical: isCompact ? 18 : 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10,
                      color: Color(0x140F172A),
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: editorHeight,
                  child: RichEditorSurface(
                    key: ValueKey(_currentPage),
                    controller: _editorController,
                    initialHtml: _pageHtml[_currentPage],
                    fontFamily: _fontFamily,
                    fontSize: _fontSize,
                    lineSpacing: _lineSpacing,
                    onChanged: _updateCurrentPage,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter({required bool isCompact}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Flex(
        direction: isCompact ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment:
            isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text('Words: $_wordCount | Chars: $_charCount',
              style: const TextStyle(color: Color(0xff64748B), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _compactToolbarButton(String label, VoidCallback onPressed,
      {FontWeight? fontWeight,
      FontStyle? fontStyle,
      TextDecoration? decoration}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(30, 30),
          side: const BorderSide(color: Color(0xffCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: fontWeight,
                fontStyle: fontStyle,
                decoration: decoration,
                fontSize: 13)),
      ),
    );
  }

  Widget _labelToolbarButton(
      IconData icon, String label, VoidCallback onPressed,
      {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon,
            size: 14,
            color: active ? const Color(0xff4338CA) : const Color(0xff475569)),
        label: label.isEmpty
            ? const SizedBox.shrink()
            : Text(label,
                style: TextStyle(
                    color: active
                        ? const Color(0xff4338CA)
                        : const Color(0xff475569))),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(30, 32),
          side: BorderSide(
              color:
                  active ? const Color(0xffA5B4FC) : const Color(0xffCBD5E1)),
          backgroundColor: active ? const Color(0xffEEF2FF) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(
              horizontal: label.isEmpty ? 10 : 12, vertical: 0),
        ),
      ),
    );
  }

  Widget _toolbarDivider() {
    return Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: const Color(0xffCBD5E1));
  }

  InputDecoration _toolbarDropdownDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffCBD5E1))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffCBD5E1))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xff94A3B8))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_flowState != 'done') return _buildUploadState();
    final isCompact = _isCompactLayout(context);
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(_pagePadding(context)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xffE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                        blurRadius: 18,
                        color: Color(0x120F172A),
                        offset: Offset(0, 6))
                  ],
                ),
                child: Column(
                  children: [
                    _buildHeader(isCompact: isCompact),
                    const Divider(height: 1),
                    _buildToolbar(),
                    if (_isFindReplaceOpen) ...[
                      const Divider(height: 1),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: _buildFindReplaceBar(isCompact: isCompact)),
                    ],
                    const Divider(height: 1),
                    Expanded(child: _buildEditorCanvas(isCompact: isCompact)),
                    const Divider(height: 1),
                    _buildFooter(isCompact: isCompact),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

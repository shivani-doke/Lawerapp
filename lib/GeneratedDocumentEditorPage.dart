import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'widgets/rich_editor_surface.dart';

class GeneratedDocumentEditorPage extends StatefulWidget {
  const GeneratedDocumentEditorPage({
    super.key,
    required this.filename,
    this.documentTitle,
  });

  final String filename;
  final String? documentTitle;

  @override
  State<GeneratedDocumentEditorPage> createState() =>
      _GeneratedDocumentEditorPageState();
}

class _GeneratedDocumentEditorPageState
    extends State<GeneratedDocumentEditorPage> {
  static const List<double> _fontSizes = <double>[
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

  static const List<String> _fontFamilies = <String>[
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
  static const List<MapEntry<String, double>> _lineSpacingOptions =
      <MapEntry<String, double>>[
    MapEntry<String, double>('Single', 1.0),
    MapEntry<String, double>('1.15', 1.15),
    MapEntry<String, double>('1.5', 1.5),
    MapEntry<String, double>('Double', 2.0),
  ];

  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final RichEditorController _editorController = RichEditorController();

  final List<String> _pageHtml = <String>['<p></p>'];
  final List<String> _pagePlainText = <String>[''];

  int _currentPage = 0;
  double _fontSize = 14;
  double _margin = 24;
  double _lineSpacing = 1.0;
  String _fontFamily = 'Times New Roman';
  bool _isFindReplaceOpen = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = await ApiService().getDocumentContent(widget.filename);
      final plainText = (payload['content'] ?? '').toString();
      final html = (payload['html'] ?? '').toString();
      final htmlPages = _buildInitialPages(html, plainText);
      final plainPages = _buildPlainTextPages(htmlPages, plainText);

      if (!mounted) return;
      setState(() {
        _pageHtml
          ..clear()
          ..addAll(htmlPages);
        _pagePlainText
          ..clear()
          ..addAll(plainPages);
        _currentPage = 0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<String> _buildInitialPages(String html, String plainText) {
    final trimmedHtml = html.trim();
    if (trimmedHtml.isNotEmpty) {
      return <String>[trimmedHtml];
    }

    final normalized = plainText.replaceAll('\r\n', '\n').trimRight();
    final textPages = _paginatePlainText(normalized);
    return textPages.map(_htmlFromPlainText).toList();
  }

  List<String> _buildPlainTextPages(List<String> htmlPages, String fallbackText) {
    final converted = htmlPages.map(_plainTextFromHtml).toList();
    if (converted.every((page) => page.trim().isEmpty) &&
        fallbackText.trim().isNotEmpty) {
      return _paginatePlainText(fallbackText);
    }
    return converted;
  }

  List<String> _paginatePlainText(String content) {
    if (content.trim().isEmpty) {
      return <String>[''];
    }

    final paragraphs = content.split(RegExp(r'\n\s*\n'));
    final pages = <String>[];
    final buffer = StringBuffer();

    for (final rawParagraph in paragraphs) {
      final paragraph = rawParagraph.trim();
      if (paragraph.isEmpty) continue;

      final nextValue = buffer.isEmpty
          ? paragraph
          : '${buffer.toString()}\n\n$paragraph';
      if (nextValue.length > 1800 && buffer.isNotEmpty) {
        pages.add(buffer.toString());
        buffer
          ..clear()
          ..write(paragraph);
      } else {
        if (buffer.isNotEmpty) {
          buffer.write('\n\n');
        }
        buffer.write(paragraph);
      }
    }

    if (buffer.isNotEmpty) {
      pages.add(buffer.toString());
    }

    return pages.isEmpty ? <String>[''] : pages;
  }

  String _htmlFromPlainText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '<p></p>';
    }
    final escaped = trimmed
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return escaped
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => '<p>${paragraph.replaceAll('\n', '<br>')}</p>')
        .join();
  }

  String _plainTextFromHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(
            r'</(p|div|h1|h2|h3|li|ul|ol|blockquote)>',
            caseSensitive: false,
          ),
          '\n',
        )
        .replaceAll(
          RegExp(r'<hr[^>]*>', caseSensitive: false),
          '\n----------------------------------------\n',
        )
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
    if (mounted) {
      setState(() {});
    }
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _pageHtml.length) return;
    setState(() {
      _currentPage = index;
    });
  }

  void _addPage() {
    setState(() {
      _pageHtml.add('<p></p>');
      _pagePlainText.add('');
      _currentPage = _pageHtml.length - 1;
    });
  }

  void _deletePage() {
    if (_pageHtml.length == 1) return;
    setState(() {
      _pageHtml.removeAt(_currentPage);
      _pagePlainText.removeAt(_currentPage);
      if (_currentPage >= _pageHtml.length) {
        _currentPage = _pageHtml.length - 1;
      }
    });
  }

  void _runCommand(String command, [String? value]) {
    _editorController.execCommand(command, value);
    _editorController.focus();
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
      if (option.value == _lineSpacing) {
        return option.key;
      }
    }
    return _lineSpacingOptions.first.key;
  }

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
      case 'highlight':
        _runCommand('hiliteColor', '#FFFF00');
        break;
      case 'rule':
        _runCommand(
          'insertHTML',
          '<hr style="border:none;border-top:2px solid #cbd5e1;margin:12px 0;" />',
        );
        break;
      case 'clear':
        _runCommand('removeFormat');
        break;
      case 'find':
        setState(() {
          _isFindReplaceOpen = !_isFindReplaceOpen;
        });
        break;
      default:
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

  int get _wordCount {
    final words = _pagePlainText.join('\n\n').trim();
    if (words.isEmpty) return 0;
    return words.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  int get _charCount => _pagePlainText.join('\n\n').length;

  Future<void> _saveDocument() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final currentHtml = await _editorController.getHtml();
      final currentPlain = _editorController.getPlainText();
      _updateCurrentPage(currentHtml, currentPlain);

      final mergedHtml = _pageHtml
          .map((page) => page.trim())
          .where((page) => page.isNotEmpty)
          .join('<div data-page-break="true"></div>');
      final mergedPlain = _pagePlainText
          .map((page) => page.trimRight())
          .where((page) => page.isNotEmpty)
          .join('\n\n');

      await ApiService().updateDocument(
        widget.filename,
        mergedPlain,
        html: mergedHtml,
        fontFamily: _fontFamily,
        fontSize: _fontSize.round(),
        lineSpacing: _lineSpacingLabel,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xffF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xffF8FAFC),
        appBar: AppBar(
          title: const Text('Document Editor'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildEditor(),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1060),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffE5E7EB)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                color: Color(0x120F172A),
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              const Divider(height: 1),
              _buildToolbar(),
              if (_isFindReplaceOpen) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: _buildFindReplaceBar(),
                ),
              ],
              const Divider(height: 1),
              Expanded(child: _buildEditorCanvas()),
              const Divider(height: 1),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xffE0E7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xff4F46E5),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document Editor',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff0F172A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Edit text and export as PDF.',
                  style: TextStyle(
                    color: Color(0xff64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _saveDocument,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
                _compactToolbarButton(
                  'B',
                  () => _applyTemplate('bold'),
                  fontWeight: FontWeight.w700,
                ),
                _compactToolbarButton(
                  'I',
                  () => _applyTemplate('italic'),
                  fontStyle: FontStyle.italic,
                ),
                _compactToolbarButton(
                  'U',
                  () => _applyTemplate('underline'),
                  decoration: TextDecoration.underline,
                ),
                _compactToolbarButton(
                  'S',
                  () => _applyTemplate('strike'),
                  decoration: TextDecoration.lineThrough,
                ),
                _toolbarDivider(),
                _labelToolbarButton(
                  Icons.format_list_bulleted,
                  'List',
                  () => _applyTemplate('bullet'),
                ),
                _labelToolbarButton(
                  Icons.format_list_numbered,
                  '1. List',
                  () => _applyTemplate('number'),
                ),
                _toolbarDivider(),
                _labelToolbarButton(
                  Icons.format_align_left,
                  'Left',
                  () => _applyTemplate('left'),
                ),
                _labelToolbarButton(
                  Icons.format_align_center,
                  'Center',
                  () => _applyTemplate('center'),
                ),
                _labelToolbarButton(
                  Icons.format_align_right,
                  'Right',
                  () => _applyTemplate('right'),
                ),
                _toolbarDivider(),
                _labelToolbarButton(
                  Icons.format_indent_increase,
                  'Indent',
                  () => _applyTemplate('indent'),
                ),
                _labelToolbarButton(
                  Icons.format_indent_decrease,
                  'Outdent',
                  () => _applyTemplate('outdent'),
                ),
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
                    value: _fontSizes.contains(_fontSize.roundToDouble())
                        ? _fontSize.roundToDouble()
                        : _fontSizes.first,
                    isExpanded: true,
                    iconSize: 18,
                    decoration: _toolbarDropdownDecoration(),
                    selectedItemBuilder: (context) => _fontSizes
                        .map(
                          (_) => const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Size',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xff0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    items: _fontSizes
                        .map(
                          (size) => DropdownMenuItem<double>(
                            value: size,
                            child: Text(size.toInt().toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _fontSize = value;
                      });
                      _runCommand('fontSize', _fontSizeCommandValue(value));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: _fontFamilies.contains(_fontFamily)
                        ? _fontFamily
                        : _fontFamilies.first,
                    isExpanded: true,
                    iconSize: 18,
                    decoration: _toolbarDropdownDecoration(),
                    selectedItemBuilder: (context) => _fontFamilies
                        .map(
                          (_) => const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Font Family',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xff0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    items: _fontFamilies
                        .map(
                          (family) => DropdownMenuItem<String>(
                            value: family,
                            child: Text(
                              family,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _fontFamily = value;
                      });
                      _runCommand('fontName', value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: DropdownButtonFormField<String>(
                    value: _lineSpacingLabel,
                    isExpanded: true,
                    iconSize: 18,
                    decoration: _toolbarDropdownDecoration(),
                    items: _lineSpacingOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option.key,
                            child: Text(
                              option.key,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final selected = _lineSpacingOptions.firstWhere(
                        (option) => option.key == value,
                        orElse: () => _lineSpacingOptions.first,
                      );
                      setState(() {
                        _lineSpacing = selected.value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _compactToolbarButton('H1', () => _applyTemplate('h1')),
                _compactToolbarButton('H2', () => _applyTemplate('h2')),
                _compactToolbarButton('P', () => _applyTemplate('paragraph')),
                _toolbarDivider(),
                _labelToolbarButton(
                  Icons.horizontal_rule,
                  'Rule',
                  () => _applyTemplate('rule'),
                ),
                _labelToolbarButton(
                  Icons.format_clear,
                  'Clear',
                  () => _applyTemplate('clear'),
                ),
                _toolbarDivider(),
                _labelToolbarButton(
                  Icons.find_replace,
                  'Find & Replace',
                  () => _applyTemplate('find'),
                  active: _isFindReplaceOpen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindReplaceBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xffEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffC7D2FE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _findController,
              decoration: const InputDecoration(
                hintText: 'Find...',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '->',
            style: TextStyle(
              color: Color(0xff64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _replaceController,
              decoration: const InputDecoration(
                hintText: 'Replace...',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _replaceAll,
            child: const Text('Replace All'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                _isFindReplaceOpen = false;
              });
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCanvas() {
    return Container(
      color: const Color(0xffF1F5F9),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(
        children: [
          Row(
            children: [
              OutlinedButton(
                onPressed:
                    _currentPage == 0 ? null : () => _goToPage(_currentPage - 1),
                child: const Text('Prev'),
              ),
              const SizedBox(width: 12),
              Text(
                'Page ${_currentPage + 1} / ${_pageHtml.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _currentPage == _pageHtml.length - 1
                    ? null
                    : () => _goToPage(_currentPage + 1),
                child: const Text('Next'),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _addPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff4F46E5),
                  side: const BorderSide(color: Color(0xffC7D2FE)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: const Text('+ Add Page'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _pageHtml.length == 1 ? null : _deletePage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xffDC2626),
                  side: const BorderSide(color: Color(0xffFECACA)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: const Text('- Delete Page'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 824,
                  constraints: const BoxConstraints(minHeight: 980),
                  padding: EdgeInsets.symmetric(
                    horizontal: _margin,
                    vertical: 24,
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
                    height: 860,
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
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Text(
            'Words: $_wordCount | Chars: $_charCount',
            style: const TextStyle(
              color: Color(0xff64748B),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactToolbarButton(
    String label,
    VoidCallback onPressed, {
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(30, 30),
          side: const BorderSide(color: Color(0xffCBD5E1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _labelToolbarButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 14,
          color: active ? const Color(0xff4338CA) : const Color(0xff475569),
        ),
        label: label.isEmpty
            ? const SizedBox.shrink()
            : Text(
                label,
                style: TextStyle(
                  color: active
                      ? const Color(0xff4338CA)
                      : const Color(0xff475569),
                ),
              ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(30, 32),
          side: BorderSide(
            color:
                active ? const Color(0xffA5B4FC) : const Color(0xffCBD5E1),
          ),
          backgroundColor:
              active ? const Color(0xffEEF2FF) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: label.isEmpty ? 10 : 12,
            vertical: 0,
          ),
        ),
      ),
    );
  }

  Widget _toolbarDivider() {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xffCBD5E1),
    );
  }

  InputDecoration _toolbarDropdownDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff94A3B8)),
      ),
    );
  }
}

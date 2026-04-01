import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import 'web_preview_iframe_stub.dart'
    if (dart.library.html) 'web_preview_iframe_web.dart';

class CaseStatusPage extends StatefulWidget {
  const CaseStatusPage({super.key});

  @override
  State<CaseStatusPage> createState() => _CaseStatusPageState();
}

class _CaseStatusPageState extends State<CaseStatusPage> {
  static const String ecourtsUrl =
      'https://services.ecourts.gov.in/ecourtindia_v6/?p=casestatus/index&app_token=';
  static const String iframeViewType = 'ecourts-case-status-iframe';

  final WebviewController _windowsController = WebviewController();
  bool _isLoading = true;
  bool _windowsReady = false;
  String? _errorMessage;

  bool get _isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      registerPreviewIframe(iframeViewType, ecourtsUrl);
      _isLoading = false;
      return;
    }

    if (_isWindowsDesktop) {
      _initializeWindowsWebView();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _initializeWindowsWebView() async {
    try {
      await _windowsController.initialize();
      await _windowsController.loadUrl(ecourtsUrl);
      if (!mounted) return;
      setState(() {
        _windowsReady = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load embedded eCourts view: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _reload() async {
    if (kIsWeb) {
      await _openExternally();
      return;
    }

    if (_isWindowsDesktop && _windowsReady) {
      await _windowsController.loadUrl(ecourtsUrl);
      return;
    }

    await _openExternally();
  }

  Future<void> _openExternally() async {
    final uri = Uri.parse(ecourtsUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open eCourts portal')),
      );
    }
  }

  @override
  void dispose() {
    _windowsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Case Status',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use the official eCourts page below. Enter captcha there, submit, and review the cases inside this section.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _buildToolbar(),
            const SizedBox(height: 20),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff111827),
            foregroundColor: Colors.white,
          ),
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
          label: const Text('Reload'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _openExternally,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open Outside'),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return _buildMessageCard(_errorMessage!);
    }

    if (kIsWeb) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: buildPreviewIframe(iframeViewType),
      );
    }

    if (_isWindowsDesktop && _windowsReady) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Webview(_windowsController),
      );
    }

    return _buildMessageCard(
      'Embedded eCourts view is only configured here for Flutter web iframe and Windows desktop. Use Open Outside on this platform.',
    );
  }

  Widget _buildMessageCard(String message) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 42, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

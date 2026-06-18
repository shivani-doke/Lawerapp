import 'dart:convert';
import 'dart:typed_data';

import 'package:LegalAI/Clientside.dart';
import 'package:LegalAI/CaseStatusPage.dart';
import 'package:LegalAI/DashboardPage.dart';
import 'package:LegalAI/DocumentPage.dart';
import 'package:LegalAI/SmartLegalEditorPage.dart';
import 'package:LegalAI/UploadsPage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/session_service.dart';
import 'LegalAiPage.dart';
import 'GiftDeedPage.dart';
import 'RentalAgreementPage.dart';
import 'PowerOfAttorneyPage.dart';
import 'PartnershipDeedPage.dart';
import 'AffidavitPage.dart';
import 'WillTestamentPage.dart';
import 'BailApplicationPage.dart';
import 'LoanAgreementPage.dart';
import 'DivorcePaperPage.dart';
import 'SaleDeedPage.dart';
import 'MortgageDeedPage.dart';
import 'NonDisclosureAgreementPage.dart';
import 'EmploymentContractPage.dart';
import 'OfferLetterPage.dart';
import 'ServiceAgreementPage.dart';
import 'ChildCustodyAgreementPage.dart';
import 'AdoptionPapersPage.dart';
import 'PartitionDeedPage.dart';
import 'TrustDeedPage.dart';
import 'MemorandumOfUnderstandingPage.dart';
import 'VendorAgreementPage.dart';
import 'NonCompeteAgreementPage.dart';
import 'IndemnityAgreementPage.dart';
import 'JointVentureAgreementPage.dart';
import 'LicensingAgreementPage.dart';
import 'AssignmentAgreementPage.dart';
import 'SettlementAgreementPage.dart';
import 'TrademarkApplicationPage.dart';
import 'CopyrightAgreementPage.dart';
import 'PatentFilingDocumentsPage.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key, this.onLogout, this.session});

  final Future<void> Function()? onLogout;
  final Map<String, dynamic>? session;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static const double _mobileBreakpoint = 900;
  static const double _mobileMenuVerticalClearance = 76;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int selectedIndex = 0;
  bool _isUpdatingLogin = false;
  late String? _currentUserEmail;
  late String? _currentDisplayName;
  late String? _currentFirmName;
  late String? _currentRole;
  late String? _appDisplayName;
  late String? _appLogoData;
  late String? _overLimitMessage;
  late bool _canManageBilling;
  late bool _isPlatformAdmin;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    _currentUserEmail = widget.session?['email']?.toString();
    _currentDisplayName = widget.session?['display_name']?.toString() ??
        widget.session?['username']?.toString();
    _currentFirmName = widget.session?['firm_name']?.toString();
    _currentRole = widget.session?['role']?.toString();
    _appDisplayName = widget.session?['app_display_name']?.toString();
    _appLogoData = widget.session?['app_logo_data']?.toString();
    _overLimitMessage = widget.session?['over_limit_message']?.toString();
    _isPlatformAdmin = widget.session?['is_platform_admin'] == true;
    _canManageBilling = widget.session?['can_manage_billing'] == true;
    if (!_isPlatformAdmin && _canManageBilling) {
      _refreshFirmBranding();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final message = (_overLimitMessage ?? '').trim();
      if (!mounted ||
          message.isEmpty ||
          !_canManageBilling ||
          _isPlatformAdmin) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
        ),
      );
    });
    pages = [
      DashboardPage(onNavigate: _changePage),
      const LegalAIPage(),
      DocumentsPage(onNavigate: _changePage), // const DocumentsPage(),
      const ClientsPage(),
      const GiftDeedPage(), // 4
      const RentalAgreementPage(), // 5
      PowerOfAttorneyPage(), // 6
      PartnershipDeedPage(), // 7
      const AffidavitPage(), // 8
      const WillTestamentPage(), // 9
      const BailApplicationPage(), // 10
      LoanAgreementPage(),
      const DivorcePaperPage(), // 12
      const SaleDeedPage(), // 13
      const MortgageDeedPage(), // 14
      const NonDisclosureAgreementPage(), // 15
      const EmploymentContractPage(), // 16
      const OfferLetterPage(), // 17
      const ServiceAgreementPage(), // 18
      const ChildCustodyAgreementPage(), // 19
      const AdoptionPapersPage(), // 20
      const PartitionDeedPage(), // 21
      const TrustDeedPage(), // 22
      const MemorandumOfUnderstandingPage(), // 23
      const VendorAgreementPage(), // 24
      const NonCompeteAgreementPage(), // 25
      const IndemnityAgreementPage(), // 26
      const JointVentureAgreementPage(), // 27
      const LicensingAgreementPage(), // 28
      const AssignmentAgreementPage(), // 29
      const SettlementAgreementPage(), // 30
      const TrademarkApplicationPage(), // 31
      const CopyrightAgreementPage(), // 32
      const PatentFilingDocumentsPage(), // 33
      UploadsPage(onNavigate: _changePage), // 34
      const SmartLegalEditorPage(), // 35
      CaseStatusPage(onNavigate: _changePage), // 36
      FirmSettingsPage(
        isFirmAdmin: _canManageBilling && !_isPlatformAdmin,
        firmName: _currentFirmName,
        appDisplayName: _effectiveAppDisplayName,
        overLimitMessage: _overLimitMessage,
        onOpenBranding: _showBrandingDialog,
        onOpenTeamManagement: _showManageTeamDialog,
        onLogout: widget.onLogout,
      ), // 37
    ];
  }

  void _changePage(int index, {bool closeDrawer = false}) {
    setState(() {
      selectedIndex = index;
    });
    if (closeDrawer && mounted) {
      Navigator.of(context).pop();
    }
  }

  bool get _shouldApplyMobileMenuInset => selectedIndex != 3;

  Widget _buildMobilePageContent() {
    final page = pages[selectedIndex];
    if (!_shouldApplyMobileMenuInset) {
      return page;
    }

    return Padding(
      padding: const EdgeInsets.only(top: _mobileMenuVerticalClearance),
      child: page,
    );
  }

  Future<void> _showChangeLoginDialog() async {
    final formKey = GlobalKey<FormState>();
    final currentEmailController = TextEditingController(
      text: _currentUserEmail ?? '',
    );
    final currentPasswordController = TextEditingController();
    final newEmailController =
        TextEditingController(text: _currentUserEmail ?? '');
    final newFullNameController =
        TextEditingController(text: _currentDisplayName ?? '');
    final newUsernameController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Login Credentials'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Current Email',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter current email'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscureCurrent = !obscureCurrent;
                              });
                            },
                            icon: Icon(
                              obscureCurrent
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Enter current password'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newFullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter full name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newEmailController,
                        decoration: const InputDecoration(
                          labelText: 'New Email',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter new email'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newUsernameController,
                        decoration: const InputDecoration(
                          labelText: 'Internal Username',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscureNew = !obscureNew;
                              });
                            },
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Enter new password';
                          }
                          if ((value ?? '').length < 4) {
                            return 'Use at least 4 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isUpdatingLogin
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _isUpdatingLogin
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          setState(() => _isUpdatingLogin = true);
                          try {
                            final result =
                                await ApiService().updateAuthSettings(
                              currentUsername: '',
                              currentEmail: currentEmailController.text.trim(),
                              currentPassword: currentPasswordController.text,
                              newUsername: newUsernameController.text.trim(),
                              newEmail: newEmailController.text.trim(),
                              newFullName: newFullNameController.text.trim(),
                              newPassword: newPasswordController.text,
                            );
                            await SessionService.saveSession(result);
                            if (!mounted) return;
                            setState(() {
                              _currentUserEmail = (result['email'] ??
                                      newEmailController.text.trim())
                                  .toString();
                              _currentDisplayName = (result['display_name'] ??
                                      result['full_name'] ??
                                      newFullNameController.text.trim())
                                  .toString();
                              _currentFirmName = (result['firm_name'] ??
                                      _currentFirmName ??
                                      '')
                                  .toString();
                              _currentRole =
                                  (result['role'] ?? _currentRole ?? '')
                                      .toString();
                              _isPlatformAdmin =
                                  result['is_platform_admin'] == true;
                              _canManageBilling =
                                  result['can_manage_billing'] == true;
                            });
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Login credentials updated. Use the new username and password next time you sign in.',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _isUpdatingLogin = false);
                            }
                          }
                        },
                  child: _isUpdatingLogin
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showManageTeamDialog() async {
    await showDialog(
      context: context,
      builder: (_) => const TeamManagementDialog(),
    );
  }

  Future<void> _showManageFirmsDialog() async {
    await showDialog(
      context: context,
      builder: (_) => const FirmManagementDialog(),
    );
  }

  String get _effectiveAppDisplayName {
    final custom = (_appDisplayName ?? '').trim();
    if (custom.isNotEmpty) {
      return custom;
    }
    return 'LegalAI';
  }

  List<int>? _logoBytesFromData(String? dataUrl) {
    final raw = (dataUrl ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    final commaIndex = raw.indexOf(',');
    final encoded = commaIndex >= 0 ? raw.substring(commaIndex + 1) : raw;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  String _logoMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/png';
  }

  Future<void> _refreshFirmBranding() async {
    try {
      final result = await ApiService().getFirmBranding();
      if (!mounted) return;
      setState(() {
        _appDisplayName = result['app_display_name']?.toString();
        _appLogoData = result['app_logo_data']?.toString();
      });
      final currentSession = await SessionService.loadSession();
      await SessionService.saveSession({
        ...currentSession,
        'app_display_name': result['app_display_name'],
        'app_logo_data': result['app_logo_data'],
      });
    } catch (_) {
      // Keep the current in-memory/session branding if the fetch fails.
    }
  }

  Future<void> _showBrandingDialog() async {
    final formKey = GlobalKey<FormState>();
    final appNameController = TextEditingController(
      text: (_appDisplayName ?? '').trim().isNotEmpty
          ? _appDisplayName!.trim()
          : _effectiveAppDisplayName,
    );
    String? draftLogoData =
        (_appLogoData ?? '').trim().isEmpty ? null : _appLogoData;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final previewBytes = _logoBytesFromData(draftLogoData);
            return AlertDialog(
              title: const Text('App Branding'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: appNameController,
                        decoration: const InputDecoration(
                          labelText: 'App Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter app name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'App Logo',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xfff8fafc),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xffe2e8f0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xff0f172a),
                              backgroundImage: previewBytes != null
                                  ? MemoryImage(
                                      Uint8List.fromList(previewBytes))
                                  : null,
                              child: previewBytes == null
                                  ? const Icon(
                                      Icons.balance,
                                      color: Colors.amber,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                previewBytes == null
                                    ? 'No custom logo selected'
                                    : 'Custom logo ready',
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final result =
                                        await FilePicker.platform.pickFiles(
                                      type: FileType.image,
                                      withData: true,
                                    );
                                    final file =
                                        (result == null || result.files.isEmpty)
                                            ? null
                                            : result.files.first;
                                    final bytes = file?.bytes;
                                    if (file == null || bytes == null) {
                                      return;
                                    }
                                    final mimeType = _logoMimeType(file.name);
                                    setDialogState(() {
                                      draftLogoData =
                                          'data:$mimeType;base64,${base64Encode(bytes)}';
                                    });
                                  },
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Choose Logo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: isSaving || draftLogoData == null
                                ? null
                                : () {
                                    setDialogState(() {
                                      draftLogoData = null;
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove Logo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final result =
                                await ApiService().updateFirmBranding(
                              appDisplayName: appNameController.text.trim(),
                              appLogoData: draftLogoData,
                              clearLogo: draftLogoData == null,
                            );
                            final currentSession =
                                await SessionService.loadSession();
                            await SessionService.saveSession({
                              ...currentSession,
                              'app_display_name': result['app_display_name'],
                              'app_logo_data': result['app_logo_data'],
                            });
                            if (!mounted) return;
                            setState(() {
                              _appDisplayName =
                                  result['app_display_name']?.toString();
                              _appLogoData =
                                  result['app_logo_data']?.toString();
                            });
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('App branding updated.'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brandLogoBytes = _logoBytesFromData(_appLogoData);
    final isMobile = MediaQuery.of(context).size.width < _mobileBreakpoint;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xfff5f6f8),
      drawer: isMobile
          ? Drawer(
              width: 280,
              child: _buildSidebarContent(brandLogoBytes, isMobile: true),
            )
          : null,
      body: isMobile
          ? Stack(
              children: [
                Positioned.fill(child: _buildMobilePageContent()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: const Color(0xff0f172a).withOpacity(0.92),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.menu_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                /// ================= SIDEBAR =================
                Container(
                  width: 240,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xff0f172a), Color(0xff0b1a33)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        /// Logo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xff13233f),
                              backgroundImage: brandLogoBytes != null
                                  ? MemoryImage(
                                      Uint8List.fromList(brandLogoBytes))
                                  : null,
                              child: brandLogoBytes == null
                                  ? const Icon(
                                      Icons.balance,
                                      color: Colors.amber,
                                      size: 22,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _effectiveAppDisplayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 50),

                        _navItem(Icons.dashboard, "Dashboard", 0),
                        _navItem(Icons.chat_bubble_outline, "AI Chat", 1),
                        _navItem(Icons.description_outlined, "Documents", 2),
                        _navItem(Icons.people_outline, "Clients", 3),
                        _navItem(Icons.upload_file_outlined, "Uploads", 34),
                        _navItem(Icons.edit_note, "Edit Document", 35),
                        _navItem(Icons.fact_check_outlined, "Case Status", 36),
                        if (!_isPlatformAdmin)
                          _navItem(Icons.settings_outlined, "Settings", 37),
                        const SizedBox(height: 24),
                        if ((_currentDisplayName ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white12,
                                  child: Text(
                                    _currentDisplayName!.trim().isEmpty
                                        ? '?'
                                        : _currentDisplayName!
                                            .trim()[0]
                                            .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentDisplayName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (((_currentRole ?? '')
                                              .trim()
                                              .isNotEmpty) ||
                                          ((_currentFirmName ?? '')
                                              .trim()
                                              .isNotEmpty))
                                        Text(
                                          [
                                            if ((_currentRole ?? '')
                                                .trim()
                                                .isNotEmpty)
                                              _currentRole == 'platform_admin'
                                                  ? 'Platform Admin'
                                                  : _currentRole == 'firm_admin'
                                                      ? 'Firm Admin'
                                                      : 'Lawyer',
                                            if ((_currentFirmName ?? '')
                                                .trim()
                                                .isNotEmpty)
                                              _currentFirmName!,
                                          ].join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_isPlatformAdmin)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showManageFirmsDialog,
                                icon: const Icon(Icons.apartment_outlined),
                                label: const Text('Manage Firms'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_isPlatformAdmin)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isUpdatingLogin
                                    ? null
                                    : _showChangeLoginDialog,
                                icon:
                                    const Icon(Icons.manage_accounts_outlined),
                                label: const Text('Change Login'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (widget.onLogout != null && _isPlatformAdmin)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: widget.onLogout == null
                                    ? null
                                    : () async => widget.onLogout!(),
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Logout'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                /// ================= PAGE CONTENT =================
                Expanded(child: pages[selectedIndex]),
              ],
            ),
    );
  }

  Widget _buildSidebarContent(
    List<int>? brandLogoBytes, {
    bool isMobile = false,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff0f172a), Color(0xff0b1a33)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xff13233f),
                      backgroundImage: brandLogoBytes != null
                          ? MemoryImage(Uint8List.fromList(brandLogoBytes))
                          : null,
                      child: brandLogoBytes == null
                          ? const Icon(
                              Icons.balance,
                              color: Colors.amber,
                              size: 22,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _effectiveAppDisplayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              _navItem(Icons.dashboard, "Dashboard", 0, isMobile: isMobile),
              _navItem(Icons.chat_bubble_outline, "AI Chat", 1,
                  isMobile: isMobile),
              _navItem(Icons.description_outlined, "Documents", 2,
                  isMobile: isMobile),
              _navItem(Icons.people_outline, "Clients", 3, isMobile: isMobile),
              _navItem(Icons.upload_file_outlined, "Uploads", 34,
                  isMobile: isMobile),
              _navItem(Icons.edit_note, "Edit Document", 35,
                  isMobile: isMobile),
              _navItem(Icons.fact_check_outlined, "Case Status", 36,
                  isMobile: isMobile),
              if (!_isPlatformAdmin)
                _navItem(Icons.settings_outlined, "Settings", 37,
                    isMobile: isMobile),
              const SizedBox(height: 24),
              if ((_currentDisplayName ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white12,
                        child: Text(
                          _currentDisplayName!.trim().isEmpty
                              ? '?'
                              : _currentDisplayName!.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentDisplayName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (((_currentRole ?? '').trim().isNotEmpty) ||
                                ((_currentFirmName ?? '').trim().isNotEmpty))
                              Text(
                                [
                                  if ((_currentRole ?? '').trim().isNotEmpty)
                                    _currentRole == 'platform_admin'
                                        ? 'Platform Admin'
                                        : _currentRole == 'firm_admin'
                                            ? 'Firm Admin'
                                            : 'Lawyer',
                                  if ((_currentFirmName ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    _currentFirmName!,
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isPlatformAdmin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showManageFirmsDialog,
                      icon: const Icon(Icons.apartment_outlined),
                      label: const Text('Manage Firms'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isPlatformAdmin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _isUpdatingLogin ? null : _showChangeLoginDialog,
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Change Login'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.onLogout != null && _isPlatformAdmin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onLogout == null
                          ? null
                          : () async => widget.onLogout!(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String title, int index,
      {bool isMobile = false}) {
    bool active = selectedIndex == index;

    return InkWell(
      onTap: () => _changePage(index, closeDrawer: isMobile),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: active ? const Color(0xff1e293b) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? Colors.amber : Colors.white70),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: active ? Colors.amber : Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FirmManagementDialog extends StatefulWidget {
  const FirmManagementDialog({super.key});

  @override
  State<FirmManagementDialog> createState() => _FirmManagementDialogState();
}

class _FirmManagementDialogState extends State<FirmManagementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firmNameController = TextEditingController();
  final _adminFullNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _maxTeamMembersController = TextEditingController(text: '10');
  bool _isSubmitting = false;
  bool _isLoading = true;
  int? _busyFirmId;
  List<Map<String, dynamic>> _firms = [];
  static const String _masterDefaultFirmName = 'Default Firm';

  @override
  void initState() {
    super.initState();
    _loadFirms();
  }

  @override
  void dispose() {
    _firmNameController.dispose();
    _adminFullNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _maxTeamMembersController.dispose();
    super.dispose();
  }

  Future<void> _loadFirms() async {
    try {
      final firms = await ApiService().getFirms();
      final visibleFirms = firms
          .where(
            (firm) =>
                (firm['name'] ?? '').toString().trim() !=
                _masterDefaultFirmName,
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _firms = visibleFirms;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _createFirm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().createFirm(
        firmName: _firmNameController.text.trim(),
        adminFullName: _adminFullNameController.text.trim(),
        adminEmail: _adminEmailController.text.trim(),
        adminPassword: _adminPasswordController.text,
        maxTeamMembers: int.parse(_maxTeamMembersController.text.trim()),
      );
      _firmNameController.clear();
      _adminFullNameController.clear();
      _adminEmailController.clear();
      _adminPasswordController.clear();
      _maxTeamMembersController.text = '10';
      await _loadFirms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firm credentials created successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _updateFirmLimit(Map<String, dynamic> firm) async {
    final controller = TextEditingController(
      text: (firm['max_team_members'] ?? 10).toString(),
    );
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update Team Limit'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Team Members',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final parsed = int.tryParse((value ?? '').trim());
                if (parsed == null || parsed < 1) {
                  return 'Enter a value of at least 1';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      controller.dispose();
      return;
    }

    final firmId = (firm['id'] as num?)?.toInt();
    if (firmId == null) {
      controller.dispose();
      return;
    }

    setState(() => _busyFirmId = firmId);
    try {
      final result = await ApiService().updateFirm(
        firmId: firmId,
        maxTeamMembers: int.parse(controller.text.trim()),
      );
      await _loadFirms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (result['message'] ?? 'Firm team limit updated successfully.')
                .toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      controller.dispose();
      if (mounted) {
        setState(() => _busyFirmId = null);
      }
    }
  }

  Future<void> _deleteFirm(Map<String, dynamic> firm) async {
    final firmId = (firm['id'] as num?)?.toInt();
    final firmName = (firm['name'] ?? '').toString();
    if (firmId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Firm'),
          content: Text(
            'Delete $firmName and all users, clients, and payments under this firm?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _busyFirmId = firmId);
    try {
      await ApiService().deleteFirm(firmId);
      await _loadFirms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firm deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyFirmId = null);
      }
    }
  }

  String _createdAtLabel(dynamic value) {
    final raw = (value ?? '').toString();
    if (raw.isEmpty) return 'Recently added';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 980,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Manage Firms',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create firm credentials for the user-side login flow.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firmNameController,
                          decoration: const InputDecoration(
                            labelText: 'Firm Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter firm name';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _adminFullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Firm Admin Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter admin name';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _adminEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Firm Admin Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter admin email';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _adminPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Enter password';
                            }
                            if ((value ?? '').length < 4) {
                              return 'Use at least 4 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: TextFormField(
                          controller: _maxTeamMembersController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Team Limit',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final parsed = int.tryParse((value ?? '').trim());
                            if (parsed == null || parsed < 1) {
                              return 'Min 1';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _createFirm,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.apartment_outlined),
                      label: const Text('Create Firm Credentials'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffEEEEEE)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _firms.isEmpty
                      ? const SizedBox(
                          height: 140,
                          child: Center(
                            child: Text(
                              'No firms available yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Registered Firms',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap a firm to edit team limit. Use the Delete button to remove firm credentials.',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 280,
                              child: ListView.separated(
                                itemCount: _firms.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final firm = _firms[index];
                                  final firmId = (firm['id'] as num?)?.toInt();
                                  final isBusy = _busyFirmId == firmId;
                                  final isDefaultFirm =
                                      (firm['name'] ?? '').toString() ==
                                          'Default Firm';
                                  final primaryAdmin = firm['primary_admin']
                                      as Map<String, dynamic>?;
                                  final adminName = primaryAdmin == null
                                      ? 'No admin yet'
                                      : (primaryAdmin['display_name'] ??
                                              primaryAdmin['full_name'] ??
                                              primaryAdmin['email'] ??
                                              '')
                                          .toString();
                                  final adminEmail = primaryAdmin == null
                                      ? ''
                                      : (primaryAdmin['email'] ?? '')
                                          .toString();
                                  final teamCount =
                                      (firm['user_count'] ?? 0).toString();
                                  final teamLimit =
                                      (firm['max_team_members'] ?? 0)
                                          .toString();
                                  final isOverLimit =
                                      firm['is_over_limit'] == true;
                                  final overLimitBy =
                                      (firm['over_limit_by'] ?? 0).toString();
                                  final createdLabel =
                                      _createdAtLabel(firm['created_at']);
                                  return ListTile(
                                    onTap: isBusy
                                        ? null
                                        : () => _updateFirmLimit(firm),
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xff0f172a)
                                          .withOpacity(0.08),
                                      child: const Icon(
                                        Icons.business_outlined,
                                        color: Color(0xff0f172a),
                                      ),
                                    ),
                                    title: Text(
                                      (firm['name'] ?? '').toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        'Admin: $adminName',
                                        if (adminEmail.isNotEmpty) adminEmail,
                                        'Members: $teamCount',
                                        'Created $createdLabel',
                                      ].join(' • '),
                                    ),
                                    trailing: isBusy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xff0f172a)
                                                      .withOpacity(0.06),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  'Limit $teamLimit',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xff0f172a),
                                                  ),
                                                ),
                                              ),
                                              if (isOverLimit) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xfffee2e2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      999,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Remove $overLimitBy user${overLimitBy == '1' ? '' : 's'}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xffb91c1c),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (!isDefaultFirm) ...[
                                                const SizedBox(width: 8),
                                                TextButton.icon(
                                                  onPressed: () =>
                                                      _deleteFirm(firm),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent,
                                                  ),
                                                  label: const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeamManagementDialog extends StatefulWidget {
  const TeamManagementDialog({super.key});

  @override
  State<TeamManagementDialog> createState() => _TeamManagementDialogState();
}

class _TeamManagementDialogState extends State<TeamManagementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _teamMembers = [];
  Map<String, dynamic>? _teamSummary;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamMembers() async {
    try {
      final teamMembers = await ApiService().getTeamUsers();
      final teamSummary = await ApiService().getTeamSummary();
      if (!mounted) return;
      setState(() {
        _teamMembers = teamMembers;
        _teamSummary = teamSummary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().createTeamUser(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: 'lawyer',
      );

      _fullNameController.clear();
      _emailController.clear();
      _passwordController.clear();
      await _loadTeamMembers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team member created successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Team Member'),
          content: Text(
            'Are you sure you want to delete ${(member['display_name'] ?? member['full_name'] ?? member['username'] ?? '').toString()}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().deleteTeamUser((member['id'] as num).toInt());
      await _loadTeamMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team member deleted successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _roleLabel(String role) {
    return role == 'firm_admin' ? 'Firm Admin' : 'Lawyer';
  }

  String _createdAtLabel(dynamic value) {
    final raw = (value ?? '').toString();
    if (raw.isEmpty) return 'Recently added';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 860,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Team',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create lawyer accounts under this firm and review current access.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    if (_teamSummary != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Seats used ${_teamSummary!['team_count'] ?? 0}/${(_teamSummary!['firm'] as Map?)?['max_team_members'] ?? 0} • Remaining ${_teamSummary!['remaining_slots'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter full name';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter email';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Enter password';
                        }
                        if ((value ?? '').length < 4) {
                          return 'Use at least 4 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 170,
                    child: TextFormField(
                      initialValue: 'Lawyer',
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _createUser,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: const Text('Add User'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffEEEEEE)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _teamMembers.isEmpty
                      ? const SizedBox(
                          height: 140,
                          child: Center(
                            child: Text(
                              'No team members found yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Team',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (((_teamSummary?['over_limit_message'] ?? '')
                                    .toString())
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xfffef2f2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xfffecaca),
                                  ),
                                ),
                                child: Text(
                                  (_teamSummary?['over_limit_message'] ?? '')
                                      .toString(),
                                  style: const TextStyle(
                                    color: Color(0xff991b1b),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 280,
                              child: ListView.separated(
                                itemCount: _teamMembers.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final member = _teamMembers[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xff0f172a)
                                          .withOpacity(0.08),
                                      child: const Icon(
                                        Icons.person_outline,
                                        color: Color(0xff0f172a),
                                      ),
                                    ),
                                    title: Text(
                                      (member['display_name'] ??
                                              member['full_name'] ??
                                              member['username'] ??
                                              '')
                                          .toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${(member['email'] ?? '').toString()} • ${_roleLabel((member['role'] ?? '').toString())} • Added ${_createdAtLabel(member['created_at'])}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (member['can_manage_billing'] ==
                                            true)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Billing Access',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        IconButton(
                                          onPressed: _isSubmitting ||
                                                  member['id'] == null
                                              ? null
                                              : () => _deleteUser(member),
                                          tooltip: 'Delete user',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class FirmSettingsPage extends StatelessWidget {
  const FirmSettingsPage({
    super.key,
    required this.isFirmAdmin,
    required this.firmName,
    required this.appDisplayName,
    required this.overLimitMessage,
    required this.onOpenBranding,
    required this.onOpenTeamManagement,
    required this.onLogout,
  });

  final bool isFirmAdmin;
  final String? firmName;
  final String appDisplayName;
  final String? overLimitMessage;
  final Future<void> Function() onOpenBranding;
  final Future<void> Function() onOpenTeamManagement;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFirmAdmin
                  ? 'Manage your firm workspace, branding, and team access.'
                  : 'Review your workspace details and account actions.',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Workspace',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Firm: ${(firmName ?? '').trim().isEmpty ? 'Your Firm' : firmName!}',
                    style: const TextStyle(
                      color: Color(0xff334155),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'App Name: $appDisplayName',
                    style: const TextStyle(
                      color: Color(0xff334155),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (isFirmAdmin) ...[
              _SettingsActionCard(
                title: 'App Branding',
                description:
                    'Update the app name and logo shown across your firm workspace.',
                icon: Icons.brush_outlined,
                onTap: () async => onOpenBranding(),
              ),
              const SizedBox(height: 16),
              _SettingsActionCard(
                title: 'Manage Team',
                description:
                    'Create lawyer accounts and review who has access to this firm.',
                icon: Icons.groups_outlined,
                onTap: () async => onOpenTeamManagement(),
              ),
              const SizedBox(height: 16),
            ],
            _SettingsActionCard(
              title: 'Logout',
              description: 'Sign out of the current workspace safely.',
              icon: Icons.logout_rounded,
              isDestructive: true,
              onTap: onLogout == null ? null : () async => onLogout!(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionCard extends StatelessWidget {
  const _SettingsActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.extraContent,
  });

  final String title;
  final String description;
  final IconData icon;
  final Future<void> Function()? onTap;
  final bool isDestructive;
  final Widget? extraContent;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        isDestructive ? Colors.redAccent : const Color(0xff0f172a);
    return InkWell(
      onTap: onTap == null ? null : () async => onTap!(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xff64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  isDestructive
                      ? Icons.logout_rounded
                      : Icons.chevron_right_rounded,
                  color: accentColor,
                ),
              ],
            ),
            if (extraContent != null) extraContent!,
          ],
        ),
      ),
    );
  }
}

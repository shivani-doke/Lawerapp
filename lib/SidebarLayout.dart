import 'package:LegalAI/Clientside.dart';
import 'package:LegalAI/CaseStatusPage.dart';
import 'package:LegalAI/DashboardPage.dart';
import 'package:LegalAI/DocumentPage.dart';
import 'package:LegalAI/UploadsPage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
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
  const MainLayout({super.key, this.onLogout, this.loggedInUsername});

  final Future<void> Function()? onLogout;
  final String? loggedInUsername;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int selectedIndex = 0;
  bool _isUpdatingLogin = false;
  late String? _currentUsername;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    _currentUsername = widget.loggedInUsername;
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
      const CaseStatusPage(), // 35
    ];
  }

  void _changePage(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Future<void> _showChangeLoginDialog() async {
    final formKey = GlobalKey<FormState>();
    final currentUsernameController = TextEditingController(
      text: _currentUsername ?? '',
    );
    final currentPasswordController = TextEditingController();
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
                        controller: currentUsernameController,
                        decoration: const InputDecoration(
                          labelText: 'Current Username',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter current username'
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
                        controller: newUsernameController,
                        decoration: const InputDecoration(
                          labelText: 'New Username',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter new username'
                            : null,
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
                            await ApiService().updateAuthSettings(
                              currentUsername: currentUsernameController.text.trim(),
                              currentPassword: currentPasswordController.text,
                              newUsername: newUsernameController.text.trim(),
                              newPassword: newPasswordController.text,
                            );
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                              'logged_in_username',
                              newUsernameController.text.trim(),
                            );
                            if (!mounted) return;
                            setState(() {
                              _currentUsername = newUsernameController.text.trim();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6f8),
      body: Row(
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
            child: Column(
              children: [
                const SizedBox(height: 40),

                /// Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.balance, color: Colors.amber, size: 26),
                    SizedBox(width: 10),
                    Text(
                      "LegalAI",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),

                _navItem(Icons.dashboard, "Dashboard", 0),
                _navItem(Icons.chat_bubble_outline, "AI Chat", 1),
                _navItem(Icons.description_outlined, "Documents", 2),
                _navItem(Icons.people_outline, "Clients", 3),
                _navItem(Icons.fact_check_outlined, "Case Status", 35),
                _navItem(Icons.upload_file_outlined, "Uploads", 34),
                const Spacer(),
                if ((_currentUsername ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Signed in as $_currentUsername',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                      child: OutlinedButton.icon(
                      onPressed: _isUpdatingLogin ? null : _showChangeLoginDialog,
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
                if (widget.onLogout != null)
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

          /// ================= PAGE CONTENT =================
          Expanded(child: pages[selectedIndex]),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String title, int index) {
    bool active = selectedIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
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

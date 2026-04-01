import 'package:LegalAI/Clientside.dart';
import 'package:LegalAI/CaseStatusPage.dart';
import 'package:LegalAI/DashboardPage.dart';
import 'package:LegalAI/DocumentPage.dart';
import 'package:LegalAI/UploadsPage.dart';
import 'package:flutter/material.dart';
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
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int selectedIndex = 0;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
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

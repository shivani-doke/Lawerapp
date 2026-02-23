import 'package:chatbot/Clientside.dart';
import 'package:chatbot/DashboardPage.dart';
import 'package:chatbot/DocumentPage.dart';
import 'package:flutter/material.dart';
import 'LegalAiPage.dart';


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
      const DocumentsPage(),
      const ClientsPage(),
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

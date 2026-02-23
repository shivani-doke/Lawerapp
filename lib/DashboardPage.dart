import 'package:flutter/material.dart';
import 'LegalAiPage.dart';

class DashboardPage extends StatelessWidget {
  final Function(int)? onNavigate;
  const DashboardPage({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ================= WELCOME =================
            const Text(
              "Welcome back, Advocate",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Here's an overview of your legal practice today.",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 30),

            /// ================= STATS =================
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: const [
                _StatCard("Active Chats", "12", Icons.chat_bubble),
                _StatCard("Documents", "48", Icons.description),
                _StatCard("Clients", "36", Icons.people),
                _StatCard("Cases Active", "8", Icons.trending_up),
              ],
            ),

            const SizedBox(height: 30),

            /// ================= LOWER SECTION =================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Recent Documents
                Expanded(
                  flex: 2,
                  child: _recentDocuments(),
                ),

                const SizedBox(width: 20),

                /// Quick Actions
                Expanded(
                  child: _quickActions(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ================= RECENT DOCUMENTS =================
  static Widget _recentDocuments() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Recent Documents",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          _DocumentTile(
              "Rental Agreement - Sharma", "Rental Agreement", "Feb 14, 2026"),
          Divider(),
          _DocumentTile(
              "Sale Deed - Patel Property", "Sale Deed", "Feb 13, 2026"),
          Divider(),
          _DocumentTile("Power of Attorney - Kumar", "Deed", "Feb 12, 2026"),
          SizedBox(height: 15),
          Text(
            "View all documents →",
            style: TextStyle(color: Colors.amber),
          )
        ],
      ),
    );
  }

  /// ================= QUICK ACTIONS =================
  Widget _quickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _actionButton(
            "Start Chat",
            Icons.chat_bubble_outline,
            const Color(0xff1e293b),
            Colors.white,
            () {
              onNavigate?.call(1);
            },
          ),
          const SizedBox(height: 15),
          _actionButton(
            "New Document",
            Icons.description,
            Colors.amber,
            Colors.black,
            () {},
          ),
          const SizedBox(height: 15),
          _actionButton(
            "Add Client",
            Icons.people_outline,
            Colors.grey.shade200,
            Colors.black,
            () {},
          ),
          const SizedBox(height: 15),
          _actionButton(
            "Case Status",
            Icons.trending_up,
            Colors.grey.shade200,
            Colors.black,
            () {},
          ),
        ],
      ),
    );
  }

  static Widget _actionButton(String text, IconData icon, Color bgColor,
      Color textColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor),
              const SizedBox(width: 10),
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// ================= STAT CARD =================
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard(this.title, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ]),
          Icon(icon, size: 28, color: Colors.amber),
        ],
      ),
    );
  }
}

/// ================= DOCUMENT TILE =================
class _DocumentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;

  const _DocumentTile(this.title, this.subtitle, this.date);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        date,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}

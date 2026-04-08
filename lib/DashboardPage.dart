import 'package:flutter/material.dart';
import 'GeneratedDocumentEditorPage.dart';
import 'LegalAiPage.dart';
import 'Clientside.dart';
import 'DocumentPage.dart';
import 'config/app_config.dart';
import 'services/dashboard_service.dart';
import 'services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardPage extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardPage({super.key, this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? data;
  bool isLoading = true;
  bool showAllDocuments = false;

  String? _editableFilenameFor(String? filename) {
    if (filename == null || filename.isEmpty) {
      return null;
    }

    final lower = filename.toLowerCase();
    if (lower.endsWith('.docx')) {
      return filename;
    }
    if (lower.endsWith('.pdf')) {
      return '${filename.substring(0, filename.length - 4)}.docx';
    }
    return null;
  }

  Future<void> _openDocumentEditor(Map<String, dynamic> doc) async {
    final editableFilename = _editableFilenameFor(doc["filename"]?.toString());
    if (editableFilename == null || !mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeneratedDocumentEditorPage(
          filename: editableFilename,
          documentTitle: doc["title"]?.toString(),
        ),
      ),
    );

    if (!mounted) return;
    loadData(all: showAllDocuments);
  }

  String _formatCurrency(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? "0") ?? 0;
    if (amount == amount.roundToDouble()) {
      return "Rs ${amount.toStringAsFixed(0)}";
    }
    return "Rs ${amount.toStringAsFixed(2)}";
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void _showRenameDialog(String oldName) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename Document"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Enter new name",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;

                try {
                  await DashboardService.renameDocument(oldName, newName);

                  Navigator.pop(context);

                  // 🔥 Refresh dashboard
                  loadData(all: showAllDocuments);
                } catch (e) {
                  print(e);
                }
              },
              child: const Text("Rename"),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(String filename) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Document"),
          content: const Text("Are you sure you want to delete this document?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await DashboardService.deleteDocument(filename);

                  Navigator.pop(context);

                  // 🔥 Refresh UI
                  loadData(all: showAllDocuments);
                } catch (e) {
                  print(e);
                }
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> loadData({bool all = false}) async {
    try {
      setState(() {
        isLoading = true;
      });

      final result = await DashboardService.fetchDashboardData(all: all);

      setState(() {
        data = result;
        isLoading = false;
        showAllDocuments = all;
      });
    } catch (e) {
      print(e);
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
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
              children: [
                // _StatCard(
                //     "Active Chats",
                //     data?["stats"]["chats"].toString() ?? "0",
                //     Icons.chat_bubble),
                _StatCard(
                    "Documents",
                    data?["stats"]["documents"].toString() ?? "0",
                    Icons.description),
                _StatCard("Clients",
                    data?["stats"]["clients"].toString() ?? "0", Icons.people),
                _StatCard(
                    "Cases Active",
                    data?["stats"]["active_cases"].toString() ?? "0",
                    Icons.trending_up),
                _StatCard(
                  "Finance",
                  _formatCurrency(data?["stats"]["total_received"] ?? 0),
                  Icons.account_balance_wallet_outlined,
                  onTap: _showFinanceReportDialog,
                ),
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
  Widget _recentDocuments() {
    final List docs = data?["recent_documents"] ?? [];

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
            "Recent Documents",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: showAllDocuments ? 400 : null,
            child: ListView(
              shrinkWrap: true,
              physics: showAllDocuments
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              children: docs.map<Widget>((doc) {
                final editableFilename =
                    _editableFilenameFor(doc["filename"]?.toString());

                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(doc["title"]),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(doc["date"]),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) async {
                              final filename = doc["filename"];

                              if (value == "rename") {
                                _showRenameDialog(filename);
                              } else if (value == "delete") {
                                _confirmDelete(filename);
                              } else if (value == "edit") {
                                await _openDocumentEditor(doc);
                              } else if (value == "download") {
                                final username =
                                    await SessionService.getLoggedInUsername();
                                final url =
                                    "${AppConfig.backendBaseUrl}/dashboard/download/$filename?username=$username";

                                final uri = Uri.parse(url);

                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  print("Download failed");
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              if (editableFilename != null)
                                const PopupMenuItem(
                                  value: "edit",
                                  child: Text("Edit"),
                                ),
                              const PopupMenuItem(
                                value: "rename",
                                child: Text("Rename"),
                              ),
                              const PopupMenuItem(
                                value: "delete",
                                child: Text("Delete"),
                              ),
                              const PopupMenuItem(
                                value: "download",
                                child: Text("Download"),
                              ),
                            ],
                          )
                        ],
                      ),
                      onTap: () async {
                        final filename = doc["filename"];
                        if (filename == null) return;

                        final username =
                            await SessionService.getLoggedInUsername();
                        final url =
                            "${AppConfig.backendBaseUrl}/view/$filename?username=$username";
                        final uri = Uri.parse(url);

                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                    const Divider()
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: () {
              loadData(all: !showAllDocuments);
            },
            child: Text(
              showAllDocuments ? "Show less ←" : "View all documents →",
              style: const TextStyle(color: Colors.amber),
            ),
          ),
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
              widget.onNavigate?.call(1); // Navigate to Chat tab
            },
          ),
          const SizedBox(height: 15),
          _actionButton(
            "New Document",
            Icons.description,
            Colors.amber,
            Colors.black,
            () {
              widget.onNavigate?.call(2);
            },
          ),
          const SizedBox(height: 15),
          _actionButton(
            "Add Client",
            Icons.people_outline,
            Colors.grey.shade200,
            Colors.black,
            () {
              widget.onNavigate
                  ?.call(3); // Navigate to Clients tab (adjust index if needed)
            },
          ),
          const SizedBox(height: 15),
          _actionButton(
            "Case Status",
            Icons.trending_up,
            Colors.grey.shade200,
            Colors.black,
            () {
              widget.onNavigate?.call(35);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showFinanceReportDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 980,
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<Map<String, dynamic>>(
              future: DashboardService.fetchFinanceReport(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 420,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return SizedBox(
                    height: 220,
                    child: Center(
                      child: Text("Unable to load finance report: ${snapshot.error}"),
                    ),
                  );
                }

                final report = snapshot.data ?? {};
                final summary = Map<String, dynamic>.from(
                  report["summary"] ?? {},
                );
                final clientReports =
                    (report["client_reports"] as List? ?? []).cast<dynamic>();
                final recentPayments =
                    (report["recent_payments"] as List? ?? []).cast<dynamic>();

                return Column(
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
                              "Finance Report",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Client-wise payment summary and recent receipts.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _FinanceSummaryCard(
                          title: "Total Fee",
                          value: _formatCurrency(summary["total_fee"] ?? 0),
                        ),
                        _FinanceSummaryCard(
                          title: "Received",
                          value:
                              _formatCurrency(summary["total_received"] ?? 0),
                        ),
                        _FinanceSummaryCard(
                          title: "Pending",
                          value:
                              _formatCurrency(summary["pending_amount"] ?? 0),
                        ),
                        _FinanceSummaryCard(
                          title: "Due Clients",
                          value:
                              (summary["clients_with_pending"] ?? 0).toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xffEEEEEE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Client Payments",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 320,
                                  child: clientReports.isEmpty
                                      ? const Center(
                                          child: Text(
                                            "No payment data yet.",
                                            style:
                                                TextStyle(color: Colors.grey),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: clientReports.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final item = Map<String, dynamic>.from(
                                              clientReports[index]
                                                  as Map<dynamic, dynamic>,
                                            );
                                            return ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 0,
                                                vertical: 4,
                                              ),
                                              title: Text(
                                                item["client_name"] ?? "",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              subtitle: Text(
                                                "${item["case_type"] ?? ""} • ${item["status"] ?? ""}",
                                              ),
                                              trailing: SizedBox(
                                                width: 260,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      "Received ${_formatCurrency(item["total_received"])}",
                                                    ),
                                                    Text(
                                                      "Pending ${_formatCurrency(item["pending_amount"])}",
                                                      style: TextStyle(
                                                        color: _asDouble(item[
                                                                    "pending_amount"]) >
                                                                0
                                                            ? Colors.redAccent
                                                            : Colors.green,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xffEEEEEE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Recent Payments",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 320,
                                  child: recentPayments.isEmpty
                                      ? const Center(
                                          child: Text(
                                            "No recent payments yet.",
                                            style:
                                                TextStyle(color: Colors.grey),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: recentPayments.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final payment =
                                                Map<String, dynamic>.from(
                                              recentPayments[index]
                                                  as Map<dynamic, dynamic>,
                                            );
                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(
                                                _formatCurrency(payment["amount"]),
                                              ),
                                              subtitle: Text(
                                                [
                                                  payment["payment_date"] ?? "",
                                                  payment["payment_mode"] ?? "",
                                                ]
                                                    .where((value) => value
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty)
                                                    .join(" • "),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? "0") ?? 0;
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
  final VoidCallback? onTap;

  const _StatCard(this.title, this.value, this.icon, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ]),
            Icon(icon, size: 28, color: Colors.amber),
          ],
        ),
      ),
    );
  }
}

class _FinanceSummaryCard extends StatelessWidget {
  final String title;
  final String value;

  const _FinanceSummaryCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
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



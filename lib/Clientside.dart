import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/app_config.dart';
import 'services/session_service.dart';

const List<String> kClientCaseTypes = [
  "AC Cri.M.A. - Criminal Misc. Application under Prevention of Corruption Act",
  "Arbitration Case",
  "Arbitration R.D - Arbitration Execution Darkhast",
  "Atro.Spl.Case - Special Case under Prevention of Atrocities Act",
  "B.G.P.E.Act Case - Case under Bombay Govt. Property Eviction Act",
  "C.Appln. - Civil Application",
  "Chapter Case",
  "Civil Appeal PPE - Civil Appeal under Public Premises Act",
  "Civil M.A. - Civil Misc. Application",
  "Civil Revn. - Civil Revision Application",
  "Civil Suit",
  "Commercial Appeal",
  "Commercial Suit",
  "Contempt Proceeding",
  "Cri.Appeal - Criminal Appeal",
  "Cri.Bail Appln. - Bail Application",
  "Cri.Case - Criminal Case",
  "Cri.M.A. - Criminal Misc. Application",
  "Cri.Municipal Appeal - Municipal Appeal (Criminal Side)",
  "Cri.Rev.App. - Criminal Revision Application",
  "Darkhast - Execution Petition",
  "Distress Warrant",
  "E.C.Act.Spl.Case - Special Case (Essential Commodities Act)",
  "Elec.Petn. - Election Petition",
  "Election Appeal",
  "E.S.I.Act Case - Proceedings under Employees State Insurance Act",
  "Final Decree",
  "Guardian Wards Case",
  "I.C.M.A. - Interlocutory Civil Misc. Application",
  "Insolvency - Insolvency Application",
  "Juvenile - Juvenile Case",
  "Juvenile Cri.MA",
  "L.A.R. - Land Acquisition Reference",
  "L.R.DKST. - Execution of Land Reference Award",
  "L.R.M.A. - Misc. Application in Land Reference",
  "M.A.C.P. - Motor Accident Claim Petition",
  "MACP C Appln. - Civil Application in Motor Accident Claim",
  "MACP. Dkst. - Execution of Award in Motor Accident Claims",
  "MACP. M.A. - Misc. Application in Motor Accident Claims",
  "MACP M.A.N.R.J.I. - Misc. Appln. not requiring Judicial Inquiry in Motor Accident Claim Petition",
  "MACP Spl. - Motor Accident Claim Petition (Special)",
  "MAHA P.I.D. 1999. - Special Case under Mah. P.I.D. Act",
  "M.A.N.R.J.I. - Misc. Application not requiring Judicial Inquiry",
  "Marriage Petn. - Marriage Petition",
  "M.C.A. - Misc.Civil Appeal",
  "MCOCO1999 - Special Case under MCOCO ACT 1999",
  "MCOCO.Revn. - Revision Application under MCOCO Act",
  "Mesne Profit - Mesne Profit Inquiries",
  "M.J.Cases - Misc. Judicial Cases",
  "MOCCA M.A. - Misc. Application under MOCC ACT",
  "MPID M.A. - Misc. Application under MPID Act",
  "MPID M.A. Others - Other Misc. Application under MPID Act",
  "MSEB MA - Misc. Application under Electricity Act",
  "Munci. Appeal - Munci. Appeal (civil)",
  "NDPS Cri.Revn. - Criminal Revision Application under NDPS Act",
  "NDPS M.A.. - Misc. Application under NDPS Act",
  "NDPS. S. Case - Special Cases under NDPS Act",
  "Other Misc.Appln. - Other Civil Misc.Application",
  "Other Misc.Cri.Appln - Other Misc.Criminal Application",
  "Pauper Appln. - Pauper Application",
  "P.C.M.Appln. - Misc. Application under Prevention of Corruption Act",
  "Probate",
  "PWDVA Appeal - Appeal under Domestic Violence Act",
  "PWDVA Appln. - Application under Domestic Violence Act",
  "PWDVA Execution - Execution of order passed under Domestic Violence Act",
  "PWDVA Revi. - Revision under Domestic Violence Act",
  "R.C.A. - Regular Civil Appeal",
  "R.C.C. - Regular Criminal Case",
  "R.C.S. - Regular Civil Suit",
  "Reg Dkst - Regular Execution Petition",
  "Reg.Sum.Suit - Regular Summary Suit",
  "Rent Appeal - Appeal under Rent Act",
  "Rent Suit - Civil Suit under Rent Act",
  "Review Appln.",
  "S.C.C. - Summons/Summary Criminal Case",
  "Sessions Case",
  "Small Cause Dkst - Execution Proceeding against small cause suit decree",
  "Small Cause Suit",
  "Spl.Case - Special Case (Sessions)",
  "Spl.Case ACB - Special Case under Prevention of Corruption Act",
  "Spl.Case ATS - Special Case relating offences investigated by ATS",
  "Spl.Case Child Prot. - Spl.Case under POCSO Act",
  "Spl. Case Drug Cosm. - Special Case under Drugs and Cosmetics Act",
  "Spl Case MSEB - Special Case under Electricity Act",
  "Spl.Cri.M.A. - Special Criminal Misc. Application",
  "Spl.C.S. - Special Civil Suit (Senior Division Judge)",
  "Spl .Dkst - Execution Petition against decree passed in Special Civil Suit",
  "Spl.M.A. Child Prot. - Special Misc. Application under POCSO Act",
  "Spl. Marriage Petn. - Marriage Petition under Special Marriage Act",
  "Spl.Sum.Suit - Special Summary Suit",
  "Std. Rent Appln. - Standard Rent Application",
  "Succession - Application for Succession Certificate",
  "Suit Indian Divorce Act - Suit under Indian Divorce Act",
  "Suit Trade Mark Act - Civil Suit under Trade Mark Act",
  "Sum.Civ.Suit - Summary Civil Suit",
  "Sum. Darkhast - Execution Petition against Decree in Summary Suit",
  "TADA S. C. - Sepcial Cases under TADA Act",
  "T.Cri.M.A. - Criminal Misc. Application under TADA Act",
  "Trust Appeal - Appeal against order of Charity Commissioner in Trust matters",
  "Trust Suit - Civil Suit concerning Trust matters",
  "W.C.F.A.Case - Workmen Compensation Fatal Accident Case",
  "W.C.N.F.A. Case - Workmen Compensation not involving Fatal Accident",
];

Map<String, dynamic> buildClientPayload({
  required String name,
  required String email,
  required String phone,
  String age = "",
  String occupation = "",
  String address = "",
  String panNumber = "",
  String aadharNumber = "",
  String feeAmount = "",
  required String caseType,
  required String status,
  String notes = "",
}) {
  return {
    "name": name,
    "email": email,
    "phone": phone,
    "age": age,
    "occupation": occupation,
    "address": address,
    "pan_number": panNumber,
    "aadhar_number": aadharNumber,
    "fee_amount": feeAmount,
    "case_type": caseType,
    "status": status,
    "notes": notes,
  };
}

double _parseCurrencyValue(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

String _formatCurrency(dynamic value) {
  final amount = _parseCurrencyValue(value);
  if (amount == amount.roundToDouble()) {
    return "Rs ${amount.toStringAsFixed(0)}";
  }
  return "Rs ${amount.toStringAsFixed(2)}";
}

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> clients = [];
  List<Map<String, dynamic>> filteredClients = [];
  bool isLoading = true;

  final String baseUrl = AppConfig.backendBaseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final username = await SessionService.getLoggedInUsername();
    return {'X-Username': username};
  }

  Future<Uri> _authorizedUri(String path) async {
    final username = await SessionService.getLoggedInUsername();
    return Uri.parse("$baseUrl$path").replace(
      queryParameters: {'username': username},
    );
  }

  @override
  void initState() {
    super.initState();
    fetchClients();
  }

  Future<void> fetchClients() async {
    try {
      final response = await http.get(
        await _authorizedUri("/clients/"),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);

        setState(() {
          clients = data
              .map((e) => {
                    "id": e["id"],
                    "name": e["name"],
                    "email": e["email"],
                    "phone": e["phone"] ?? "",
                    "age": e["age"] ?? "",
                    "occupation": e["occupation"] ?? "",
                    "address": e["address"] ?? "",
                    "panNumber": e["pan_number"] ?? "",
                    "aadharNumber": e["aadhar_number"] ?? "",
                    "feeAmount": _parseCurrencyValue(e["fee_amount"]),
                    "caseType": e["case_type"],
                    "status": e["status"],
                    "notes": e["notes"] ?? "",
                  })
              .toList()
              .cast<Map<String, dynamic>>();

          filteredClients = clients;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching clients: $e");
    }
  }

  void _searchClient(String query) {
    setState(() {
      filteredClients = clients.where((client) {
        return client["name"]!.toLowerCase().contains(query.toLowerCase()) ||
            client["email"]!.toLowerCase().contains(query.toLowerCase()) ||
            client["caseType"]!.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _deleteClient(Map<String, dynamic> client) async {
    await http.delete(
      await _authorizedUri("/clients/${client["id"]}"),
      headers: await _authHeaders(),
    );

    fetchClients();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showNotesDialog(Map<String, dynamic> client) {
    // Create a local copy of the client to avoid modifying original until save
    Map<String, dynamic> editableClient = Map.from(client);
    TextEditingController notesController =
        TextEditingController(text: client["notes"] ?? "");
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Notes for ${client["name"]}"),
              content: Container(
                width: 400,
                constraints: const BoxConstraints(maxHeight: 300),
                child: TextField(
                  controller: notesController,
                  maxLines: null, // Allows multiple lines
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: "Enter notes here...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffE0A800),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() => isSaving = true);
                          try {
                            // Update only the notes field via PUT
                            final url =
                                await _authorizedUri("/clients/${client["id"]}");
                            final response = await http.put(
                              url,
                              headers: {
                                ...await _authHeaders(),
                                "Content-Type": "application/json",
                              },
                              body: jsonEncode(buildClientPayload(
                                name: client["name"],
                                email: client["email"],
                                phone: client["phone"],
                                age: client["age"] ?? "",
                                occupation: client["occupation"] ?? "",
                                address: client["address"] ?? "",
                                panNumber: client["panNumber"] ?? "",
                                aadharNumber: client["aadharNumber"] ?? "",
                                feeAmount:
                                    (client["feeAmount"] ?? 0).toString(),
                                caseType: client["caseType"],
                                status: client["status"],
                                notes: notesController.text,
                              )),
                            );

                            if (response.statusCode == 200) {
                              // Update the local client object and refresh list
                              setState(() {
                                client["notes"] = notesController.text;
                              });
                              fetchClients(); // Refresh from server
                              Navigator.pop(context); // Close dialog
                            } else {
                              _showErrorSnackBar("Failed to update notes");
                            }
                          } catch (e) {
                            _showErrorSnackBar("Error: $e");
                          } finally {
                            setState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Save"),
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
      backgroundColor: const Color(0xffF5F6FA),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Title
            const Text(
              "Clients",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Manage your clients and their cases",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            /// Search + Add
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchClient,
                    decoration: InputDecoration(
                      hintText: "Search clients...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffE0A800),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () async {
                    final result = await showDialog(
                      context: context,
                      builder: (_) => const AddClientDialog(),
                    );

                    if (result == true) {
                      fetchClients(); // 🔥 Refresh from database
                    }
                  },
                  child: const Text(
                    "+ Add Client",
                    style: TextStyle(color: Colors.black),
                  ),
                )
              ],
            ),

            const SizedBox(height: 20, width: 16),

            /// Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    /// Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: Color(0xffEEEEEE))),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text("Name",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text("Contact",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 3,
                              child: Text("Case Type",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 1,
                              child: Text("Status",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.center,
                                child: Text("Payments",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              )),
                          Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.center,
                                child: Text("Actions",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              )),
                        ],
                      ),
                    ),

                    /// Rows
                    Expanded(
                      child: ListView(
                        children: filteredClients.map((c) {
                          return clientRow(c);
                        }).toList(),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget clientRow(Map<String, dynamic> client) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffEEEEEE))),
      ),
      child: Row(
        children: [
          /// Name
          Expanded(
            flex: 2,
            child: Text(
              client["name"]!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          /// Contact
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client["email"]!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  client["phone"]!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          /// Case Type
          Expanded(
            flex: 3,
            child: Text(
              client["caseType"]!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey),
            ),
          ),

          /// Status
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                onSelected: (newStatus) async {
                  // Update only the status via PUT
                  final clientId = client["id"];
                  final url = await _authorizedUri("/clients/$clientId");

                  try {
                    final response = await http.put(
                      url,
                      headers: {
                        ...await _authHeaders(),
                        "Content-Type": "application/json",
                      },
                      body: jsonEncode(buildClientPayload(
                        name: client["name"],
                        email: client["email"],
                        phone: client["phone"],
                        age: client["age"] ?? "",
                        occupation: client["occupation"] ?? "",
                        address: client["address"] ?? "",
                        panNumber: client["panNumber"] ?? "",
                        aadharNumber: client["aadharNumber"] ?? "",
                        feeAmount: (client["feeAmount"] ?? 0).toString(),
                        caseType: client["caseType"],
                        status: newStatus,
                        notes: client["notes"] ?? "",
                      )),
                    );

                    if (response.statusCode == 200) {
                      fetchClients(); // refresh list
                    } else {
                      _showErrorSnackBar("Failed to update status");
                    }
                  } catch (e) {
                    _showErrorSnackBar("Error: $e");
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: "Active",
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text("Active"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: "Pending",
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text("Pending"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: "Closed",
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Colors.grey, size: 16),
                        SizedBox(width: 8),
                        Text("Closed"),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor(client["status"]!).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    client["status"]!,
                    style: TextStyle(
                      color: statusColor(client["status"]!),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// Action
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Color(0xffE0A800)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ClientPaymentsDialog(client: client),
                  ).then((_) => fetchClients());
                },
                icon:
                    const Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: const Text("Payments"),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffE0A800),
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => SendUpdateDialog(
                        clientName: client["name"]!,
                        clientEmail: client["email"]!,
                      ),
                    );
                  },
                  icon: const Icon(Icons.send, color: Colors.black, size: 18),
                  label: const Text("Send Update",
                      style: TextStyle(color: Colors.black)),
                ),

                /// More Options
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) async {
                    if (value == "edit") {
                      final result = await showDialog(
                        context: context,
                        builder: (_) => EditClientDialog(client: client),
                      );
                      if (result == true) {
                        fetchClients(); // Refresh after edit
                      }
                    } else if (value == "delete") {
                      _deleteClient(client);
                    } else if (value == "notes") {
                      _showNotesDialog(client);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: "edit",
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 12),
                          Text("Edit Client"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: "delete",
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 12),
                          Text("Delete Client"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: "notes",
                      child: Row(
                        children: [
                          Icon(Icons.note, color: Colors.blue),
                          SizedBox(width: 12),
                          Text("View Notes"),
                        ],
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Color statusColor(String status) {
    switch (status) {
      case "Active":
        return Colors.green;
      case "Pending":
        return Colors.orange;
      case "Closed":
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}

///    ========   Edit client Dialog   ==========
class EditClientDialog extends StatefulWidget {
  final Map<String, dynamic> client;

  const EditClientDialog({super.key, required this.client});

  @override
  State<EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends State<EditClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _ageController;
  late TextEditingController _occupationController;
  late TextEditingController _addressController;
  late TextEditingController _panNumberController;
  late TextEditingController _aadharNumberController;
  late TextEditingController _feeAmountController;
  late String _selectedCaseType;
  late String _selectedStatus;
  late TextEditingController _notesController;

  final String baseUrl = AppConfig.backendBaseUrl;

  // Case type options (same as AddClientDialog)
  final List<String> _caseTypes = kClientCaseTypes;

  late List<String>
      _availableCaseTypes; // To include current value if not in list

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _nameController = TextEditingController(text: client["name"]);
    _emailController = TextEditingController(text: client["email"]);
    _phoneController = TextEditingController(text: client["phone"]);
    _ageController = TextEditingController(text: client["age"] ?? "");
    _occupationController =
        TextEditingController(text: client["occupation"] ?? "");
    _addressController = TextEditingController(text: client["address"] ?? "");
    _panNumberController =
        TextEditingController(text: client["panNumber"] ?? "");
    _aadharNumberController =
        TextEditingController(text: client["aadharNumber"] ?? "");
    _feeAmountController = TextEditingController(
      text: _parseCurrencyValue(client["feeAmount"]).toStringAsFixed(
        _parseCurrencyValue(client["feeAmount"]) % 1 == 0 ? 0 : 2,
      ),
    );
    _selectedStatus = client["status"] ?? "Active";
    _notesController =
        TextEditingController(text: widget.client["notes"] ?? "");

    // Ensure current case type is available in dropdown
    final currentCaseType = client["caseType"] ?? "";
    if (_caseTypes.contains(currentCaseType)) {
      _availableCaseTypes = List.from(_caseTypes);
    } else {
      _availableCaseTypes = List.from(_caseTypes)..add(currentCaseType);
    }
    _selectedCaseType = currentCaseType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    _addressController.dispose();
    _panNumberController.dispose();
    _aadharNumberController.dispose();
    _feeAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final username = await SessionService.getLoggedInUsername();
      final response = await http.put(
        Uri.parse("$baseUrl/clients/${widget.client["id"]}")
            .replace(queryParameters: {'username': username}),
        headers: {
          "Content-Type": "application/json",
          "X-Username": username,
        },
        body: jsonEncode(buildClientPayload(
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          age: _ageController.text,
          occupation: _occupationController.text,
          address: _addressController.text,
          panNumber: _panNumberController.text,
          aadharNumber: _aadharNumberController.text,
          feeAmount: _feeAmountController.text,
          caseType: _selectedCaseType,
          status: _selectedStatus,
          notes: _notesController.text,
        )),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        _showError("Failed to update client. Please try again.");
      }
    } catch (e) {
      _showError("An error occurred: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Edit Client",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Update the client's details and case information below.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Full Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    hintText: "e.g. Rajesh Sharma",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? "Name is required"
                      : null,
                ),
                const SizedBox(height: 12),

                // Email and Phone (side by side)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          hintText: "email@example.com",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? "Email is required"
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: "Phone",
                          hintText: "+91 98765 43210",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Age",
                    hintText: "e.g. 35",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _occupationController,
                  decoration: InputDecoration(
                    labelText: "Occupation",
                    hintText: "e.g. Business / Service",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: "Address",
                    hintText: "Enter full address",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _panNumberController,
                        decoration: InputDecoration(
                          labelText: "PAN Number",
                          hintText: "e.g. ABCDE1234F",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _aadharNumberController,
                        decoration: InputDecoration(
                          labelText: "Aadhar Number",
                          hintText: "Enter Aadhar number",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _feeAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: "Total Fee Amount",
                    hintText: "e.g. 25000",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Case Type Dropdown (with same options as AddClientDialog)
                DropdownButtonFormField<String>(
                  value: _selectedCaseType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: "Case Type",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: _availableCaseTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCaseType = value!;
                    });
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? "Select case type"
                      : null,
                ),
                const SizedBox(height: 12),

                // Status Dropdown (Active/Pending/Closed)
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: "Status",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: "Active", child: Text("Active")),
                    DropdownMenuItem(value: "Pending", child: Text("Pending")),
                    DropdownMenuItem(value: "Closed", child: Text("Closed")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),

                ///  Notes Field
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: "Case Notes",
                    hintText: "Brief description of the case...",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons (Cancel / Save)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffE0A800),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _saveChanges,
                      child: const Text("Save Changes"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ================= ADD CLIENT DIALOG =================

class AddClientDialog extends StatefulWidget {
  const AddClientDialog({super.key});

  @override
  State<AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<AddClientDialog> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final ageController = TextEditingController();
  final occupationController = TextEditingController();
  final addressController = TextEditingController();
  final panNumberController = TextEditingController();
  final aadharNumberController = TextEditingController();
  final feeAmountController = TextEditingController();
  final notesController = TextEditingController();

  String selectedCaseType = kClientCaseTypes.first;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    ageController.dispose();
    occupationController.dispose();
    addressController.dispose();
    panNumberController.dispose();
    aadharNumberController.dispose();
    feeAmountController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Add New Client",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close))
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "Enter the client's details and case information below.",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 16),

              /// Name
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  hintText: "e.g. Rajesh Sharma",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 12),

              /// Email + Phone
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        hintText: "email@example.com",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: "Phone",
                        hintText: "+91 98765 43210",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Age",
                  hintText: "e.g. 35",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: occupationController,
                decoration: InputDecoration(
                  labelText: "Occupation",
                  hintText: "e.g. Business / Service",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Address",
                  hintText: "Enter full address",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: panNumberController,
                      decoration: InputDecoration(
                        labelText: "PAN Number",
                        hintText: "e.g. ABCDE1234F",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: aadharNumberController,
                      decoration: InputDecoration(
                        labelText: "Aadhar Number",
                        hintText: "Enter Aadhar number",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextField(
                controller: feeAmountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Total Fee Amount",
                  hintText: "e.g. 25000",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 12),

              /// Case Type
              DropdownButtonFormField<String>(
                value: selectedCaseType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: "Case Type",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: kClientCaseTypes
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) => setState(() {
                  selectedCaseType = value!;
                }),
              ),

              const SizedBox(height: 12),

              /// Notes
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Case Notes",
                  hintText: "Brief description of the case...",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 20),

              /// Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel")),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffE0A800),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          emailController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Name and email are required")),
                        );
                        return;
                      }

                      final username =
                          await SessionService.getLoggedInUsername();
                      final response = await http.post(
                        Uri.parse("${AppConfig.backendBaseUrl}/clients/")
                            .replace(queryParameters: {'username': username}),
                        headers: {
                          "Content-Type": "application/json",
                          "X-Username": username,
                        },
                        body: jsonEncode(buildClientPayload(
                          name: nameController.text,
                          email: emailController.text,
                          phone: phoneController.text,
                          age: ageController.text,
                          occupation: occupationController.text,
                          address: addressController.text,
                          panNumber: panNumberController.text,
                          aadharNumber: aadharNumberController.text,
                          feeAmount: feeAmountController.text,
                          caseType: selectedCaseType,
                          status: "Active",
                          notes: notesController.text,
                        )),
                      );

                      if (response.statusCode == 200 ||
                          response.statusCode == 201) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text("Add Client"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ClientPaymentsDialog extends StatefulWidget {
  final Map<String, dynamic> client;

  const ClientPaymentsDialog({super.key, required this.client});

  @override
  State<ClientPaymentsDialog> createState() => _ClientPaymentsDialogState();
}

class _ClientPaymentsDialogState extends State<ClientPaymentsDialog> {
  final String baseUrl = AppConfig.backendBaseUrl;
  bool isLoading = true;
  bool isUpdatingFee = false;
  Map<String, dynamic>? data;

  Future<Map<String, String>> _authHeaders() async {
    final username = await SessionService.getLoggedInUsername();
    return {'X-Username': username};
  }

  Future<Uri> _authorizedUri(String path) async {
    final username = await SessionService.getLoggedInUsername();
    return Uri.parse("$baseUrl$path").replace(
      queryParameters: {'username': username},
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        await _authorizedUri("/payments/client/${widget.client["id"]}"),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        setState(() {
          data = Map<String, dynamic>.from(jsonDecode(response.body));
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load payments");
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to load payments: $e")),
        );
      }
    }
  }

  Future<void> _deletePayment(int paymentId) async {
    final response = await http.delete(
      await _authorizedUri("/payments/$paymentId"),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      await _loadPayments();
      return;
    }

    throw Exception("Failed to delete payment");
  }

  double _currentTotalFee() {
    return _parseCurrencyValue(
      data?["summary"]?["total_fee"] ?? widget.client["feeAmount"] ?? 0,
    );
  }

  Future<void> _editTotalFee() async {
    final currentFee = _currentTotalFee();
    final controller = TextEditingController(
      text: currentFee.toStringAsFixed(currentFee % 1 == 0 ? 0 : 2),
    );
    String? errorText;

    final updatedFee = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Edit Total Fee"),
              content: SizedBox(
                width: 360,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: "Total Fee",
                    hintText: "e.g. 25000",
                    errorText: errorText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffE0A800),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final parsedFee = double.tryParse(controller.text.trim());

                    if (parsedFee == null) {
                      setDialogState(() {
                        errorText = "Enter a valid fee amount";
                      });
                      return;
                    }

                    if (parsedFee < 0) {
                      setDialogState(() {
                        errorText = "Fee amount cannot be negative";
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, parsedFee);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (updatedFee == null) return;

    setState(() => isUpdatingFee = true);
    try {
      final response = await http.put(
        await _authorizedUri("/clients/${widget.client["id"]}"),
        headers: {
          ...await _authHeaders(),
          "Content-Type": "application/json",
        },
        body: jsonEncode({"fee_amount": updatedFee}),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to update total fee");
      }

      widget.client["feeAmount"] = updatedFee;
      await _loadPayments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Total fee updated successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to update total fee: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUpdatingFee = false);
      }
    }
  }

  Widget _summaryTile(
    String label,
    dynamic value, {
    VoidCallback? onEdit,
    bool showProgress = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xffF7F7F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                if (showProgress)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text("Edit"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatCurrency(value),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        height: 620,
        padding: const EdgeInsets.all(24),
        child: isLoading
            ? const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Payments - ${widget.client["name"]}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Track fee amount, received payments, and pending balance.",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffE0A800),
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () async {
                              final result = await showDialog(
                                context: context,
                                builder: (_) => AddPaymentDialog(
                                  clientId: widget.client["id"],
                                  clientName: widget.client["name"],
                                ),
                              );

                              if (result == true) {
                                await _loadPayments();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text("Add Payment"),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _summaryTile(
                        "Total Fee",
                        _currentTotalFee(),
                        onEdit: isUpdatingFee ? null : _editTotalFee,
                        showProgress: isUpdatingFee,
                      ),
                      const SizedBox(width: 12),
                      _summaryTile(
                        "Received",
                        data?["summary"]?["total_received"] ?? 0,
                      ),
                      const SizedBox(width: 12),
                      _summaryTile(
                        "Pending",
                        data?["summary"]?["pending_amount"] ?? 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Payment History",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final payments =
                            (data?["payments"] as List?)?.cast<Map>() ?? [];

                        if (payments.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xffF7F7F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "No payments added yet for this client.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: payments.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final payment = Map<String, dynamic>.from(
                              payments[index],
                            );
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    const Color(0xffE0A800).withOpacity(0.18),
                                child: const Icon(
                                  Icons.payments_outlined,
                                  color: Colors.black87,
                                ),
                              ),
                              title: Text(_formatCurrency(payment["amount"])),
                              subtitle: Text(
                                [
                                  payment["payment_date"] ?? "",
                                  payment["payment_mode"] ?? "",
                                  payment["notes"] ?? "",
                                ].where((item) => item.toString().trim().isNotEmpty).join("  •  "),
                              ),
                              trailing: IconButton(
                                tooltip: "Delete payment",
                                onPressed: () async {
                                  try {
                                    await _deletePayment(payment["id"] as int);
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content:
                                              Text("Unable to delete payment: $e"),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AddPaymentDialog extends StatefulWidget {
  final int clientId;
  final String clientName;

  const AddPaymentDialog({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final amountController = TextEditingController();
  final dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split("T").first,
  );
  final notesController = TextEditingController();
  bool isSaving = false;
  String selectedPaymentMode = "Cash";

  final List<String> paymentModes = const [
    "Cash",
    "UPI",
    "Bank Transfer",
    "Cheque",
    "Card",
    "Other",
  ];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      dateController.text = picked.toIso8601String().split("T").first;
    }
  }

  Future<void> _savePayment() async {
    if (amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment amount is required")),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final username = await SessionService.getLoggedInUsername();
      final response = await http.post(
        Uri.parse("${AppConfig.backendBaseUrl}/payments/").replace(
          queryParameters: {'username': username},
        ),
        headers: {
          "Content-Type": "application/json",
          "X-Username": username,
        },
        body: jsonEncode({
          "client_id": widget.clientId,
          "amount": amountController.text.trim(),
          "payment_mode": selectedPaymentMode,
          "payment_date": dateController.text.trim(),
          "notes": notesController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) Navigator.pop(context, true);
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to save payment: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    dateController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add Payment - ${widget.clientName}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Amount",
                hintText: "e.g. 5000",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Payment Date",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _pickDate,
                  child: const Text("Pick Date"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedPaymentMode,
              decoration: InputDecoration(
                labelText: "Payment Mode",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: paymentModes
                  .map((mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedPaymentMode = value ?? paymentModes.first;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Notes",
                hintText: "Optional payment note",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffE0A800),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isSaving ? null : _savePayment,
                  child: Text(isSaving ? "Saving..." : "Save Payment"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= SEND UPDATE (EMAIL ONLY) =================

class SendUpdateDialog extends StatefulWidget {
  final String clientName;
  final String clientEmail;

  const SendUpdateDialog({
    super.key,
    required this.clientName,
    required this.clientEmail,
  });

  @override
  State<SendUpdateDialog> createState() => _SendUpdateDialogState();
}

class _SendUpdateDialogState extends State<SendUpdateDialog> {
  bool isLoading = false;

  final subjectController = TextEditingController();
  final messageController = TextEditingController();

  Future<void> sendUpdate() async {
    if (subjectController.text.isEmpty || messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subject and message required")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${AppConfig.backendBaseUrl}/send-update"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.clientEmail,
          "subject": subjectController.text,
          "message": messageController.text,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email sent successfully")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${response.body}")),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send email: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Send Update to ${widget.clientName}",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ],
            ),

            const SizedBox(height: 10),
            const Text("Send case update to client via email",
                style: TextStyle(color: Colors.grey)),

            const SizedBox(height: 20),

            /// Subject
            const Text("Subject"),
            const SizedBox(height: 6),
            TextField(
              controller: subjectController,
              decoration: InputDecoration(
                hintText: "e.g. Case hearing scheduled",
                filled: true,
                fillColor: const Color(0xffF1F3F6),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 16),

            /// Message
            const Text("Message"),
            const SizedBox(height: 6),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Write your update message...",
                filled: true,
                fillColor: const Color(0xffF1F3F6),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 24),

            /// Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffE0A800),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading ? null : sendUpdate,
                  icon: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.black),
                  label: Text(isLoading ? "Sending..." : "Send Email",
                      style: const TextStyle(color: Colors.black)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

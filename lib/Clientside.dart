import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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

const double _kClientCompactBreakpoint = 600;

bool _isCompactClientLayout(BuildContext context,
        [double breakpoint = _kClientCompactBreakpoint]) =>
    MediaQuery.sizeOf(context).width < breakpoint;

Widget _buildResponsiveFieldsRow(
  BuildContext context, {
  required Widget first,
  required Widget second,
  double spacing = 12,
}) {
  final isCompact = _isCompactClientLayout(context);
  return Flex(
    direction: isCompact ? Axis.vertical : Axis.horizontal,
    crossAxisAlignment:
        isCompact ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
    children: [
      if (isCompact) first else Expanded(child: first),
      SizedBox(width: isCompact ? 0 : spacing, height: isCompact ? spacing : 0),
      if (isCompact) second else Expanded(child: second),
    ],
  );
}

Widget _buildResponsiveActionRow(
  BuildContext context, {
  required List<Widget> children,
  MainAxisAlignment mainAxisAlignment = MainAxisAlignment.end,
  double spacing = 12,
}) {
  final isCompact = _isCompactClientLayout(context);
  return Flex(
    direction: isCompact ? Axis.vertical : Axis.horizontal,
    crossAxisAlignment:
        isCompact ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
    mainAxisAlignment: isCompact ? MainAxisAlignment.start : mainAxisAlignment,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (isCompact) SizedBox(width: double.infinity, child: children[i]) else children[i],
        if (i != children.length - 1)
          SizedBox(width: isCompact ? 0 : spacing, height: isCompact ? spacing : 0),
      ],
    ],
  );
}

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
  bool _canManageBilling = false;
  String? _loadError;

  final String baseUrl = AppConfig.backendBaseUrl;

  bool _isCompactWidth(double width) => width < 760;

  bool _isDesktopTableWidth(double width) => width >= 1180;

  double get _mobileTableWidth => _canManageBilling ? 1240 : 1080;

  Future<Map<String, String>> _authHeaders() async {
    final username = await SessionService.getLoggedInUsername();
    final firmName = await SessionService.getFirmName();
    return {'X-Username': username, 'X-Firm-Name': firmName};
  }

  Future<Uri> _authorizedUri(String path) async {
    final username = await SessionService.getLoggedInUsername();
    final firmName = await SessionService.getFirmName();
    return Uri.parse("$baseUrl$path").replace(
      queryParameters: {'username': username, 'firm_name': firmName},
    );
  }

  @override
  void initState() {
    super.initState();
    SessionService.canManageBilling().then((value) {
      if (!mounted) return;
      setState(() {
        _canManageBilling = value;
      });
    });
    fetchClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchClients() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _loadError = null;
      });
    }

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
      } else {
        setState(() {
          isLoading = false;
          _loadError = 'Failed to load clients (${response.statusCode}).';
        });
      }
    } catch (e) {
      print("Error fetching clients: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _loadError = 'Unable to load clients. Please check your connection.';
      });
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

  Widget _buildWhatsappIcon() {
    return SvgPicture.asset(
      'assets/icons/whatsapp.svg',
      width: 40,
      height: 40,
      fit: BoxFit.contain,
    );
  }

  String _normalizeWhatsappNumber(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return '';
    }
    if (digitsOnly.length == 10) {
      return '91$digitsOnly';
    }
    if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      return digitsOnly;
    }
    if (digitsOnly.length == 13 && digitsOnly.startsWith('091')) {
      return digitsOnly.substring(1);
    }
    return digitsOnly;
  }

  Future<void> _openWhatsappChat(Map<String, dynamic> client) async {
    final phone = _normalizeWhatsappNumber((client['phone'] ?? '').toString());
    if (phone.isEmpty) {
      _showErrorSnackBar('No phone number available for this client.');
      return;
    }

    final name = (client['name'] ?? 'Client').toString().trim();
    final message = Uri.encodeComponent('Hello $name,');
    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    _showErrorSnackBar('Could not open WhatsApp chat.');
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
                width: _isCompactClientLayout(context)
                    ? MediaQuery.sizeOf(context).width - 72
                    : 400,
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
                            final url = await _authorizedUri(
                                "/clients/${client["id"]}");
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 760;
    final topInset = MediaQuery.paddingOf(context).top;
    final mobileOverlayOffset = isMobile ? topInset + 76.0 : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 30,
            (isMobile ? 16 : 30) + mobileOverlayOffset,
            isMobile ? 16 : 30,
            isMobile ? 16 : 30,
          ),
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
            Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment:
                  isMobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
              children: [
                if (isMobile)
                  TextField(
                    controller: _searchController,
                    onChanged: _searchClient,
                    decoration: InputDecoration(
                      hintText: "Search clients...",
                      hintStyle: const TextStyle(color: Color(0xff9CA3AF)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xff4B5563),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchClient,
                      decoration: InputDecoration(
                        hintText: "Search clients...",
                        hintStyle: const TextStyle(color: Color(0xff9CA3AF)),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xff4B5563),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 12 : 0),
                SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffE0A800),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
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
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20, width: 16),

            /// Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D111827),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: _buildClientContent(isMobile: isMobile),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientContent({required bool isMobile}) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: Color(0xff94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xff64748B),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchClients,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return isMobile ? _buildMobileClientTable() : _buildDesktopClientList();
  }

  Widget _buildDesktopClientList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xffEEEEEE))),
          ),
          child: Row(
            children: [
              Expanded(
                  flex: 2,
                  child:
                      Text("Name", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text("Contact",
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 3,
                  child: Text("Case Type",
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 1,
                  child: Text("Status",
                      style: TextStyle(fontWeight: FontWeight.bold))),
              if (_canManageBilling)
                const Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.center,
                      child: Text("Payments",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    )),
              Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text("Actions",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  )),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: filteredClients.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xffF1F5F9)),
            itemBuilder: (context, index) {
              return clientRow(filteredClients[index], isMobile: false);
            },
          ),
        )
      ],
    );
  }

  Widget _buildMobileClientList() {
    if (filteredClients.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "No clients found",
            style: TextStyle(color: Color(0xff6B7280), fontSize: 16),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: filteredClients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return clientRow(filteredClients[index], isMobile: true);
      },
    );
  }

  Widget _buildMobileClientTable() {
    if (filteredClients.isEmpty) {
      return _buildMobileClientList();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: _mobileTableWidth,
              height: constraints.maxHeight - 28,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.white),
                  child: _buildDesktopClientList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget clientRow(Map<String, dynamic> client, {required bool isMobile}) {
    if (isMobile) {
      return _buildMobileClientCard(client);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Name
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                client["name"]!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xff111827),
                ),
              ),
            ),
          ),

          /// Contact
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client["email"]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff6B7280),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    client["phone"]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// Case Type
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Text(
                client["caseType"]!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff6B7280),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
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
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          if (_canManageBilling)
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.center,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Color(0xffEAB308)),
                    backgroundColor: const Color(0xffFFFBEB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => ClientPaymentsDialog(client: client),
                    ).then((_) => fetchClients());
                  },
                  icon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                  ),
                  label: const Text("Payments"),
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffE0A800),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
                      icon:
                          const Icon(Icons.send, color: Colors.black, size: 18),
                      label: const Text(
                        "Send Update",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Open WhatsApp',
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _openWhatsappChat(client),
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          child: _buildWhatsappIcon(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xff6B7280),
                    ),
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

  Widget _buildMobileClientCard(Map<String, dynamic> client) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client["name"]!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xff111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      client["email"]!,
                      style: const TextStyle(
                        color: Color(0xff6B7280),
                        fontSize: 14,
                      ),
                    ),
                    if ((client["phone"] ?? "").toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        client["phone"]!,
                        style: const TextStyle(
                          color: Color(0xff9CA3AF),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xff6B7280),
                ),
                onSelected: (value) async {
                  if (value == "edit") {
                      final result = await showDialog(
                      context: context,
                      builder: (_) => EditClientDialog(client: client),
                    );
                    if (result == true) {
                      fetchClients();
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
          const SizedBox(height: 14),
          Text(
            client["caseType"]!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff6B7280),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _buildStatusChip(client),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffE0A800),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                label: const Text(
                  "Send Update",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_canManageBilling)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Color(0xffEAB308)),
                    backgroundColor: const Color(0xffFFFBEB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => ClientPaymentsDialog(client: client),
                    ).then((_) => fetchClients());
                  },
                  icon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                  ),
                  label: const Text("Payments"),
                ),
              Tooltip(
                message: 'Open WhatsApp',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _openWhatsappChat(client),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Center(child: _buildWhatsappIcon()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> client) {
    return PopupMenuButton<String>(
      onSelected: (newStatus) async {
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
            fetchClients();
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      final firmName = await SessionService.getFirmName();
      final response = await http.put(
        Uri.parse("$baseUrl/clients/${widget.client["id"]}").replace(
            queryParameters: {'username': username, 'firm_name': firmName}),
        headers: {
          "Content-Type": "application/json",
          "X-Username": username,
          "X-Firm-Name": firmName,
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
    final dialogWidth = MediaQuery.of(context).size.width < 600
        ? MediaQuery.of(context).size.width - 32
        : 520.0;
    final isCompact = _isCompactClientLayout(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and close button
                Flex(
                  direction: isCompact ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: isCompact
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Edit Client",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      width: isCompact ? 0 : 12,
                      height: isCompact ? 8 : 0,
                    ),
                    Align(
                      alignment: isCompact
                          ? Alignment.centerRight
                          : Alignment.center,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
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
                _buildResponsiveFieldsRow(
                  context,
                  first: TextFormField(
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
                  second: TextFormField(
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

                _buildResponsiveFieldsRow(
                  context,
                  first: TextFormField(
                    controller: _panNumberController,
                    decoration: InputDecoration(
                      labelText: "PAN Number",
                      hintText: "e.g. ABCDE1234F",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  second: TextFormField(
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
                _buildResponsiveActionRow(
                  context,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
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
    final dialogWidth = MediaQuery.of(context).size.width < 600
        ? MediaQuery.of(context).size.width - 32
        : 520.0;
    final isCompact = _isCompactClientLayout(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header
              Flex(
                direction: isCompact ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: isCompact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Add New Client",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(width: isCompact ? 0 : 12, height: isCompact ? 8 : 0),
                  Align(
                    alignment: isCompact
                        ? Alignment.centerRight
                        : Alignment.center,
                    child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ),
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
              _buildResponsiveFieldsRow(
                context,
                first: TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    hintText: "email@example.com",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                second: TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: "Phone",
                    hintText: "+91 98765 43210",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
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

              _buildResponsiveFieldsRow(
                context,
                first: TextField(
                  controller: panNumberController,
                  decoration: InputDecoration(
                    labelText: "PAN Number",
                    hintText: "e.g. ABCDE1234F",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                second: TextField(
                  controller: aadharNumberController,
                  decoration: InputDecoration(
                    labelText: "Aadhar Number",
                    hintText: "Enter Aadhar number",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
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
              _buildResponsiveActionRow(
                context,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel")),
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
                      final firmName = await SessionService.getFirmName();
                      final response = await http.post(
                        Uri.parse("${AppConfig.backendBaseUrl}/clients/")
                            .replace(queryParameters: {
                          'username': username,
                          'firm_name': firmName
                        }),
                        headers: {
                          "Content-Type": "application/json",
                          "X-Username": username,
                          "X-Firm-Name": firmName,
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
    final firmName = await SessionService.getFirmName();
    return {'X-Username': username, 'X-Firm-Name': firmName};
  }

  Future<Uri> _authorizedUri(String path) async {
    final username = await SessionService.getLoggedInUsername();
    final firmName = await SessionService.getFirmName();
    return Uri.parse("$baseUrl$path").replace(
      queryParameters: {'username': username, 'firm_name': firmName},
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
                width: _isCompactClientLayout(context)
                    ? MediaQuery.sizeOf(context).width - 72
                    : 360,
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
    final dialogWidth = MediaQuery.of(context).size.width < 900
        ? MediaQuery.of(context).size.width - 24
        : 820.0;
    final dialogHeight = MediaQuery.of(context).size.height < 700
        ? MediaQuery.of(context).size.height - 24
        : 620.0;
    final isCompact = _isCompactClientLayout(context, 760);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(24),
        child: isLoading
            ? const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 40),
                        child: Column(
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
                            const SizedBox(height: 16),
                            SizedBox(
                              width: isCompact ? double.infinity : null,
                              child: ElevatedButton.icon(
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
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: isCompact ? dialogWidth - 48 : (dialogWidth - 72) / 3,
                        child: _summaryTile(
                          "Total Fee",
                          _currentTotalFee(),
                          onEdit: isUpdatingFee ? null : _editTotalFee,
                          showProgress: isUpdatingFee,
                        ),
                      ),
                      SizedBox(
                        width: isCompact ? dialogWidth - 48 : (dialogWidth - 72) / 3,
                        child: _summaryTile(
                          "Received",
                          data?["summary"]?["total_received"] ?? 0,
                        ),
                      ),
                      SizedBox(
                        width: isCompact ? dialogWidth - 48 : (dialogWidth - 72) / 3,
                        child: _summaryTile(
                          "Pending",
                          data?["summary"]?["pending_amount"] ?? 0,
                        ),
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
                          separatorBuilder: (_, __) =>
                              isCompact
                                  ? const SizedBox(height: 10)
                                  : const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final payment = Map<String, dynamic>.from(
                              payments[index],
                            );
                            final mobileDetails = [
                              payment["payment_date"] ?? "",
                              payment["payment_mode"] ?? "",
                              payment["notes"] ?? "",
                            ]
                                .where(
                                  (item) => item.toString().trim().isNotEmpty,
                                )
                                .join("  •  ");

                            if (isCompact) {
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xffE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(
                                        0xffE0A800,
                                      ).withOpacity(0.18),
                                      child: const Icon(
                                        Icons.payments_outlined,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatCurrency(payment["amount"]),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (mobileDetails.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              mobileDetails,
                                              style: const TextStyle(
                                                color: Color(0xff475569),
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: "Delete payment",
                                      onPressed: () async {
                                        try {
                                          await _deletePayment(
                                            payment["id"] as int,
                                          );
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "Unable to delete payment: $e",
                                                ),
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
                                  ],
                                ),
                              );
                            }
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
                                ]
                                    .where((item) =>
                                        item.toString().trim().isNotEmpty)
                                    .join("  •  "),
                              ),
                              trailing: IconButton(
                                tooltip: "Delete payment",
                                onPressed: () async {
                                  try {
                                    await _deletePayment(payment["id"] as int);
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              "Unable to delete payment: $e"),
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
      final firmName = await SessionService.getFirmName();
      final response = await http.post(
        Uri.parse("${AppConfig.backendBaseUrl}/payments/").replace(
          queryParameters: {'username': username, 'firm_name': firmName},
        ),
        headers: {
          "Content-Type": "application/json",
          "X-Username": username,
          "X-Firm-Name": firmName,
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
    final dialogWidth = MediaQuery.of(context).size.width < 560
        ? MediaQuery.of(context).size.width - 32
        : 480.0;
    final isCompact = _isCompactClientLayout(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
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
            Flex(
              direction: isCompact ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: isCompact
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.center,
              children: [
                if (isCompact)
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Payment Date",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                else
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
                SizedBox(width: isCompact ? 0 : 12, height: isCompact ? 12 : 0),
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
            _buildResponsiveActionRow(
              context,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
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

  @override
  void dispose() {
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> sendUpdate() async {
    if (subjectController.text.isEmpty || messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subject and message required")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final mailUri = Uri(
        scheme: 'mailto',
        path: widget.clientEmail,
        queryParameters: {
          'subject': subjectController.text.trim(),
          'body': messageController.text.trim(),
        },
      );
      final launched = await launchUrl(
        mailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      if (launched) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No email app was available to open this draft."),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to open email draft: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.of(context).size.width < 580
        ? MediaQuery.of(context).size.width - 32
        : 500.0;
    final isCompact = _isCompactClientLayout(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header
            Flex(
              direction: isCompact ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: isCompact
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Send Update to ${widget.clientName}",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(width: isCompact ? 0 : 12, height: isCompact ? 8 : 0),
                Align(
                  alignment:
                      isCompact ? Alignment.centerRight : Alignment.center,
                  child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ),
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
            _buildResponsiveActionRow(
              context,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
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

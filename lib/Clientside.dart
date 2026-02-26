import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  final String baseUrl = "http://127.0.0.1:5000";

  @override
  void initState() {
    super.initState();
    fetchClients();
  }

  Future<void> fetchClients() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/clients/"));

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);

        setState(() {
          clients = data
              .map((e) => {
                    "id": e["id"],
                    "name": e["name"],
                    "email": e["email"],
                    "phone": e["phone"] ?? "",
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
      Uri.parse("$baseUrl/clients/${client["id"]}"),
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
                                Uri.parse("$baseUrl/clients/${client["id"]}");
                            final response = await http.put(
                              url,
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({
                                "name": client["name"],
                                "email": client["email"],
                                "phone": client["phone"],
                                "case_type": client["caseType"],
                                "status": client["status"],
                                "notes": notesController.text,
                              }),
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
                              flex: 2,
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
                Text(client["email"]!,
                    style: const TextStyle(color: Colors.grey)),
                Text(client["phone"]!,
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          /// Case Type
          Expanded(
            flex: 2,
            child: Text(client["caseType"]!,
                style: const TextStyle(color: Colors.grey)),
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
                  final url = Uri.parse("$baseUrl/clients/$clientId");

                  try {
                    final response = await http.put(
                      url,
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode({
                        "name": client["name"],
                        "email": client["email"],
                        "phone": client["phone"],
                        "case_type": client["caseType"],
                        "status": newStatus, // new status
                      }),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffE0A800),
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
                const SizedBox(width: 8),

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
  late String _selectedCaseType;
  late String _selectedStatus;
  late TextEditingController _notesController;

  final String baseUrl = "http://127.0.0.1:5000";

  // Case type options (same as AddClientDialog)
  final List<String> _caseTypes = [
    "Property Dispute",
    "Rental Agreement",
    "Criminal Defense",
    "Finance",
    "Sale Deed",
  ];

  late List<String>
      _availableCaseTypes; // To include current value if not in list

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _nameController = TextEditingController(text: client["name"]);
    _emailController = TextEditingController(text: client["email"]);
    _phoneController = TextEditingController(text: client["phone"]);
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
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final response = await http.put(
        Uri.parse("$baseUrl/clients/${widget.client["id"]}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": _nameController.text,
          "email": _emailController.text,
          "phone": _phoneController.text,
          "case_type": _selectedCaseType,
          "status": _selectedStatus,
          "notes": _notesController.text,
        }),
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

                // Case Type Dropdown (with same options as AddClientDialog)
                DropdownButtonFormField<String>(
                  value: _selectedCaseType,
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
  final notesController = TextEditingController();

  String selectedCaseType = "Property Dispute";

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

              /// Case Type
              DropdownButtonFormField<String>(
                value: selectedCaseType,
                decoration: InputDecoration(
                  labelText: "Case Type",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  "Property Dispute",
                  "Rental Agreement",
                  "Criminal Defense",
                  "Finance",
                  "Sale Deed"
                ]
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

                      final response = await http.post(
                        Uri.parse("http://127.0.0.1:5000/clients/"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({
                          "name": nameController.text,
                          "email": emailController.text,
                          "phone": phoneController.text,
                          "case_type": selectedCaseType,
                          "status": "Active",
                          "notes": notesController.text,
                        }),
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
        Uri.parse("http://127.0.0.1:5000/send-update"),
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

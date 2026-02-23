import 'package:flutter/material.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, String>> clients = [
    {
      "name": "Rajesh Sharma",
      "email": "rajesh@email.com",
      "phone": "+91 98765 43210",
      "case": "Property Dispute",
      "status": "Active"
    },
    {
      "name": "Priya Patel",
      "email": "priya@email.com",
      "phone": "+91 87654 32109",
      "case": "Rental Agreement",
      "status": "Active"
    },
    {
      "name": "Amit Kumar",
      "email": "amit@email.com",
      "phone": "+91 76543 21098",
      "case": "Criminal Defense",
      "status": "Pending"
    },
    {
      "name": "Sunita Verma",
      "email": "sunita@email.com",
      "phone": "+91 65432 10987",
      "case": "Finance",
      "status": "Closed"
    },
    {
      "name": "Vikram Singh",
      "email": "vikram@email.com",
      "phone": "+91 54321 09876",
      "case": "Sale Deed",
      "status": "Active"
    },
  ];

  List<Map<String, String>> filteredClients = [];

  @override
  void initState() {
    super.initState();
    filteredClients = clients;
  }

  void _searchClient(String query) {
    setState(() {
      filteredClients = clients
          .where((client) =>
              client["name"]!.toLowerCase().contains(query.toLowerCase()) ||
              client["email"]!.toLowerCase().contains(query.toLowerCase()) ||
              client["case"]!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Color _statusColor(String status) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F6F9),
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Clients",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Manage your clients and their cases",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffE6A817),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text(
                  "Add Client",
                  style: TextStyle(color: Colors.black),
                ),
              )
            ],
          ),

          const SizedBox(height: 25),

          /// Search Bar
          SizedBox(
            width: 400,
            child: TextField(
              controller: _searchController,
              onChanged: _searchClient,
              decoration: InputDecoration(
                hintText: "Search clients...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          /// Table Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  /// Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text("Name",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 2,
                            child: Text("Contact",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 2,
                            child: Text("Case Type",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            child: Text("Status",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 40),
                      ],
                    ),
                  ),

                  /// Table Rows
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = filteredClients[index];

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 20),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  client["name"]!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(client["email"]!,
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(client["phone"]!,
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(client["case"]!),
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _statusColor(client["status"]!)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    client["status"]!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: _statusColor(client["status"]!),
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              const Icon(Icons.more_vert, color: Colors.grey),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

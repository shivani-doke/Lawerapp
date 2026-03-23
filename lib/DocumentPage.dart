import 'package:flutter/material.dart';
import 'SaleDeedPage.dart';
import 'RentalAgreementPage.dart';
import 'PowerOfAttorneyPage.dart';
import 'PartnershipDeedPage.dart';

class DocumentsPage extends StatefulWidget {
  final Function(int)? onNavigate;

  const DocumentsPage({super.key, this.onNavigate});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  String selectedCategory = "All";
  String searchQuery = ""; // ✅ New state for search

  final List<String> categories = [
    "All",
    "Property",
    "Deed",
    "Business",
    "Legal",
    "Estate",
    "Criminal",
    "Finance",
  ];

  final List<Map<String, String>> documents = [
    {
      "title": "Sale Deed",
      "category": "Property",
      "description":
          "Transfer of property ownership from seller to buyer with all legal stipulations."
    },
    {
      "title": "Rental Agreement",
      "category": "Property",
      "description":
          "Legally binding lease agreement between landlord and tenant."
    },
    {
      "title": "Power of Attorney",
      "category": "Deed",
      "description":
          "Authorization document granting legal authority to act on behalf of another."
    },
    {
      "title": "Partnership Deed",
      "category": "Business",
      "description":
          "Agreement defining terms and conditions of a business partnership."
    },
    {
      "title": "Affidavit",
      "category": "Legal",
      "description":
          "Sworn written statement confirmed by oath for use as evidence in court."
    },
    {
      "title": "Will & Testament",
      "category": "Estate",
      "description":
          "Legal declaration of how a person's assets should be distributed after death."
    },
    {
      "title": "Bail Application",
      "category": "Criminal",
      "description":
          "Application to the court seeking release of an accused on bail."
    },
    {
      "title": "Loan Agreement",
      "category": "Finance",
      "description":
          "Contract between borrower and lender specifying loan terms and repayment."
    },
  ];

  @override
  Widget build(BuildContext context) {
    // 🔍 Filter documents by category AND search query
    final filteredDocs = documents.where((doc) {
      // Category filter
      final matchesCategory =
          selectedCategory == "All" || doc["category"] == selectedCategory;

      // Search filter (case‑insensitive, checks title and description)
      final matchesSearch = searchQuery.isEmpty ||
          doc["title"]!.toLowerCase().contains(searchQuery.toLowerCase()) ||
          doc["description"]!.toLowerCase().contains(searchQuery.toLowerCase());

      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FB),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Document Templates",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Create legal documents using AI-powered templates",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                // ElevatedButton.icon(
                //   onPressed: () {},
                //   icon: const Icon(Icons.add, size: 18),
                //   label: const Text("New Document"),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: const Color(0xffE0A800),
                //     padding: const EdgeInsets.symmetric(
                //         horizontal: 20, vertical: 14),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(10),
                //     ),
                //   ),
                // )
              ],
            ),

            const SizedBox(height: 30),

            /// Search Bar
            TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value; // ✅ Update search state
                });
              },
              decoration: InputDecoration(
                hintText: "Search templates...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            searchQuery = "";
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Category Chips
            Wrap(
              spacing: 10,
              children: categories.map((category) {
                final isSelected = selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      selectedCategory = category;
                    });
                  },
                  selectedColor: const Color(0xff0F172A),
                  backgroundColor: Colors.grey.shade200,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 25),

            /// Grid Documents
            Expanded(
              child: filteredDocs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No documents found",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Try a different search term or category",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      itemCount: filteredDocs.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, // Change to 3 if smaller screen
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 1.3,
                      ),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        return documentCard(doc);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget documentCard(Map<String, String> doc) {
    return InkWell(
      onTap: () {
        switch (doc["title"]) {
          case "Sale Deed":
            widget.onNavigate?.call(4);
            break;
          case "Rental Agreement":
            widget.onNavigate?.call(5);
            break;
          case "Power of Attorney":
            widget.onNavigate?.call(6);
            break;
          case "Partnership Deed":
            widget.onNavigate?.call(7);
            break;
          case "Affidavit":
            widget.onNavigate?.call(8);
            break;
          case "Will & Testament":
            widget.onNavigate?.call(9);
            break;
          case "Bail Application":
            widget.onNavigate?.call(10);
            break;
          case "Loan Agreement":
            widget.onNavigate?.call(11);
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.description_outlined, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Text(
              doc["title"]!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              doc["category"]!.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xffE0A800),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              doc["description"]!,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

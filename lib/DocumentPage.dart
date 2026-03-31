import 'package:flutter/material.dart';
import 'GiftDeedPage.dart';
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
      "title": "Gift Deed",
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
    {
      "title": "Divorce Paper",
      "category": "Legal",
      "description":
          "Petition or mutual consent document capturing marriage, separation, and settlement details."
    },
    {
      "title": "Sale Deed",
      "category": "Property",
      "description":
          "Document for sale and transfer of ownership rights in an immovable property."
    },
    {
      "title": "Mortgage Deed",
      "category": "Property",
      "description":
          "Security document creating mortgage rights over property against a loan."
    },
    {
      "title": "Non-Disclosure Agreement (NDA)",
      "category": "Business",
      "description":
          "Confidentiality agreement restricting disclosure and misuse of sensitive information."
    },
    {
      "title": "Employment Contract",
      "category": "Business",
      "description":
          "Contract defining role, compensation, terms, and obligations between employer and employee."
    },
    {
      "title": "Offer Letter",
      "category": "Business",
      "description":
          "Formal offer of employment including designation, compensation, and joining conditions."
    },
    {
      "title": "Service Agreement",
      "category": "Business",
      "description":
          "Agreement for delivery of services, timelines, fees, and responsibilities."
    },
    {
      "title": "Child Custody Agreement",
      "category": "Legal",
      "description":
          "Agreement defining legal and physical custody, visitation, and child support terms."
    },
    {
      "title": "Adoption Papers",
      "category": "Legal",
      "description":
          "Documents for legal adoption process including consent, guardianship, and court details."
    },
    {
      "title": "Partition Deed",
      "category": "Property",
      "description":
          "Deed for partition of jointly held property among co-owners/heirs."
    },
    {
      "title": "Trust Deed",
      "category": "Estate",
      "description":
          "Document creating a trust and defining settlor, trustees, beneficiaries, and trust terms."
    },
    {
      "title": "Memorandum of Understanding (MOU)",
      "category": "Business",
      "description":
          "Preliminary agreement recording shared understanding, intent, roles, and key commercial terms."
    },
    {
      "title": "Vendor Agreement",
      "category": "Business",
      "description":
          "Agreement between company and vendor for supply terms, pricing, SLAs, and obligations."
    },
    {
      "title": "Non-Compete Agreement",
      "category": "Business",
      "description":
          "Restrictive covenant preventing competitive activity for a defined scope, geography, and duration."
    },
    {
      "title": "Indemnity Agreement",
      "category": "Legal",
      "description":
          "Contract where one party agrees to compensate the other for specified losses or liabilities."
    },
    {
      "title": "Joint Venture Agreement",
      "category": "Business",
      "description":
          "Agreement between parties for a specific joint business project, contributions, and profit sharing."
    },
    {
      "title": "Licensing Agreement",
      "category": "Business",
      "description":
          "Contract granting rights to use intellectual property under agreed scope and royalty terms."
    },
    {
      "title": "Assignment Agreement",
      "category": "Legal",
      "description":
          "Agreement transferring rights, title, or obligations from one party to another."
    },
    {
      "title": "Settlement Agreement",
      "category": "Legal",
      "description":
          "Agreement resolving disputes and recording final obligations, payments, and release terms."
    },
    {
      "title": "Trademark Application",
      "category": "Legal",
      "description":
          "Application details for trademark registration including mark, class, applicant, and usage."
    },
    {
      "title": "Copyright Agreement",
      "category": "Legal",
      "description":
          "Agreement defining ownership, assignment, licensing, or usage rights of copyrighted work."
    },
    {
      "title": "Patent Filing Documents",
      "category": "Legal",
      "description":
          "Patent filing details including invention summary, claims, inventors, and applicant information."
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
                        childAspectRatio: 1.15,
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
          case "Gift Deed":
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
          case "Divorce Paper":
            widget.onNavigate?.call(12);
            break;
          case "Sale Deed":
            widget.onNavigate?.call(13);
            break;
          case "Mortgage Deed":
            widget.onNavigate?.call(14);
            break;
          case "Non-Disclosure Agreement (NDA)":
            widget.onNavigate?.call(15);
            break;
          case "Employment Contract":
            widget.onNavigate?.call(16);
            break;
          case "Offer Letter":
            widget.onNavigate?.call(17);
            break;
          case "Service Agreement":
            widget.onNavigate?.call(18);
            break;
          case "Child Custody Agreement":
            widget.onNavigate?.call(19);
            break;
          case "Adoption Papers":
            widget.onNavigate?.call(20);
            break;
          case "Partition Deed":
            widget.onNavigate?.call(21);
            break;
          case "Trust Deed":
            widget.onNavigate?.call(22);
            break;
          case "Memorandum of Understanding (MOU)":
            widget.onNavigate?.call(23);
            break;
          case "Vendor Agreement":
            widget.onNavigate?.call(24);
            break;
          case "Non-Compete Agreement":
            widget.onNavigate?.call(25);
            break;
          case "Indemnity Agreement":
            widget.onNavigate?.call(26);
            break;
          case "Joint Venture Agreement":
            widget.onNavigate?.call(27);
            break;
          case "Licensing Agreement":
            widget.onNavigate?.call(28);
            break;
          case "Assignment Agreement":
            widget.onNavigate?.call(29);
            break;
          case "Settlement Agreement":
            widget.onNavigate?.call(30);
            break;
          case "Trademark Application":
            widget.onNavigate?.call(31);
            break;
          case "Copyright Agreement":
            widget.onNavigate?.call(32);
            break;
          case "Patent Filing Documents":
            widget.onNavigate?.call(33);
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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



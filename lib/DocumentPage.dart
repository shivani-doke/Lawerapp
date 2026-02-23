import 'package:flutter/material.dart';

class Document {
  final String title;
  final String category;
  final String description;

  Document(this.title, this.category, this.description);
}

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  String selectedCategory = "All";

  final List<String> categories = [
    "All",
    "Property",
    "Deed",
    "Business",
    "Legal",
    "Estate",
    "Criminal",
    "Finance"
  ];

  final List<Document> documents = [
    Document("Sale Deed", "Property",
        "Transfer of property ownership from seller to buyer."),
    Document("Rental Agreement", "Property",
        "Legally binding lease agreement."),
    Document("Power of Attorney", "Deed",
        "Authorization document granting authority."),
    Document("Partnership Deed", "Business",
        "Agreement defining business partnership."),
    Document("Affidavit", "Legal",
        "Sworn written statement."),
    Document("Will & Testament", "Estate",
        "Declaration of asset distribution."),
    Document("Bail Application", "Criminal",
        "Application for bail."),
    Document("Loan Agreement", "Finance",
        "Contract specifying loan terms."),
  ];

  @override
  Widget build(BuildContext context) {
    List<Document> filteredDocs = selectedCategory == "All"
        ? documents
        : documents
            .where((doc) => doc.category == selectedCategory)
            .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Document Templates",
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {},
                child: const Text("+ New Document"),
              )
            ],
          ),
          const SizedBox(height: 20),

          /// Category Buttons
          Wrap(
            spacing: 10,
            children: categories.map((category) {
              return ChoiceChip(
                label: Text(category),
                selected: selectedCategory == category,
                onSelected: (_) {
                  setState(() {
                    selectedCategory = category;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          /// Document Cards Grid
          Expanded(
            child: GridView.builder(
              itemCount: filteredDocs.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.4,
              ),
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description,
                          size: 40, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text(
                        doc.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        doc.category.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        doc.description,
                        style: const TextStyle(
                            color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

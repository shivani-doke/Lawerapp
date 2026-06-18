import 'package:flutter/material.dart';
import 'upload_context.dart';

class UploadsPage extends StatelessWidget {
  final Function(int)? onNavigate;

  const UploadsPage({super.key, this.onNavigate});

  static const List<Map<String, dynamic>> uploadTargets = [
    {"title": "Gift Deed", "pageIndex": 4, "documentType": "gift_deed"},
    {
      "title": "Rental Agreement",
      "pageIndex": 5,
      "documentType": "rental_agreement",
    },
    {
      "title": "Power of Attorney",
      "pageIndex": 6,
      "documentType": "power_of_attorney",
    },
    {
      "title": "Partnership Deed",
      "pageIndex": 7,
      "documentType": "partnership_deed",
    },
    {"title": "Affidavit", "pageIndex": 8, "documentType": "affidavit"},
    {
      "title": "Will & Testament",
      "pageIndex": 9,
      "documentType": "will_and_testament",
    },
    {
      "title": "Bail Application",
      "pageIndex": 10,
      "documentType": "bail_application",
    },
    {
      "title": "Loan Agreement",
      "pageIndex": 11,
      "documentType": "loan_agreement",
    },
    {
      "title": "Divorce Paper",
      "pageIndex": 12,
      "documentType": "divorce_paper",
    },
    {
      "title": "Sale Deed",
      "pageIndex": 13,
      "documentType": "sale_deed",
    },
    {
      "title": "Mortgage Deed",
      "pageIndex": 14,
      "documentType": "mortgage_deed",
    },
    {
      "title": "Non-Disclosure Agreement (NDA)",
      "pageIndex": 15,
      "documentType": "non_disclosure_agreement",
    },
    {
      "title": "Employment Contract",
      "pageIndex": 16,
      "documentType": "employment_contract",
    },
    {
      "title": "Offer Letter",
      "pageIndex": 17,
      "documentType": "offer_letter",
    },
    {
      "title": "Service Agreement",
      "pageIndex": 18,
      "documentType": "service_agreement",
    },
    {
      "title": "Child Custody Agreement",
      "pageIndex": 19,
      "documentType": "child_custody_agreement",
    },
    {
      "title": "Adoption Papers",
      "pageIndex": 20,
      "documentType": "adoption_papers",
    },
    {
      "title": "Partition Deed",
      "pageIndex": 21,
      "documentType": "partition_deed",
    },
    {
      "title": "Trust Deed",
      "pageIndex": 22,
      "documentType": "trust_deed",
    },
    {
      "title": "Memorandum of Understanding (MOU)",
      "pageIndex": 23,
      "documentType": "memorandum_of_understanding",
    },
    {
      "title": "Vendor Agreement",
      "pageIndex": 24,
      "documentType": "vendor_agreement",
    },
    {
      "title": "Non-Compete Agreement",
      "pageIndex": 25,
      "documentType": "non_compete_agreement",
    },
    {
      "title": "Indemnity Agreement",
      "pageIndex": 26,
      "documentType": "indemnity_agreement",
    },
    {
      "title": "Joint Venture Agreement",
      "pageIndex": 27,
      "documentType": "joint_venture_agreement",
    },
    {
      "title": "Licensing Agreement",
      "pageIndex": 28,
      "documentType": "licensing_agreement",
    },
    {
      "title": "Assignment Agreement",
      "pageIndex": 29,
      "documentType": "assignment_agreement",
    },
    {
      "title": "Settlement Agreement",
      "pageIndex": 30,
      "documentType": "settlement_agreement",
    },
    {
      "title": "Trademark Application",
      "pageIndex": 31,
      "documentType": "trademark_application",
    },
    {
      "title": "Copyright Agreement",
      "pageIndex": 32,
      "documentType": "copyright_agreement",
    },
    {
      "title": "Patent Filing Documents",
      "pageIndex": 33,
      "documentType": "patent_filing_documents",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;
          final pagePadding = isCompact ? 16.0 : 30.0;

          return Padding(
            padding: EdgeInsets.all(pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Uploads",
                  style: TextStyle(
                    fontSize: isCompact ? 24 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Choose a document type to add a reference document",
                  style: TextStyle(
                    fontSize: isCompact ? 13 : 14,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: isCompact ? 18 : 24),
                Expanded(
                  child: ListView.separated(
                    itemCount: uploadTargets.length,
                    separatorBuilder: (_, __) => SizedBox(height: isCompact ? 10 : 12),
                    itemBuilder: (context, index) {
                      final item = uploadTargets[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          UploadNavigationContext.openReferenceOnly(
                            item["documentType"] as String,
                          );
                          onNavigate?.call(item["pageIndex"] as int);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 14 : 16,
                            vertical: isCompact ? 12 : 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isCompact ? 9 : 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.upload_file_outlined,
                                  color: Colors.black54,
                                ),
                              ),
                              SizedBox(width: isCompact ? 12 : 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item["title"] as String,
                                      maxLines: isCompact ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isCompact ? 15 : 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "Add Reference Document",
                                      style: TextStyle(
                                        fontSize: isCompact ? 12 : 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.black45,
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
          );
        },
      ),
    );
  }
}



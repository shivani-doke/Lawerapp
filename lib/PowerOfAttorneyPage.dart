import 'package:flutter/material.dart';

class PowerOfAttorneyPage extends StatefulWidget {
  const PowerOfAttorneyPage({super.key});

  @override
  State<PowerOfAttorneyPage> createState() => _PowerOfAttorneyPageState();
}

class _PowerOfAttorneyPageState extends State<PowerOfAttorneyPage> {
  final TextEditingController principalController = TextEditingController();
  final TextEditingController agentController = TextEditingController();
  final TextEditingController purposeController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController conditionsController = TextEditingController();

  @override
  void dispose() {
    principalController.dispose();
    agentController.dispose();
    purposeController.dispose();
    dateController.dispose();
    conditionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xfff5f6f8),
      padding: const EdgeInsets.all(30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ================= LEFT SIDE FORM =================
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "AUTHORIZATION",
                      style: TextStyle(
                        color: Color(0xffE0A800),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      "Power of Attorney",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _inputField("Principal's Full Name", principalController,
                        hint: "Person granting authority"),

                    _inputField("Agent's Full Name", agentController,
                        hint: "Person receiving authority"),

                    _multiLineField(
                        "Purpose / Scope of Authority", purposeController,
                        hint: "Describe the powers being granted..."),

                    _inputField("Date of Execution", dateController,
                        hint: "dd-mm-yyyy"),

                    _multiLineField(
                        "Conditions & Limitations", conditionsController,
                        hint: "Any restrictions on the authority..."),

                    const SizedBox(height: 20),

                    /// ===== ADD REFERENCE DOCUMENT BUTTON =====
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement document attachment
                        },
                        icon: const Icon(Icons.attach_file),
                        label: const Text("Add Reference Document"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(
                              color: Color(0xffE0A800), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: const Color(0xffE0A800),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    /// ===== GENERATE DOCUMENT BUTTON =====
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Integrate AI generation
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text("Generate Document with AI"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffE0A800),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 30),

          /// ================= RIGHT SIDE PREVIEW =================
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              height: 700,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 50, color: Colors.grey),
                    SizedBox(height: 20),
                    Text(
                      "Ready to Generate",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Fill in the details on the left, then click\n\"Generate Document with AI\" to create your Power of Attorney.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xfff9fafb),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _multiLineField(String label, TextEditingController controller,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xfff9fafb),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

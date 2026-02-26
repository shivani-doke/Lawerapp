import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LegalAIPage extends StatefulWidget {
  const LegalAIPage({super.key});

  @override
  State<LegalAIPage> createState() => _LegalAIPageState();
}

class _LegalAIPageState extends State<LegalAIPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  final String apiKey = "AIzaSyCZ24GzxkB3_UkOepNjHHbeEPyfgo2R5QA";

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ================= SAVE HISTORY =================

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("chat_history", jsonEncode(_messages));
  }

  // ================= LOAD HISTORY =================

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString("chat_history");

    if (saved != null) {
      final List decoded = jsonDecode(saved);
      setState(() {
        _messages.addAll(
          decoded.map((e) => Map<String, String>.from(e)).toList(),
        );
      });
    }
  }

  // ================= SEND MESSAGE =================

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isLoading = true;
    });

    await _saveHistory();

    _controller.clear();

    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$apiKey");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "system_instruction": {
            "parts": [
              {
                "text": "You are a specialized Indian Legal Assistant. "
                    "Answer only legal questions. "
                    "When possible, base your answers on Indian legal news and case law. "
                    "Prefer referencing these sources: "
                    "barandbench.com, verdictum.in, scconline.com, and livemint.com. "
                    "If relevant, mention the source name in your answer like: "
                    "'As reported by Bar & Bench...' or "
                    "'According to SCC Online...'. "
                    "If no specific case reference is available, clearly state that it is a general legal explanation."
              }
            ]
          },
          "contents": [
            {
              "parts": [
                {"text": text}
              ]
            }
          ]
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final aiReply =
            data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"];

        setState(() {
          _messages.add({"role": "ai", "text": aiReply ?? "No response"});
        });

        await _saveHistory();
      } else {
        setState(() {
          _messages.add({
            "role": "ai",
            "text": "ERROR ${response.statusCode}\n${response.body}"
          });
        });

        await _saveHistory();
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "ai", "text": "NETWORK ERROR: $e"});
      });

      await _saveHistory();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: _buildChatArea(),
    );
  }

  // =================== CHAT AREA ===================

  Widget _buildChatArea() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _messages.isEmpty ? _buildWelcome() : _buildMessages(),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.centerLeft,
      child: const Text(
        "Legal AI Assistant",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1F2A44),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            "How can I help you today?",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Ask me about legal documents, case law, procedures, or let me draft agreements for you.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: [
              _suggestionCard(
                  "Draft a rental agreement for a residential property in Mumbai"),
              _suggestionCard("What are the key clauses in a sale deed?"),
              _suggestionCard(
                  "Explain Section 138 of the Negotiable Instruments Act"),
              _suggestionCard("Help me prepare a power of attorney document"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionCard(String text) {
    return InkWell(
      onTap: () => _sendMessage(text),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        bool isUser = message["role"] == "user";

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              color: isUser ? Colors.amber[200] : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(message["text"] ?? ""),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Ask about legal matters, draft documents...",
                filled: true,
                fillColor: const Color(0xFFF1F3F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(),
            ),
          )
        ],
      ),
    );
  }
}

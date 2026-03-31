import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'config/app_config.dart';

class LegalAIPage extends StatefulWidget {
  const LegalAIPage({super.key});

  @override
  State<LegalAIPage> createState() => _LegalAIPageState();
}

class _LegalAIPageState extends State<LegalAIPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = []; // Now includes timestamp
  bool _isLoading = false;

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        "role": "user",
        "text": text,
        "timestamp": DateTime.now(),
      });
      _isLoading = true;
    });
    _scrollToBottom();

    _controller.clear();

    final url = Uri.parse("${AppConfig.backendBaseUrl}/legal-ai");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": text}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final aiReply = data["reply"];

        setState(() {
          _messages.add({
            "role": "ai",
            "text": aiReply ?? "No response",
            "timestamp": DateTime.now(),
          });
        });
        _scrollToBottom();
      } else {
        setState(() {
          _messages.add({
            "role": "ai",
            "text": "ERROR ${response.statusCode}",
            "timestamp": DateTime.now(),
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "ai",
          "text": "NETWORK ERROR: $e",
          "timestamp": DateTime.now(),
        });
      });
      _scrollToBottom();
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _messages.isEmpty ? _buildWelcome() : _buildMessages(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // =================== HEADER ===================
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

  // =================== EMPTY CHAT (WELCOME) ===================
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
            "Ask me about Indian laws, recent court rulings, legal procedures, and updates from trusted legal sources.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: [
              _suggestionCard("Recent legal updates from Indian courts"),
              _suggestionCard(
                  "Summarize the recent judgement from Supreme Court Cases Online"),
              _suggestionCard(
                  "Explain Section 138 of the Negotiable Instruments Act"),
              _suggestionCard("Explain the recent High Court ruling in India"),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "Powered by trusted legal sources ",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // =================== SUGGESTION CARD (Interactive) ===================
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
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  // =================== MESSAGES LIST ===================
  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading indicator at the end
        if (_isLoading && index == _messages.length) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFF1F2A44),
                    child: Icon(Icons.gavel, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TypingIndicator(),
                  ),
                ],
              ),
            ),
          );
        }

        final message = _messages[index];
        final bool isUser = message["role"] == "user";
        final timestamp = message["timestamp"] as DateTime;

        // User messages: no avatar
        if (isUser) {
          Widget messageContent = Container(
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.amber[300],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(message["text"] ?? ""),
                const SizedBox(height: 5),
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );

          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: messageContent,
            ),
          );
        }

        // AI messages: with avatar
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF1F2A44),
                    child: Icon(Icons.gavel, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(
                            data: message["text"] ?? "",
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(fontSize: 14),
                              strong:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // 👇 COPY BUTTON BELOW MESSAGE
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: message["text"]),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Copied")),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            _formatTimestamp(timestamp),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      // Today: show time
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else {
      // Different day: show date + time
      return "${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Ask a legal question...",
                filled: true,
                fillColor: const Color(0xFFF1F3F6),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: Colors.amber,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}

// =================== TYPING INDICATOR (Animated Dots) ===================
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Analyzing"),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final int dotCount = ((_controller.value * 3).floor() % 3) + 1;
            return Text(
              "." * dotCount,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            );
          },
        ),
      ],
    );
  }
}

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class LegalAIPage extends StatefulWidget {
//   const LegalAIPage({super.key});

//   @override
//   State<LegalAIPage> createState() => _LegalAIPageState();
// }

// class _LegalAIPageState extends State<LegalAIPage> {
//   final TextEditingController _controller = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final List<Map<String, String>> _messages = [];
//   bool _isLoading = false;

//   final String apiKey = "AIzaSyBUqS5Cu_pK8nqNbvgG5HsQuxNGqDji1G4";

//   Future<void> _sendMessage([String? quickText]) async {
//     final text = quickText ?? _controller.text.trim();
//     if (text.isEmpty) return;

//     setState(() {
//       _messages.add({"role": "user", "text": text});
//       _isLoading = true;
//     });

//     _controller.clear();

//     final url = Uri.parse(
//         "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$apiKey");

//     try {
//       final response = await http.post(
//         url,
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "system_instruction": {
//             "parts": [
//               {
//                 "text": "You are a specialized Indian Legal Assistant. "
//                     "Answer only legal questions. "
//                     "When possible, base your answers on Indian legal news and case law. "
//                     "Prefer referencing these sources: "
//                     "barandbench.com, verdictum.in, scconline.com, and livemint.com. "
//                     "If relevant, mention the source name in your answer like: "
//                     "'As reported by Bar & Bench...' or "
//                     "'According to SCC Online...'. "
//                     "If no specific case reference is available, clearly state that it is a general legal explanation."
//               }
//             ]
//           },
//           "contents": [
//             {
//               "parts": [
//                 {"text": text}
//               ]
//             }
//           ]
//         }),
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200) {
//         final aiReply =
//             data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"];

//         setState(() {
//           _messages.add({"role": "ai", "text": aiReply ?? "No response"});
//         });
//       } else {
//         setState(() {
//           _messages.add({"role": "ai", "text": "ERROR ${response.statusCode}"});
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _messages.add({"role": "ai", "text": "NETWORK ERROR: $e"});
//       });
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF4F6F9),
//       body: _buildChatArea(),
//     );
//   }

//   // =================== CHAT AREA ===================

//   Widget _buildChatArea() {
//     return Column(
//       children: [
//         _buildHeader(),
//         Expanded(
//           child: _messages.isEmpty ? _buildWelcome() : _buildMessages(),
//         ),
//         _buildInputBar(),
//       ],
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       alignment: Alignment.centerLeft,
//       child: const Text(
//         "Legal AI Assistant",
//         style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//       ),
//     );
//   }

//   Widget _buildWelcome() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: const BoxDecoration(
//               color: Color(0xFF1F2A44),
//               shape: BoxShape.circle,
//             ),
//             child:
//                 const Icon(Icons.auto_awesome, color: Colors.amber, size: 40),
//           ),
//           const SizedBox(height: 20),
//           const Text(
//             "How can I help you today?",
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 10),
//           const Text(
//             "Ask me about legal documents, case law, procedures, or let me draft agreements for you.",
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.grey),
//           ),
//           const SizedBox(height: 30),
//           Wrap(
//             spacing: 15,
//             runSpacing: 15,
//             children: [
//               _suggestionCard(
//                   "Draft a rental agreement for a residential property in Mumbai"),
//               _suggestionCard("What are the key clauses in a gift deed?"),
//               _suggestionCard(
//                   "Explain Section 138 of the Negotiable Instruments Act"),
//               _suggestionCard("Help me prepare a power of attorney document"),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _suggestionCard(String text) {
//     return InkWell(
//       onTap: () => _sendMessage(text),
//       child: Container(
//         width: 300,
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.grey.shade300),
//         ),
//         child: Text(text),
//       ),
//     );
//   }

//   Widget _buildMessages() {
//     return ListView.builder(
//       padding: const EdgeInsets.all(20),
//       itemCount: _messages.length,
//       itemBuilder: (context, index) {
//         final message = _messages[index];
//         bool isUser = message["role"] == "user";

//         return Align(
//           alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
//           child: Container(
//             margin: const EdgeInsets.symmetric(vertical: 6),
//             padding: const EdgeInsets.all(14),
//             constraints: const BoxConstraints(maxWidth: 600),
//             decoration: BoxDecoration(
//               color: isUser ? Colors.amber[200] : Colors.white,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Text(message["text"] ?? ""),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInputBar() {
//     return Container(
//       padding: const EdgeInsets.all(15),
//       color: Colors.white,
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               controller: _controller,
//               decoration: InputDecoration(
//                 hintText: "Ask about legal matters, draft documents...",
//                 filled: true,
//                 fillColor: const Color(0xFFF1F3F6),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(30),
//                   borderSide: BorderSide.none,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Container(
//             decoration: const BoxDecoration(
//               color: Colors.amber,
//               shape: BoxShape.circle,
//             ),
//             child: IconButton(
//               icon: const Icon(Icons.send, color: Colors.white),
//               onPressed: () => _sendMessage(),
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }



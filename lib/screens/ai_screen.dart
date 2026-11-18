import 'package:flutter/material.dart';

import '../services/gemini_service.dart';
import '../theme/app_theme.dart';

/// AI Dost: the in-app AI helper. Works offline with built-in answers
/// when no Gemini key is supplied; with a key (via --dart-define) it
/// answers via Gemini. Never invents hadith references — see the prompt
/// in gemini_service.dart.
class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text':
          'Assalamu Alaikum! I am the AI Friend. Ask me about Prayer, Zakat, Fasting, Wudu or the Quran.',
    },
  ];
  bool _busy = false;

  static const _chips = ['What is Zakat?', 'Prayer times?', 'How to perform Wudu?', 'What is fasting?'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _busy) return;
    setState(() {
      _messages.add({'role': 'user', 'text': q});
      _busy = true;
    });
    _controller.clear();
    final answer = await GeminiService.ask(q);
    if (mounted) {
      setState(() {
        _messages.add({'role': 'ai', 'text': answer});
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                GeminiService.hasKey ? Icons.check_circle : Icons.info,
                color: GeminiService.hasKey ? Colors.green : AppTheme.gold,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  GeminiService.hasKey
                      ? 'Gemini connected — AI Friend is online.'
                      : 'Offline mode — no Gemini key set (see README).',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              final isUser = m['role'] == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppTheme.emerald
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    m['text'] ?? '',
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: _chips.map((c) {
              return ActionChip(
                label: Text(c),
                onPressed: () => _send(c),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Type your question...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _send,
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: () => _send(_controller.text),
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

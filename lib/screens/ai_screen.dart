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
          'Assalamu Alaikum! I am your AI Friend. Ask me about prayer, fasting, Zakat, or daily duas — or tap a suggestion below.',
    },
  ];
  bool _busy = false;

  static const _chips = ['What is Zakat?', 'How do I pray Fajr?', 'Dua for travelling'];

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    final chipBg = isDark ? AppTheme.chipDark : AppTheme.chipLight;
    final cardLine = isDark ? AppTheme.cardLineDark : AppTheme.cardLineLight;
    final card = isDark ? AppTheme.nightCard : AppTheme.cardLight;
    final userBubble = isDark ? AppTheme.emeraldLight : AppTheme.emerald;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Icon(
                GeminiService.hasKey ? Icons.check_circle : Icons.info,
                color: GeminiService.hasKey ? userBubble : gold,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  GeminiService.hasKey
                      ? 'Gemini connected — AI Friend is online.'
                      : 'Offline mode — no Gemini key set (see README).',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              final isUser = m['role'] == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? userBubble : card,
                    borderRadius: BorderRadius.circular(16),
                    border: isUser
                        ? null
                        : Border.all(color: cardLine, width: 1),
                    boxShadow: isUser ? null : [AppTheme.cardShadow(isDark)],
                  ),
                  child: Text(
                    m['text'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser ? const Color(0xFFF7F1E3) : ink,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircularProgressIndicator(color: gold),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _chips.map((c) {
              return ActionChip(
                label: Text(
                  c,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                backgroundColor: chipBg,
                side: BorderSide(color: cardLine, width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.chipRadius,
                  ),
                ),
                onPressed: () => _send(c),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: ink),
                  decoration: InputDecoration(
                    hintText: 'Type your question...',
                    hintStyle: TextStyle(color: muted),
                    filled: true,
                    fillColor: chipBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.buttonRadius,
                      ),
                      borderSide: BorderSide(color: cardLine),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.buttonRadius,
                      ),
                      borderSide: BorderSide(color: cardLine),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.buttonRadius,
                      ),
                      borderSide: BorderSide(color: gold, width: 1.5),
                    ),
                  ),
                  onSubmitted: _send,
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                backgroundColor: gold,
                foregroundColor: const Color(0xFF1A2E28),
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

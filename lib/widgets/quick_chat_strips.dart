import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickChatStrips extends StatelessWidget {
  final Function(String) onSelect;

  const QuickChatStrips({Key? key, required this.onSelect}) : super(key: key);

  static const List<Map<String, dynamic>> _categories = [
    {'label': '💡 Random Fact', 'prompt': 'Tell me an interesting random fact I probably don\'t know.'},
    {'label': '🎭 Personality', 'prompt': 'Give me a short personality quiz question.'},
    {'label': '🧘 Motivation', 'prompt': 'I need some motivation for today. What should I focus on?'},
    {'label': '🚀 Future Tech', 'prompt': 'What is the most exciting technology being developed right now?'},
    {'label': '🏛️ History', 'prompt': 'Tell me a fascinating story from ancient history.'},
    {'label': '🍳 Quick Recipe', 'prompt': 'Suggest a healthy snack I can make in 5 minutes.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            "Spark a Conversation:",
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ActionChip(
                  label: Text(cat['label']),
                  labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500),
                  onPressed: () => onSelect(cat['prompt']),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

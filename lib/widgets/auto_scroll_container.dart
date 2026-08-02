import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// A curated list of short, impactful quotes.
final List<Map<String, String>> inspirationalQuotes = [
  {'quote': 'The only way to do great work is to love what you do.', 'author': 'Steve Jobs'},
  {'quote': 'Believe you can and you’re halfway there.', 'author': 'Theodore Roosevelt'},
  {'quote': 'The future belongs to those who believe in the beauty of their dreams.', 'author': 'Eleanor Roosevelt'},
  {'quote': 'Strive not to be a success, but rather to be of value.', 'author': 'Albert Einstein'},
  {'quote': 'The secret of getting ahead is getting started.', 'author': 'Mark Twain'},
  {'quote': 'Your time is limited, don’t waste it living someone else’s life.', 'author': 'Steve Jobs'},
  {'quote': 'The mind is everything. What you think you become.', 'author': 'Buddha'},
  {'quote': 'The best way to predict the future is to create it.', 'author': 'Peter Drucker'},
];

class InspirationalQuoteCard extends StatefulWidget {
  final String nickname;

  const InspirationalQuoteCard({super.key, required this.nickname});

  @override
  State<InspirationalQuoteCard> createState() => _InspirationalQuoteCardState();
}

class _InspirationalQuoteCardState extends State<InspirationalQuoteCard> {
  late final Map<String, String> _selectedQuote;

  @override
  void initState() {
    super.initState();
    // Select a random quote once when the widget is initialized.
    _selectedQuote = inspirationalQuotes[Random().nextInt(inspirationalQuotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey[850]!.withValues(alpha: 0.9) : Colors.white;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final accentColor = Theme.of(context).colorScheme.secondary; // AccentPink

    final greeting = widget.nickname.isNotEmpty ? 'Hello, ${widget.nickname}' : 'Welcome!';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            greeting,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote, color: accentColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedQuote['quote']!,
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: textColor.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '— ${_selectedQuote['author']}',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

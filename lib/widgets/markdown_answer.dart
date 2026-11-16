import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders an AI answer with proper headings, bold text, lists and links
/// instead of raw `**` and `#` symbols.
class MarkdownAnswer extends StatelessWidget {
  final String data;
  final Color? textColor;
  final double fontSize;

  const MarkdownAnswer({
    super.key,
    required this.data,
    this.textColor,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = textColor ?? theme.colorScheme.onSurface;
    final body = theme.textTheme.bodyLarge?.copyWith(
          fontSize: fontSize,
          height: 1.55,
          color: color,
        ) ??
        TextStyle(fontSize: fontSize, height: 1.55, color: color);

    return MarkdownBody(
      data: data,
      selectable: true,
      onTapLink: (text, href, title) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: body,
        listBullet: body,
        strong: body.copyWith(fontWeight: FontWeight.bold),
        em: body.copyWith(fontStyle: FontStyle.italic),
        h1: body.copyWith(fontSize: fontSize + 6, fontWeight: FontWeight.bold),
        h2: body.copyWith(fontSize: fontSize + 4, fontWeight: FontWeight.bold),
        h3: body.copyWith(fontSize: fontSize + 2, fontWeight: FontWeight.bold),
        h4: body.copyWith(fontWeight: FontWeight.bold),
        a: body.copyWith(
          color: theme.colorScheme.secondary,
          decoration: TextDecoration.underline,
        ),
        code: body.copyWith(
          fontFamily: 'monospace',
          fontSize: fontSize - 2,
          backgroundColor: color.withValues(alpha: 0.08),
        ),
        codeblockDecoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.secondary, width: 3),
          ),
        ),
        blockSpacing: 10,
      ),
    );
  }
}

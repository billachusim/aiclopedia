import 'package:ai_clopedia/services/assets_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/answer_utils.dart';
import 'markdown_answer.dart';
import 'report_ai_content.dart';

class ChatWidget extends StatelessWidget {
  const ChatWidget(
      {super.key, required this.msg, required this.chatIndex, this.prompt});

  final String msg;
  final String? prompt;
  final int chatIndex;

  bool get _isUser => chatIndex == 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bubbleColor = _isUser
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.onSurface.withValues(alpha: 0.05);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            _isUser ? AssetsManager.userImage : "assets/images/aiclopedia.png",
            height: 30,
            width: 30,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isUser
                  ? SelectableText(
                      msg,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownAnswer(data: msg.trim(), fontSize: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Copy',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.copy_rounded,
                                  size: 18,
                                  color: scheme.onSurface.withValues(alpha: 0.6)),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(
                                    text: AnswerUtils.plainText(msg)));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Answer copied.')),
                                  );
                                }
                              },
                            ),
                            ReportAiContentButton(
                              contentType: 'chat_reply',
                              content: msg,
                              prompt: prompt,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

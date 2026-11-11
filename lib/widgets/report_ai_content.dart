import 'package:flutter/material.dart';

import '../services/firebase_services.dart';

/// Reasons a user can pick when flagging AI-generated content.
const List<String> kAiReportReasons = [
  'Offensive or hateful',
  'Sexual or inappropriate',
  'Violent or dangerous',
  'Harassment or bullying',
  'False or misleading',
  'Other',
];

/// Opens an in-app dialog that lets the user report or flag offensive
/// AI-generated content without leaving the app.
Future<void> showReportAiContentDialog(
  BuildContext context, {
  required String contentType,
  required String content,
  String? prompt,
  String? questionId,
}) async {
  String? selected;
  final detailsController = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Report AI content'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Tell us what is wrong with this AI-generated content. '
                  'Reports are reviewed by our team and used to improve our filters.'),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) => setState(() => selected = v),
                child: Column(
                  children: kAiReportReasons
                      .map((r) => RadioListTile<String>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(r),
                            value: r,
                          ))
                      .toList(),
                ),
              ),
              TextField(
                controller: detailsController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Add details (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed:
                selected == null ? null : () => Navigator.of(ctx).pop(true),
            child: const Text('Submit report'),
          ),
        ],
      ),
    ),
  );

  final details = detailsController.text.trim();
  detailsController.dispose();
  if (submitted != true || selected == null) return;

  final ok = await FirebaseServices().reportAiContent(
    contentType: contentType,
    content: content,
    reason: selected!,
    prompt: prompt,
    questionId: questionId,
    details: details.isEmpty ? null : details,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(ok
        ? 'Thanks. Your report was sent and will be reviewed.'
        : 'Could not send report. Please try again.'),
  ));
}

/// A small flag button that opens [showReportAiContentDialog].
class ReportAiContentButton extends StatelessWidget {
  const ReportAiContentButton({
    super.key,
    required this.contentType,
    required this.content,
    this.prompt,
    this.questionId,
    this.color,
    this.withLabel = false,
  });

  final String contentType;
  final String content;
  final String? prompt;
  final String? questionId;
  final Color? color;
  final bool withLabel;

  void _open(BuildContext context) => showReportAiContentDialog(
        context,
        contentType: contentType,
        content: content,
        prompt: prompt,
        questionId: questionId,
      );

  @override
  Widget build(BuildContext context) {
    if (withLabel) {
      return TextButton.icon(
        onPressed: () => _open(context),
        icon: Icon(Icons.flag_outlined, size: 18, color: color),
        label: Text('Report', style: TextStyle(color: color)),
      );
    }
    return IconButton(
      tooltip: 'Report AI content',
      onPressed: () => _open(context),
      icon: Icon(Icons.flag_outlined, color: color),
    );
  }
}

/// Helpers for telling real AI answers apart from placeholders and errors
/// that older app versions saved into the `answer` field.
class AnswerUtils {
  AnswerUtils._();

  static const List<String> _badMarkers = [
    'tap open to load answer',
    'ai model is currently unavailable',
    'failed to generate answer',
    "couldn't generate an answer",
    "couldn't answer right now",
    'firebase_functions/',
    'ai services unavailable',
    'ai quota exhausted',
    'ai service error',
    'unable to load',
  ];

  /// True when [answer] is a real answer worth showing and caching.
  static bool isUsable(String? answer) {
    if (answer == null) return false;
    final text = answer.trim();
    if (text.length < 2) return false;
    final lower = text.toLowerCase();
    if (lower.startsWith('⚠️') || lower.startsWith('error:')) return false;
    for (final marker in _badMarkers) {
      if (lower.contains(marker)) return false;
    }
    return true;
  }

  /// Plain-text preview of a markdown answer, for cards and share text.
  static String plainText(String markdown) {
    var text = markdown;
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
    text = text.replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1) ?? '');
    text = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ');
    text = text.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');
    text = text.replaceAll(RegExp(r'(\*\*|__|\*|_|`|~~)'), '');
    text = text.replaceAll(RegExp(r'\n{2,}'), '\n');
    return text.trim();
  }

  /// Image URLs that are known to be dead or meaningless.
  static bool isUsableImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.contains('oaidalleapiprodscus.blob.core.windows.net')) return false;
    if (lower.contains('picsum.photos')) return false;
    return lower.startsWith('http');
  }
}

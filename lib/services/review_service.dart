import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks happy users for a store rating at a good moment: after a thumbs-up,
/// or after their third successful answer. Asks at most once every 60 days,
/// and the stores also apply their own limits.
class ReviewService {
  ReviewService._();

  static final instance = ReviewService._();

  static const _goodAnswersKey = 'review_good_answers';
  static const _lastAskedKey = 'review_last_asked_ms';
  static const int _answersBeforeAsking = 3;
  static const Duration _cooldown = Duration(days: 60);

  Future<void> recordGoodAnswer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_goodAnswersKey) ?? 0) + 1;
      await prefs.setInt(_goodAnswersKey, count);
      if (count >= _answersBeforeAsking) await _maybeAsk(prefs);
    } catch (_) {}
  }

  Future<void> recordThumbsUp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _maybeAsk(prefs);
    } catch (_) {}
  }

  Future<void> _maybeAsk(SharedPreferences prefs) async {
    final last = prefs.getInt(_lastAskedKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last < _cooldown.inMilliseconds) return;
    final review = InAppReview.instance;
    if (!await review.isAvailable()) return;
    await prefs.setInt(_lastAskedKey, now);
    await review.requestReview();
  }
}

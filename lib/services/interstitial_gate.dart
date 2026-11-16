/// Caps how often full-screen ads appear, so leaving a question or a chat
/// doesn't trigger an ad every single time (a common cause of 1-star reviews).
class InterstitialGate {
  InterstitialGate._();

  static final instance = InterstitialGate._();

  /// Show at most one interstitial per this many eligible exits...
  static const int everyNthExit = 3;

  /// ...and never more often than this.
  static const Duration minGap = Duration(minutes: 3);

  int _exits = 0;
  DateTime? _lastShown;

  bool shouldShow() {
    _exits++;
    final now = DateTime.now();
    final gapOk = _lastShown == null || now.difference(_lastShown!) >= minGap;
    if (_exits >= everyNthExit && gapOk) {
      _exits = 0;
      _lastShown = now;
      return true;
    }
    return false;
  }
}

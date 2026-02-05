import 'package:rxdart/rxdart.dart';

/// A global class to hold application-wide streams or state.
class App {
  /// A stream that widgets can listen to.
  /// When a value is added to this stream, it signals that the feed
  /// should be refreshed to reflect changes (e.g., a hidden or blocked post).
  static final BehaviorSubject<bool> refreshFeed = BehaviorSubject<bool>();
}

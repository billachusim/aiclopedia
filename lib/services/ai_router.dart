import 'ai_exceptions.dart';
import 'gemini_service.dart';

class AIRouter {

  /// Later you can route based on:
  /// - cost
  /// - speed
  /// - user tier
  /// - prompt type
  /// - load balancing

  static Future<String> routeMessage(String message) async {

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        return await GeminiService.sendMessage(message);
      } catch (_) {
        if (attempt == 1) rethrow;
      }
    }

    throw AIModelUnavailableException();
  }

}

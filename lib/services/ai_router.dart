import 'ai_exceptions.dart';
import 'gemini_service.dart';
import 'api_service.dart';

class AIRouter {
  /// Orchestrates message routing between available AI services.
  /// Currently tries GeminiService (Primary) and falls back to ApiService.
  static Future<String> routeMessage(String message) async {
    // Attempt 1: GeminiService
    try {
      return await GeminiService.sendMessage(message);
    } catch (e) {
      print("GeminiService failed, attempting fallback to ApiService: $e");
    }

    // Attempt 2: ApiService (as fallback)
    try {
      final fallbackResponse = await ApiService.sendMessage(message: message);
      if (fallbackResponse.isNotEmpty) {
        return fallbackResponse.first.msg;
      }
    } catch (e) {
      print("ApiService also failed: $e");
    }

    throw AIModelUnavailableException();
  }
}

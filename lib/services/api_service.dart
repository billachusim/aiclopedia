import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_model.dart';

class ApiService {
  static const String _apiKey = 'AIzaSyAtMEiuNYGVQta2Zw7G_Ci8YfdXbr0cm1M';

  static Future<List<ChatModel>> sendMessage({
    required String message,
  }) async {
    try {
      log("Sending message to Gemini: $message");

      final model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: _apiKey,
      );

      final response = await model.generateContent([
        Content.text(message),
      ]).timeout(const Duration(seconds: 30));

      log("Gemini raw response: ${response.text}");

      if (response.text == null || response.text!.isEmpty) {
        throw Exception("Empty response from AI.");
      }

      return [
        ChatModel(
          msg: response.text!,
          chatIndex: 1,
        ),
      ];
    } catch (e, stack) {
      log("GEMINI ERROR: $e");
      log("STACK: $stack");

      throw Exception(
        'AI failed to respond.\n\nPossible causes:\n'
            '• Invalid API key\n'
            '• Unsupported model\n'
            '• No internet\n'
            '• Gemini quota exceeded',
      );
    }
  }
}
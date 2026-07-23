import 'dart:async';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_exceptions.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<String> sendMessage(String message) async {
    try {
      log("GEMINI → $message");

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final response = await model
          .generateContent([Content.text(message)])
          .timeout(const Duration(seconds: 25));

      final text = response.text;

      if (text == null || text.isEmpty) {
        throw AIModelUnavailableException();
      }

      return text;
    } on TimeoutException {
      throw AITimeoutException();
    } catch (e) {
      log("Gemini crash: $e");
      throw AIModelUnavailableException();
    }
  }
}

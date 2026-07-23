import 'dart:async';
import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_exceptions.dart';

class GeminiService {
  static const _apiKey = 'AIzaSyDVrKrbOSUQJ8zv81ZaeXus4wwSviRpb-I';

  static final GenerativeModel _model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: _apiKey,
  );

  static Future<String> sendMessage(String message) async {
    try {
      log("GEMINI → $message");

      final response = await _model
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

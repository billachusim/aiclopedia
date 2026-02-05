import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_model.dart';

class ApiService {
  // IMPORTANT: Replace with your Gemini API Key
  static const String _apiKey = 'AIzaSyBYkSsyIuzT9fDpdKQSt8-V4gCDHnW-Yqw';

  static Future<List<ChatModel>> sendMessage({
    required String message,
    // The modelId parameter is removed to prevent conflicts.
    // We will use the correct model name directly.
  }) async {
    try {
      // --- MODIFIED: Hardcode the correct model name for text-only generation ---
      final model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);

      final content = [Content.text(message)];
      final response = await model.generateContent(content);

      if (response.text == null) {
        throw Exception("An error occurred: Received null response from API.");
      }

      List<ChatModel> chatList = [
        ChatModel(
          msg: response.text!,
          chatIndex: 1,
        ),
      ];
      return chatList;
    } catch (e) {
      log("error $e");
      // Providing a more user-friendly error message
      throw Exception('Failed to get a response from the AI. Please check your API key and network connection.');
    }
  }
}

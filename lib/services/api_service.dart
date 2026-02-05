import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_model.dart';

class ApiService {
  // IMPORTANT: Replace with your Gemini API Key
  static const String _apiKey = 'AIzaSyA_3GFziplvc1EGZqQCohZ1sxqDIwdkALA';

  static Future<List<ChatModel>> sendMessage({
    required String message,
    required String modelId, // This can be 'gemini-pro' for example
  }) async {
    try {
      log("modelId $modelId");
      final model = GenerativeModel(model: modelId, apiKey: _apiKey);
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
      rethrow;
    }
  }
}

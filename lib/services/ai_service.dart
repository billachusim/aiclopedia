import 'dart:developer';
import '../models/chat_model.dart';
import 'ai_router.dart';
import 'ai_exceptions.dart';

class AIService {
  static Future<List<ChatModel>> sendMessage({
    required String message,
  }) async {
    try {
      final response = await AIRouter.routeMessage(message);

      return [
        ChatModel(
          msg: response,
          chatIndex: 1,
        )
      ];
    }

    on AIException catch (e) {
      return [
        ChatModel(
          msg: "⚠️ ${e.message}",
          chatIndex: 1,
        )
      ];
    }

    catch (e) {
      log("AI UNKNOWN ERROR: $e");

      return [
        ChatModel(
          msg:
          "⚠️ Something went wrong.\nPlease try again.",
          chatIndex: 1,
        )
      ];
    }
  }
}

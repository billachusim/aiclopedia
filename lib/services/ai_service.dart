import 'dart:developer';
import '../models/chat_model.dart';
import 'ai_router.dart';
import 'ai_exceptions.dart';

class AIService {
  static Future<List<ChatModel>> sendMessage({
    required String message,
  }) async {
    final response = await AIRouter.routeMessage(message);

    return [
      ChatModel(
        msg: response,
        chatIndex: 1,
      )
    ];
  }
}

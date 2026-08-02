import '../models/chat_model.dart';
import 'ai_router.dart';

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

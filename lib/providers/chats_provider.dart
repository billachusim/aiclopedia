import 'package:flutter/cupertino.dart';
import '../models/chat_model.dart';
import '../services/ai_service.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatModel> chatList = [];

  List<ChatModel> get getChatList => chatList;

  void addUserMessage({required String msg}) {
    chatList.add(ChatModel(msg: msg, chatIndex: 0));
    notifyListeners();
  }

  Future<void> sendMessageAndGetAnswers({
    required String msg,
  }) async {
    try {
      final answers = await AIService.sendMessage(
        message: msg,
      );

      chatList.addAll(answers);
    } catch (e) {
      chatList.add(ChatModel(
        msg: "⚠️ Sorry, I couldn't answer right now. Please try again in a moment.",
        chatIndex: 1,
      ));
      rethrow; // Rethrow to let the UI know it failed for credit deduction
    } finally {
      notifyListeners();
    }
  }
}

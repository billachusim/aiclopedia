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

    final answers = await AIService.sendMessage(
      message: msg,
    );

    chatList.addAll(answers);

    notifyListeners();
  }

}

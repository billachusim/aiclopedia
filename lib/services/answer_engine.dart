import '../../services/firebaseServices.dart';
import 'ai_service.dart';

class AnswerEngine {
  AnswerEngine._();

  static final instance = AnswerEngine._();

  final FirebaseServices _firebase = FirebaseServices();

  /// MASTER RESOLVER
  Future<String> resolve({
    required String questionId,
    required String question,
    required String existingAnswer,
  }) async {

    // ✅ 1 — Already attached to the question object
    if (existingAnswer.isNotEmpty) {
      return existingAnswer;
    }

    // ✅ 2 — Check Firebase cache
    final cached = await _firebase.getAnswer(questionId);

    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // ✅ 3 — LAST RESORT → Generate
    final generated = await _generateAnswer(question);

    await _firebase.saveAnswer(questionId, generated);

    return generated;
  }

  Future<String> _generateAnswer(String question) async {
    final chatModels = await AIService.sendMessage(message: question);
    // chatModels[0].msg will contain the response or an error message
    return chatModels.first.msg;
  }
}

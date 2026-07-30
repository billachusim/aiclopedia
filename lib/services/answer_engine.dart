import '../../services/firebaseServices.dart';
import 'ai_service.dart';

class AnswerEngine {
  AnswerEngine._();

  static final instance = AnswerEngine._();

  final FirebaseServices _firebase = FirebaseServices();
  
  // Memory cache to avoid even Firebase reads during the same session
  final Map<String, String> _memoryCache = {};

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
    
    // ✅ 2 - Check memory cache
    if (_memoryCache.containsKey(questionId)) {
      return _memoryCache[questionId]!;
    }

    // ✅ 3 — Check Firebase cache
    final cached = await _firebase.getAnswer(questionId);

    if (cached != null && cached.isNotEmpty) {
      _memoryCache[questionId] = cached;
      return cached;
    }

    // ✅ 4 — LAST RESORT → Generate
    final generated = await _generateAnswer(question);

    if (generated.isNotEmpty && !generated.startsWith('⚠️')) {
      await _firebase.saveAnswer(questionId, generated);
      _memoryCache[questionId] = generated;
    }

    return generated;
  }

  Future<String> _generateAnswer(String question) async {
    final chatModels = await AIService.sendMessage(message: question);
    // chatModels[0].msg will contain the response or an error message
    return chatModels.first.msg;
  }
}

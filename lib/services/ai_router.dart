import 'package:cloud_functions/cloud_functions.dart';
import 'ai_exceptions.dart';

class AIRouter {
  /// Orchestrates message routing via Firebase Cloud Functions for security.
  static Future<String> routeMessage(String message) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('getAIResponse');
      final results = await callable.call(<String, dynamic>{
        'prompt': message,
      });

      final String? response = results.data['text'];
      
      if (response == null || response.isEmpty) {
        throw AIModelUnavailableException();
      }

      return response;
    } on FirebaseFunctionsException catch (e) {
      print("Cloud Function Error: ${e.code} - ${e.message}");
      throw AIException(e.message ?? "AI Service Error");
    } catch (e) {
      print("Unexpected Error calling Cloud Function: $e");
      throw AIModelUnavailableException();
    }
  }
}

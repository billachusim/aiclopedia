import 'package:cloud_functions/cloud_functions.dart';
import 'package:ai_clopedia/services/image_cache.dart';

class ImageEngine {
  ImageEngine._();

  static final instance = ImageEngine._();

  final _cache = ImageCacheService();

  Future<String> generate(String prompt) async {
    // 1️⃣ CHECK CACHE FIRST
    final cached = await _cache.get(prompt);

    if (cached != null) {
      return cached;
    }

    // 2️⃣ TRY NETWORK (Cloud Function)
    int attempts = 0;

    while (attempts < 2) {
      try {
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('generateAIImage');
        final results = await callable.call(<String, dynamic>{
          'prompt': prompt,
        });

        final String? url = results.data['url'];

        if (url == null || url.isEmpty) {
          throw Exception("No URL returned from AI");
        }

        await _cache.save(prompt, url);

        return url;
      } catch (e) {
        attempts++;

        if (attempts >= 2) {
          rethrow;
        }

        await Future.delayed(const Duration(seconds: 2));
      }
    }

    throw Exception("Image engine failure");
  }
}

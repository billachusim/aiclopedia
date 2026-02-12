import 'package:AiClopedia/services/image_cache.dart';
import 'image_repository.dart';

class ImageEngine {
  ImageEngine._();

  static final instance = ImageEngine._();

  final _repo = ImageRepository();
  final _cache = ImageCacheService();

  Future<String> generate(String prompt) async {
    // 1️⃣ CHECK CACHE FIRST
    final cached = await _cache.get(prompt);

    if (cached != null) {
      return cached;
    }

    // 2️⃣ TRY NETWORK (with retry)
    int attempts = 0;

    while (attempts < 3) {
      try {
        final url = await _repo.generate(prompt);

        await _cache.save(prompt, url);

        return url;
      } catch (e) {
        attempts++;

        if (attempts >= 3) {
          rethrow;
        }

        await Future.delayed(const Duration(seconds: 2));
      }
    }

    throw Exception("Image engine failure");
  }
}

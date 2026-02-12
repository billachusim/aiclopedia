import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;

  ImageCacheService._internal();

  final Map<String, String> _memoryCache = {};

  String _hash(String prompt) {
    return md5.convert(utf8.encode(prompt)).toString();
  }

  Future<String?> get(String prompt) async {
    final key = _hash(prompt);

    // MEMORY FIRST (super fast)
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    // DISK SECOND
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ai_img_$key.txt');

    if (await file.exists()) {
      final url = await file.readAsString();

      // hydrate memory cache
      _memoryCache[key] = url;

      return url;
    }

    return null;
  }

  Future<void> save(String prompt, String url) async {
    final key = _hash(prompt);

    _memoryCache[key] = url;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ai_img_$key.txt');

    await file.writeAsString(url);
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ai_service.dart';
import 'answer_utils.dart';
import 'firebase_services.dart';

/// Single place that resolves the answer to a saved question, used by the
/// feed cards, the details page and My Questions.
///
/// Order: memory -> on-device cache -> Firestore -> generate (only when
/// [allowGenerate] is true). Errors and placeholders are never cached.
class AnswerEngine {
  AnswerEngine._();

  static final instance = AnswerEngine._();

  static const String _prefsKey = 'answer_cache_v1';
  static const int _maxLocalEntries = 300;

  final FirebaseServices _firebase = FirebaseServices();
  final Map<String, String> _memoryCache = {};
  final Map<String, Future<String?>> _inFlight = {};
  LinkedHashMapCache? _local;

  Future<LinkedHashMapCache> _localCache() async {
    if (_local != null) return _local!;
    final prefs = await SharedPreferences.getInstance();
    _local = LinkedHashMapCache.fromJson(prefs.getString(_prefsKey));
    return _local!;
  }

  Future<void> _persistLocal() async {
    final cache = _local;
    if (cache == null) return;
    cache.trim(_maxLocalEntries);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, cache.toJson());
  }

  /// Synchronous peek, for painting a card without a frame of loading.
  String? peek(String questionId) => _memoryCache[questionId];

  /// Remember a good answer everywhere on the device.
  Future<void> remember(String questionId, String answer) async {
    if (questionId.isEmpty || !AnswerUtils.isUsable(answer)) return;
    _memoryCache[questionId] = answer;
    final cache = await _localCache();
    cache.put(questionId, answer);
    await _persistLocal();
  }

  /// Returns a cached answer (memory, device or Firestore) without calling AI.
  Future<String?> cached({
    required String questionId,
    String existingAnswer = '',
  }) async {
    if (AnswerUtils.isUsable(existingAnswer)) {
      unawaited(remember(questionId, existingAnswer));
      return existingAnswer;
    }
    if (questionId.isEmpty) return null;

    final mem = _memoryCache[questionId];
    if (mem != null) return mem;

    final cache = await _localCache();
    final local = cache.get(questionId);
    if (AnswerUtils.isUsable(local)) {
      _memoryCache[questionId] = local!;
      return local;
    }

    try {
      final remote = await _firebase.getAnswer(questionId);
      if (AnswerUtils.isUsable(remote)) {
        await remember(questionId, remote!);
        return remote;
      }
    } catch (_) {
      // Offline or permission issue: fall through.
    }
    return null;
  }

  /// Full resolver. Throws [AnswerUnavailable] when nothing could be found
  /// or generated, so callers can show a retry state instead of error text.
  Future<String> resolve({
    required String questionId,
    required String question,
    String existingAnswer = '',
    bool allowGenerate = true,
  }) async {
    final hit = await cached(questionId: questionId, existingAnswer: existingAnswer);
    if (hit != null) return hit;
    if (!allowGenerate) throw AnswerUnavailable();

    final key = questionId.isEmpty ? question : questionId;
    final future = _inFlight[key] ??= _generateAndSave(questionId, question);
    try {
      final generated = await future;
      if (generated == null) throw AnswerUnavailable();
      return generated;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<String?> _generateAndSave(String questionId, String question) async {
    try {
      final chatModels = await AIService.sendMessage(message: question);
      final generated = chatModels.first.msg;
      if (!AnswerUtils.isUsable(generated)) return null;
      if (questionId.isNotEmpty) {
        try {
          await _firebase.saveAnswer(questionId, generated);
        } catch (_) {
          // Saving is best effort; the server also fills answers.
        }
        await remember(questionId, generated);
      }
      return generated;
    } catch (_) {
      return null;
    }
  }
}

class AnswerUnavailable implements Exception {
  @override
  String toString() => "We couldn't load this answer right now.";
}

/// Tiny insertion-ordered string cache that serialises to JSON.
class LinkedHashMapCache {
  final Map<String, String> _map;

  LinkedHashMapCache(this._map);

  factory LinkedHashMapCache.fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return LinkedHashMapCache({});
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return LinkedHashMapCache(
          decoded.map((k, v) => MapEntry(k, v.toString())));
    } catch (_) {
      return LinkedHashMapCache({});
    }
  }

  String? get(String key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value; // mark as recently used
    return value;
  }

  void put(String key, String value) {
    _map.remove(key);
    _map[key] = value;
  }

  void trim(int maxEntries) {
    while (_map.length > maxEntries) {
      _map.remove(_map.keys.first);
    }
  }

  String toJson() => jsonEncode(_map);
}

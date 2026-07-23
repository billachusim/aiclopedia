import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ImageRepository {
  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<String> generate(String prompt) async {
    final uri = Uri.parse("https://api.openai.com/v1/images/generations");

    // Attempt 1: DALL-E 3 (High Quality)
    try {
      return await _makeRequest(uri, "dall-e-3", prompt, "1024x1024");
    } catch (e) {
      print("DALL-E 3 failed, falling back to DALL-E 2: $e");
    }

    // Attempt 2: DALL-E 2 (High Compatibility)
    return await _makeRequest(uri, "dall-e-2", prompt, "1024x1024");
  }

  Future<String> _makeRequest(Uri uri, String model, String prompt, String size) async {
    final response = await http
        .post(
      uri,
      headers: {
        "Authorization": "Bearer $_apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": model,
        "prompt": prompt,
        "n": 1,
        "size": size
      }),
    )
        .timeout(const Duration(seconds: 40));

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error']?['message'] ?? 'Image generation failed for $model');
    }

    return data['data'][0]['url'];
  }
}

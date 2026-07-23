import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageRepository {
  static const _apiKey = "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";

  Future<String> generate(String prompt) async {
    final uri = Uri.parse("https://api.openai.com/v1/images/generations");

    final response = await http
        .post(
      uri,
      headers: {
        "Authorization": "Bearer $_apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "dall-e-3",
        "prompt": prompt,
        "n": 1,
        "size": "1024x1024"
      }),
    )
        .timeout(const Duration(seconds: 40));

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error']?['message'] ?? 'Image generation failed');
    }

    return data['data'][0]['url'];
  }
}

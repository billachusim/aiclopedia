import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageService {

  static const String _apiKey = 'YOUR_KEY';

  static const _endpoint =
      'https://api.openai.com/v1/images/generations';

  static Future<String?> generateImage(String prompt) async {

    try {

      final response = await http
          .post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "gpt-image-1",
          "prompt": prompt,
          "size": "1024x1024"
        }),
      )
          .timeout(const Duration(seconds: 45));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {

        // gpt-image-1 returns base64
        final imageBase64 = data['data'][0]['b64_json'];

        return imageBase64;
      }

      throw Exception(data['error']?['message'] ?? 'Image generation failed');

    } catch (e) {
      throw Exception("Image generation error: $e");
    }
  }
}

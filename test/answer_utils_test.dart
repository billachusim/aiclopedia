import 'package:ai_clopedia/services/answer_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnswerUtils.isUsable', () {
    test('rejects empty, placeholders and saved errors', () {
      expect(AnswerUtils.isUsable(null), isFalse);
      expect(AnswerUtils.isUsable(''), isFalse);
      expect(AnswerUtils.isUsable('Tap open to load answer'), isFalse);
      expect(AnswerUtils.isUsable('⚠️ AI model is currently unavailable.'), isFalse);
      expect(AnswerUtils.isUsable('⚠️ Failed to generate answer. [firebase_functions/internal]'), isFalse);
    });

    test('accepts real answers', () {
      expect(AnswerUtils.isUsable('Photosynthesis is how plants make food from light.'), isTrue);
      expect(AnswerUtils.isUsable('**Lagos** is the largest city in Nigeria.'), isTrue);
    });
  });

  test('plainText strips markdown for previews', () {
    expect(
      AnswerUtils.plainText('## Title\n**Bold** and [link](https://x.y)\n- item'),
      'Title\nBold and link\n• item',
    );
  });

  test('dead image links are rejected', () {
    expect(AnswerUtils.isUsableImageUrl('https://oaidalleapiprodscus.blob.core.windows.net/a.png'), isFalse);
    expect(AnswerUtils.isUsableImageUrl('https://picsum.photos/512'), isFalse);
    expect(AnswerUtils.isUsableImageUrl('https://storage.googleapis.com/chat-gpt-for-students.appspot.com/generated_images/x.png'), isTrue);
  });
}

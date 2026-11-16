import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/answer_utils.dart';

class Question {
  final String userId;
  final String questionId;
  final String nickname;
  final String city;
  final String gender;
  final String question;
  final String answer;
  final String imageUrl;
  final int thumbsUpCount;
  final int thumbsDownCount;
  final DateTime timestamp;
  final bool isFeatured;
  final bool isPublic;

  Question({
    required this.userId,
    required this.nickname,
    required this.city,
    this.gender = 'Not specified',
    required this.question,
    required this.answer,
    required this.imageUrl,
    required this.thumbsUpCount,
    required this.thumbsDownCount,
    required this.timestamp,
    required this.isFeatured,
    required this.questionId,
    this.isPublic = true,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    // --- MODIFIED: Safely handle the timestamp ---
    DateTime parsedTimestamp;
    if (json['timestamp'] is Timestamp) {
      parsedTimestamp = (json['timestamp'] as Timestamp).toDate();
    } else {
      // If the timestamp is null or not a Timestamp, use the current time as a fallback.
      parsedTimestamp = DateTime.now();
    }

    return Question(
      userId: json['userId'] ?? '',
      nickname: json['nickname'] ?? '',
      city: json['city'] ?? json['nameOfSchool'] ?? '',
      gender: json['gender'] ?? 'Not specified',
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      thumbsUpCount: json['thumbsUpCount'] ?? 0,
      thumbsDownCount: json['thumbsDownCount'] ?? 0,
      questionId: json['questionId'] ?? '',
      timestamp: parsedTimestamp,
      isFeatured: json['isFeatured'] ?? false,
      isPublic: json['isPublic'] ?? true,
    );
  }

  Question copyWith({String? answer, String? imageUrl}) {
    return Question(
      userId: userId,
      nickname: nickname,
      city: city,
      gender: gender,
      question: question,
      answer: answer ?? this.answer,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbsUpCount: thumbsUpCount,
      thumbsDownCount: thumbsDownCount,
      timestamp: timestamp,
      isFeatured: isFeatured,
      questionId: questionId,
      isPublic: isPublic,
    );
  }

  bool get hasUsableAnswer => AnswerUtils.isUsable(answer);
}

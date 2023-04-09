import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String userId;
  final String questionId;
  final String nickname;
  final String nameOfSchool;
  final String question;
  final String answer;
  final String imageUrl;
  final DateTime timestamp;
  final bool isFeatured;

  Question({
    required this.userId,
    required this.nickname,
    required this.nameOfSchool,
    required this.question,
    required this.answer,
    required this.imageUrl,
    required this.timestamp,
    required this.isFeatured,
    required this.questionId,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      userId: json['userId'],
      nickname: json['nickname'] ?? '',
      nameOfSchool: json['nameOfSchool'] ?? '',
      question: json['question'],
      answer: json['answer'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      questionId: json['questionId'] ?? '',
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      isFeatured: json['isFeatured'] ?? false,
    );
  }
}

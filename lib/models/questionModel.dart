import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String userId;
  final String nickname;
  final String nameOfSchool;
  final String question;
  final DateTime timestamp;

  Question({
    required this.userId,
    required this.nickname,
    required this.nameOfSchool,
    required this.question,
    required this.timestamp,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      userId: json['userId'],
      nickname: json['nickname'] ?? '',
      nameOfSchool: json['nameOfSchool'] ?? '',
      question: json['question'],
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }
}

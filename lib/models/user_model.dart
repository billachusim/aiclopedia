import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String nickname;
  final String nameOfSchool;
  final int credits;
  final bool isPremium;
  final DateTime? premiumExpiryDate;
  final DateTime? timeRegistered;
  final DateTime? timeLastUnlocked;
  final String userType;
  final List<String> blockedUsers;
  final bool hasConsentedToDataSharing;

  UserModel({
    required this.userId,
    required this.nickname,
    required this.nameOfSchool,
    this.credits = 0,
    this.isPremium = false,
    this.premiumExpiryDate,
    required this.timeRegistered,
    required this.timeLastUnlocked,
    required this.userType,
    required this.blockedUsers,
    this.hasConsentedToDataSharing = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Safely parse the list of blocked users
    final blockedFromJson = json['blockedUsers'];
    final List<String> blockedList;
    if (blockedFromJson is List) {
      blockedList = List<String>.from(blockedFromJson);
    } else {
      blockedList = [];
    }

    // Helper function to safely convert Timestamps to DateTime
    DateTime? toDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return UserModel(
      userId: json['userId'] ?? '',
      nickname: json['nickname'] ?? '',
      nameOfSchool: json['nameOfSchool'] ?? '',
      credits: json['credits'] ?? 0,
      isPremium: json['isPremium'] ?? false,
      premiumExpiryDate: toDateTime(json['premiumExpiryDate']),
      timeRegistered: toDateTime(json['timeRegistered']),
      timeLastUnlocked: toDateTime(json['timeLastUnlocked']),
      userType: json['userType'] ?? 'REGULAR',
      blockedUsers: blockedList,
      hasConsentedToDataSharing: json['hasConsentedToDataSharing'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'nameOfSchool': nameOfSchool,
      'credits': credits,
      'isPremium': isPremium,
      'premiumExpiryDate': premiumExpiryDate?.toIso8601String(),
      'timeRegistered': timeRegistered?.toIso8601String(),
      'timeLastUnlocked': timeLastUnlocked?.toIso8601String(),
      'userType': userType,
      'blockedUsers': blockedUsers,
      'hasConsentedToDataSharing': hasConsentedToDataSharing,
    };
  }
}

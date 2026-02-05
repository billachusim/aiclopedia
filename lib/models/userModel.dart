class UserModel {
  final String userId;
  final String nickname;
  final String nameOfSchool;
  final String userType;
  final List<String> blockedUsers;

  UserModel({
    required this.userId,
    required this.nickname,
    required this.nameOfSchool,
    required this.userType,
    required this.blockedUsers,
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

    return UserModel(
      userId: json['userId'] ?? '',
      nickname: json['nickname'] ?? '',
      nameOfSchool: json['nameOfSchool'] ?? '',
      userType: json['userType'] ?? 'REGULAR',
      blockedUsers: blockedList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'nameOfSchool': nameOfSchool,
      'userType': userType,
      'blockedUsers': blockedUsers,
    };
  }
}

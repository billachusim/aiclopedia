class UserModel {
  final String userId;
  final String nickname;
  final String nameOfSchool;
  final String userType;

  UserModel({
    required this.userId,
    required this.nickname,
    required this.nameOfSchool,
    required this.userType,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'],
      nickname: json['nickname'] ?? '',
      nameOfSchool: json['nameOfSchool'] ?? '',
      userType: json['userType'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'nameOfSchool': nameOfSchool,
      'userType': userType,
    };
  }
}

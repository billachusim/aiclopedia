class UserModel {
  final String userId;
  final String nickname;
  final String nameOfSchool;

  UserModel({
    required this.userId,
    required this.nickname,
    required this.nameOfSchool,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'],
      nickname: json['nickname'] ?? '',
      nameOfSchool: json['nameOfSchool'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname ?? '',
      'nameOfSchool': nameOfSchool ?? '',
    };
  }
}

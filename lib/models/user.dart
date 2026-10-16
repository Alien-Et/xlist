import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

enum UserRole {
  @JsonValue(0)
  ADMIN,
  @JsonValue(1)
  GENERAL,
  @JsonValue(2)
  GUEST,
}

@JsonSerializable()
class UserModel {
  UserModel();

  int? id;
  String? username;
  String? password;
  String? basePath;
  UserRole? role; // 添加用户角色
  int? permission; // 添加权限字段

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}

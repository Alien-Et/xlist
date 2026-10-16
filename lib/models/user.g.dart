// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel()
  ..id = (json['id'] as num?)?.toInt()
  ..username = json['username'] as String?
  ..password = json['password'] as String?
  ..basePath = json['basePath'] as String?
  ..role = $enumDecodeNullable(_$UserRoleEnumMap, json['role'])
  ..permission = (json['permission'] as num?)?.toInt();

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'password': instance.password,
      'basePath': instance.basePath,
      'role': _$UserRoleEnumMap[instance.role],
      'permission': instance.permission,
    };

const _$UserRoleEnumMap = {
  UserRole.ADMIN: 0,
  UserRole.GENERAL: 1,
  UserRole.GUEST: 2,
};

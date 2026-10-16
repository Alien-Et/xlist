// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FsSearchModel _$FsSearchModelFromJson(Map<String, dynamic> json) =>
    FsSearchModel(
      name: json['name'] as String?,
      parent: json['parent'] as String?,
      isDir: json['is_dir'] as bool?,
      type: (json['type'] as num?)?.toInt(),
      size: (json['size'] as num?)?.toInt(),
      thumb: json['thumb'] as String?,
    );

Map<String, dynamic> _$FsSearchModelToJson(FsSearchModel instance) =>
    <String, dynamic>{
      'name': instance.name,
      'parent': instance.parent,
      'is_dir': instance.isDir,
      'type': instance.type,
      'size': instance.size,
      'thumb': instance.thumb,
    };

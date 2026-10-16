import 'package:json_annotation/json_annotation.dart';

part 'search.g.dart';

@JsonSerializable()
class FsSearchModel {
  FsSearchModel({
    this.name,
    this.parent,
    this.isDir,
    this.type,
    this.size,
    this.thumb,
  });

  @JsonKey(name: 'name') String? name;
  @JsonKey(name: 'parent') String? parent;
  @JsonKey(name: 'is_dir') bool? isDir;
  @JsonKey(name: 'type') int? type;
  @JsonKey(name: 'size') int? size;
  @JsonKey(name: 'thumb') String? thumb;
  
  factory FsSearchModel.fromJson(Map<String,dynamic> json) => _$FsSearchModelFromJson(json);
  Map<String, dynamic> toJson() => _$FsSearchModelToJson(this);
}

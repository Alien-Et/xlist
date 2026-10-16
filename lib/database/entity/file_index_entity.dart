import 'package:floor/floor.dart';

/// 文件索引表（浏览时自动写入，搜索先查本地索引，加快搜索并避免网络递归崩溃）
@Entity(
  tableName: 'file_index',
  indices: [
    Index(value: ['server_id']),
    Index(value: ['parent_path']),
    Index(value: ['name']),
  ],
)
class FileIndexEntity {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  @ColumnInfo(name: 'server_id')
  final int serverId;

  /// 完整路径（含文件名），如 /视频/原神.mp4
  @ColumnInfo(name: 'full_path')
  final String fullPath;

  /// 父目录路径，如 /视频
  @ColumnInfo(name: 'parent_path')
  final String parentPath;

  @ColumnInfo(name: 'name')
  final String name;

  /// 0=文件 1=目录
  @ColumnInfo(name: 'type')
  final int type;

  @ColumnInfo(name: 'size')
  final int? size;

  @ColumnInfo(name: 'modified')
  final int? modified;

  FileIndexEntity({
    this.id,
    required this.serverId,
    required this.fullPath,
    required this.parentPath,
    required this.name,
    required this.type,
    required this.size,
    required this.modified,
  });
}

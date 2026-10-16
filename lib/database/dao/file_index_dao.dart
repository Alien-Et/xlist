import 'package:floor/floor.dart';

import 'package:xlist/database/entity/index.dart';

/// 文件索引 DAO：浏览写入、搜索查询、删除/重命名/移动时同步清理
@dao
abstract class FileIndexDao {
  @insert
  Future<int> insertFileIndex(FileIndexEntity entity);

  @Query(
    'INSERT OR REPLACE INTO file_index (server_id, full_path, parent_path, name, type, size, modified) '
    'VALUES (:serverId, :fullPath, :parentPath, :name, :type, :size, :modified)',
  )
  Future<void> upsertFileIndex(
    int serverId,
    String fullPath,
    String parentPath,
    String name,
    int type,
    int size,
    int modified,
  );

  @Query(
    'INSERT OR REPLACE INTO file_index (server_id, full_path, parent_path, name, type, size, modified) '
    'VALUES (:serverId, :fullPath, :parentPath, :name, :type, :size, :modified)',
  )
  Future<void> upsertFileIndexBatch(
    int serverId,
    String fullPath,
    String parentPath,
    String name,
    int type,
    int size,
    int modified,
  );

  /// 关键词搜索（模糊匹配 name 或 full_path，限制数量避免卡顿）
  @Query(
    'SELECT * FROM file_index WHERE server_id = :serverId '
    'AND (name LIKE :like OR full_path LIKE :like) '
    'ORDER BY name LIMIT :limit',
  )
  Future<List<FileIndexEntity>> searchFileIndex(
      int serverId, String like, int limit);

  /// 删除单个索引（删除文件时）
  @Query('DELETE FROM file_index WHERE server_id = :serverId AND full_path = :fullPath')
  Future<void> deleteByFullPath(int serverId, String fullPath);

  /// 删除某目录下所有索引（删除文件夹时）
  @Query(
    'DELETE FROM file_index WHERE server_id = :serverId AND (parent_path = :parentPath OR full_path = :parentPath OR full_path LIKE :prefix)',
  )
  Future<void> deleteByDirectory(int serverId, String parentPath, String prefix);

  /// 删除某服务器全部索引（删除服务器时）
  @Query('DELETE FROM file_index WHERE server_id = :serverId')
  Future<void> deleteByServerId(int serverId);

  /// 重命名后更新路径（旧路径 → 新路径，含子项前缀）
  @Query(
    'UPDATE file_index SET full_path = REPLACE(full_path, :oldPath, :newPath), '
    'parent_path = CASE WHEN parent_path = :oldParent THEN :newParent '
    'ELSE REPLACE(parent_path, :oldPath, :newPath) END, '
    'name = CASE WHEN full_path = :newPath THEN :newName ELSE name END '
    'WHERE server_id = :serverId AND (full_path = :oldPath OR full_path LIKE :prefix)',
  )
  Future<void> renameByPath(
    int serverId,
    String oldPath,
    String newPath,
    String oldParent,
    String newParent,
    String newName,
    String prefix,
  );

  /// 移动后更新路径前缀（srcFull → dstFull）
  @Query(
    'UPDATE file_index SET full_path = REPLACE(full_path, :oldPath, :newPath), '
    'parent_path = REPLACE(parent_path, :oldPath, :newPath) '
    'WHERE server_id = :serverId AND (full_path = :oldPath OR full_path LIKE :prefix)',
  )
  Future<void> moveByPath(
    int serverId,
    String oldPath,
    String newPath,
    String prefix,
  );
}

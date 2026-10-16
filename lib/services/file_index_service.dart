import 'package:xlist/database/entity/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/services/index.dart';

/// 文件索引服务：浏览时自动写入本地索引，搜索先查索引（避免网络递归崩溃），
/// 删除/重命名/移动时同步清理索引
class FileIndexService {
  /// 浏览目录成功后写入该目录下所有文件的索引
  static Future<void> saveObjects({
    required int serverId,
    required String path,
    required List<ObjectModel> objects,
  }) async {
    try {
      final dao = IndexDatabaseService.to.database.fileIndexDao;
      final parent = path == '/' ? '' : path;
      for (final o in objects) {
        final fullPath = parent.isEmpty ? '/${o.name}' : '$parent/${o.name}';
        await dao.upsertFileIndex(
          serverId,
          fullPath,
          parent,
          o.name ?? '',
          o.isDir == true ? 1 : 0,
          o.size ?? 0,
          o.modified?.millisecondsSinceEpoch ?? 0,
        );
      }
    } catch (e) {
      // 索引失败不影响浏览
    }
  }

  /// 关键词搜索本地索引（毫秒级，替代网络递归）
  static Future<List<FileIndexEntity>> search({
    required int serverId,
    required String keyword,
    // 索引库不限量存储/查询：一次最多返回 1000 条（覆盖超大目录）
    int limit = 1000,
  }) async {
    try {
      final dao = IndexDatabaseService.to.database.fileIndexDao;
      return await dao.searchFileIndex(serverId, '%$keyword%', limit);
    } catch (e) {
      return [];
    }
  }

  /// 删除文件后清除单个索引
  static Future<void> removeFile({
    required int serverId,
    required String path,
    required String name,
  }) async {
    try {
      final dao = IndexDatabaseService.to.database.fileIndexDao;
      final fullPath =
          path.endsWith('/') ? '$path$name' : '$path/$name';
      await dao.deleteByFullPath(serverId, fullPath);
    } catch (e) {}
  }

  /// 删除文件夹后清除其下全部索引
  static Future<void> removeDirectory({
    required int serverId,
    required String path,
    required String name,
  }) async {
    try {
      final dao = IndexDatabaseService.to.database.fileIndexDao;
      final fullPath = path.endsWith('/') ? '$path$name' : '$path/$name';
      await dao.deleteByDirectory(serverId, fullPath, '$fullPath/%');
    } catch (e) {}
  }

  /// 重命名后更新索引（目录重命名时子项前缀一并更新）
  static Future<void> rename({
    required int serverId,
    required String oldPath,
    required String newPath,
    required String newName,
  }) async {
    try {
      final dao = IndexDatabaseService.to.database.fileIndexDao;
      await dao.renameByPath(
        serverId,
        oldPath,
        newPath,
        oldPath,
        newPath,
        newName,
        '$oldPath/%',
      );
    } catch (e) {}
  }
}

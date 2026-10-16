import 'package:floor/floor.dart';
import 'package:get/get.dart';

import 'package:xlist/database/index_database.dart';
import 'package:xlist/services/database_service.dart';

/// 独立文件索引数据库服务（与主持久化数据库 xlist_database.db 分开保存）
/// 索引库仅存放浏览时自动写入的文件索引，独立文件 xlist_index.db
class IndexDatabaseService extends GetxService {
  static IndexDatabaseService get to => Get.find();

  IndexDatabase? _database;
  IndexDatabase get database {
    if (_database == null) {
      throw StateError('IndexDatabase not initialized');
    }
    return _database!;
  }

  String name = 'xlist_index.db';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<IndexDatabaseService> init() async {
    try {
      for (int i = 0; i < 3; i++) {
        try {
          _database = await $FloorIndexDatabase.databaseBuilder(name).build();
          _isInitialized = true;
          break;
        } catch (e) {
          // 索引库打开失败时不影响主库，重试
        }
      }
    } catch (e) {}
    return this;
  }
}

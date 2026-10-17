import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:floor/floor.dart';
import 'package:xlist/database/database.dart';
import 'package:xlist/common/logger.dart';

// 数据库错误类型
enum DatabaseErrorType {
  INIT_ERROR,         // 初始化错误
  MIGRATION_ERROR,    // 迁移错误
  OPERATION_ERROR,    // 操作错误
  UNKNOWN_ERROR,      // 未知错误
}

// 数据库错误类
class DatabaseError {
  final DatabaseErrorType type;
  final String message;
  final dynamic originalError;

  DatabaseError(this.type, this.message, {this.originalError});

  @override
  String toString() {
    return 'DatabaseError{type: $type, message: $message}';
  }
}

class DatabaseService extends GetxService {
  static DatabaseService get to => Get.find();

  // AppDatabase
  XlistDatabase? _database;
  XlistDatabase get database {
    if (_database == null) {
      throw DatabaseError(
        DatabaseErrorType.INIT_ERROR,
        'Database not initialized',
      );
    }
    return _database!;
  }

  // Database name
  String name = 'xlist_database.db';

  // 初始化状态
  final _isInitialized = false.obs;
  bool get isInitialized => _isInitialized.value;

  // 数据库状态
  final _databaseStatus = 'NOT_INITIALIZED'.obs;
  String get databaseStatus => _databaseStatus.value;

  // 初始化尝试次数
  int _initAttempts = 0;

  // Database migration1to2
  final migration1to2 = Migration(1, 2, (database) async {
    await database.execute(
        'CREATE TABLE IF NOT EXISTS `recent` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `server_id` INTEGER NOT NULL, `path` TEXT NOT NULL, `name` TEXT NOT NULL, `type` INTEGER NOT NULL, `size` INTEGER NOT NULL, `updated_at` INTEGER NOT NULL)');
    await database.execute(
        'CREATE UNIQUE INDEX `index_recent_server_id_path_name` ON `recent` (`server_id`, `path`, `name`)');
    await database.execute(
        'CREATE INDEX `index_recent_updated_at` ON `recent` (`updated_at`)');
  });

  // Database migration2to3
  final migration2to3 = Migration(2, 3, (database) async {
    await database.execute(
        'CREATE TABLE IF NOT EXISTS `favorite` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `server_id` INTEGER NOT NULL, `path` TEXT NOT NULL, `name` TEXT NOT NULL, `type` INTEGER NOT NULL, `size` INTEGER NOT NULL, `updated_at` INTEGER NOT NULL)');
    await database.execute(
        'CREATE UNIQUE INDEX `index_favorite_server_id_path_name` ON `favorite` (`server_id`, `path`, `name`)');
    await database.execute(
        'CREATE INDEX `index_favorite_updated_at` ON `favorite` (`updated_at`)');
  });

  // Database migration4to5：recent 表新增 thumb 列（最近浏览显示缩略图）
  final migration4to5 = Migration(4, 5, (database) async {
    await database.execute(
        'ALTER TABLE `recent` ADD COLUMN `thumb` TEXT');
  });

  // Database migration3to4：新增文件索引表（浏览时写入，搜索先查索引）
  // 缺少本迁移会导致旧库（v3）升级 v4 失败 → 数据库打不开 → 服务器地址无法保存
  final migration3to4 = Migration(3, 4, (database) async {
    await database.execute(
        'CREATE TABLE IF NOT EXISTS `file_index` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `server_id` INTEGER NOT NULL, `full_path` TEXT NOT NULL, `parent_path` TEXT NOT NULL, `name` TEXT NOT NULL, `type` INTEGER NOT NULL, `size` INTEGER NOT NULL, `modified` INTEGER NOT NULL)');
    await database.execute(
        'CREATE INDEX `index_file_index_server_id` ON `file_index` (`server_id`)');
    await database.execute(
        'CREATE INDEX `index_file_index_parent_path` ON `file_index` (`parent_path`)');
    await database.execute(
        'CREATE INDEX `index_file_index_name` ON `file_index` (`name`)');
  });

  // Init
  Future<DatabaseService> init() async {
    Logger.d('Initializing DatabaseService');
    _databaseStatus.value = 'INITIALIZING';

    try {
      // 尝试打开数据库，如果失败则重试
      _initAttempts = 0;
      for (int i = 0; i < 3; i++) {
        _initAttempts = i + 1;
        try {
          Logger.d('Attempt $i: Initializing database...');
          
          // 构建数据库
          _database = await $FloorXlistDatabase
              .databaseBuilder(name)
              .addMigrations(
                  [migration1to2, migration2to3, migration3to4, migration4to5])
              .build();
          
          Logger.d('Database initialized successfully on attempt $i');
          _databaseStatus.value = 'INITIALIZED';
          _isInitialized.value = true;
          break;
        } catch (e) {
          Logger.w('Database initialization attempt $i failed: $e');
          if (i == 2) {
            // 最后一次尝试失败，抛出异常
            final error = DatabaseError(
              DatabaseErrorType.INIT_ERROR,
              'Failed to initialize database after 3 attempts',
              originalError: e,
            );
            throw error;
          }
          // 等待一段时间后重试
          Logger.d('Waiting 500ms before retry...');
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      Logger.e('Database initialization error: $e');
      _databaseStatus.value = 'INIT_FAILED';
      _isInitialized.value = false;
      _database = null;
      // 即使数据库初始化失败，也允许应用继续运行
      // 这样可以避免白屏问题
    } finally {
      // 打印初始化状态
      _printInitializationStatus();
    }

    Logger.d('DatabaseService initialization completed');
    return this;
  }

  // 打印初始化状态
  void _printInitializationStatus() {
    Logger.d('DatabaseService Initialization Status');
    Logger.d('Status: ${_databaseStatus.value}');
    Logger.d('Initialized: ${_isInitialized.value}');
    Logger.d('Attempts: $_initAttempts');
    Logger.d('Database: ${_database != null ? 'Created' : 'Null'}');
  }

  // 检查数据库是否初始化
  bool get isDatabaseInitialized => _isInitialized.value;

  // 关闭数据库
  Future<void> close() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
        _isInitialized.value = false;
        _databaseStatus.value = 'CLOSED';
        Logger.d('Database closed successfully');
      } else {
        Logger.w('Database not initialized, nothing to close');
      }
    } catch (e) {
      Logger.w('Error closing database: $e');
    }
  }

  // 重置数据库（危险操作，会删除所有数据）
  Future<void> reset() async {
    try {
      // 先关闭数据库
      await close();
      
      // 删除数据库文件
      final path = await sqfliteDatabaseFactory.getDatabasePath(name);
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
        Logger.d('Database file deleted');
      }
      
      // 重新初始化数据库
      await init();
      Logger.d('Database reset successfully');
    } catch (e) {
      Logger.e('Error resetting database: $e');
      throw DatabaseError(
        DatabaseErrorType.OPERATION_ERROR,
        'Failed to reset database',
        originalError: e,
      );
    }
  }

  // 获取数据库路径
  Future<String> getDatabasePath() async {
    try {
      return await sqfliteDatabaseFactory.getDatabasePath(name);
    } catch (e) {
      Logger.w('Error getting database path: $e');
      throw DatabaseError(
        DatabaseErrorType.OPERATION_ERROR,
        'Failed to get database path',
        originalError: e,
      );
    }
  }

  // 执行自定义 SQL
  Future<void> executeSql(String sql, [List<dynamic>? arguments]) async {
    try {
      if (!_isInitialized.value) {
        throw DatabaseError(
          DatabaseErrorType.INIT_ERROR,
          'Database not initialized',
        );
      }
      
      await _database!.database.execute(sql, arguments);
      Logger.d('SQL executed: $sql');
    } catch (e) {
      Logger.w('Error executing SQL: $e');
      throw DatabaseError(
        DatabaseErrorType.OPERATION_ERROR,
        'Failed to execute SQL',
        originalError: e,
      );
    }
  }

  // 获取数据库版本
  Future<int> getDatabaseVersion() async {
    try {
      if (!_isInitialized.value) {
        throw DatabaseError(
          DatabaseErrorType.INIT_ERROR,
          'Database not initialized',
        );
      }
      
      final result = await _database!.database.rawQuery('PRAGMA user_version');
      if (result.isNotEmpty) {
        return result.first['user_version'] as int;
      }
      return 0;
    } catch (e) {
      Logger.w('Error getting database version: $e');
      throw DatabaseError(
        DatabaseErrorType.OPERATION_ERROR,
        'Failed to get database version',
        originalError: e,
      );
    }
  }

  // 检查数据库连接
  Future<bool> checkConnection() async {
    try {
      if (!_isInitialized.value) {
        return false;
      }
      
      // 执行一个简单的查询来检查连接
      await _database!.database.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      Logger.w('Database connection check failed: $e');
      return false;
    }
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'index_database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

abstract class $IndexDatabaseBuilderContract {
  /// Adds migrations to the builder.
  $IndexDatabaseBuilderContract addMigrations(List<Migration> migrations);

  /// Adds a database [Callback] to the builder.
  $IndexDatabaseBuilderContract addCallback(Callback callback);

  /// Creates the database and initializes it.
  Future<IndexDatabase> build();
}

// ignore: avoid_classes_with_only_static_members
class $FloorIndexDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $IndexDatabaseBuilderContract databaseBuilder(String name) =>
      _$IndexDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $IndexDatabaseBuilderContract inMemoryDatabaseBuilder() =>
      _$IndexDatabaseBuilder(null);
}

class _$IndexDatabaseBuilder implements $IndexDatabaseBuilderContract {
  _$IndexDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  @override
  $IndexDatabaseBuilderContract addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  @override
  $IndexDatabaseBuilderContract addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  @override
  Future<IndexDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$IndexDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$IndexDatabase extends IndexDatabase {
  _$IndexDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  FileIndexDao? _fileIndexDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `file_index` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `server_id` INTEGER NOT NULL, `full_path` TEXT NOT NULL, `parent_path` TEXT NOT NULL, `name` TEXT NOT NULL, `type` INTEGER NOT NULL, `size` INTEGER, `modified` INTEGER)');
        await database.execute(
            'CREATE INDEX `index_file_index_server_id` ON `file_index` (`server_id`)');
        await database.execute(
            'CREATE INDEX `index_file_index_parent_path` ON `file_index` (`parent_path`)');
        await database.execute(
            'CREATE INDEX `index_file_index_name` ON `file_index` (`name`)');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  FileIndexDao get fileIndexDao {
    return _fileIndexDaoInstance ??= _$FileIndexDao(database, changeListener);
  }
}

class _$FileIndexDao extends FileIndexDao {
  _$FileIndexDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _fileIndexEntityInsertionAdapter = InsertionAdapter(
            database,
            'file_index',
            (FileIndexEntity item) => <String, Object?>{
                  'id': item.id,
                  'server_id': item.serverId,
                  'full_path': item.fullPath,
                  'parent_path': item.parentPath,
                  'name': item.name,
                  'type': item.type,
                  'size': item.size,
                  'modified': item.modified
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<FileIndexEntity> _fileIndexEntityInsertionAdapter;

  @override
  Future<void> upsertFileIndex(
    int serverId,
    String fullPath,
    String parentPath,
    String name,
    int type,
    int size,
    int modified,
  ) async {
    await _queryAdapter.queryNoReturn(
        'INSERT OR REPLACE INTO file_index (server_id, full_path, parent_path, name, type, size, modified) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)',
        arguments: [
          serverId,
          fullPath,
          parentPath,
          name,
          type,
          size,
          modified
        ]);
  }

  @override
  Future<void> upsertFileIndexBatch(
    int serverId,
    String fullPath,
    String parentPath,
    String name,
    int type,
    int size,
    int modified,
  ) async {
    await _queryAdapter.queryNoReturn(
        'INSERT OR REPLACE INTO file_index (server_id, full_path, parent_path, name, type, size, modified) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)',
        arguments: [
          serverId,
          fullPath,
          parentPath,
          name,
          type,
          size,
          modified
        ]);
  }

  @override
  Future<List<FileIndexEntity>> searchFileIndex(
    int serverId,
    String like,
    int limit,
  ) async {
    return _queryAdapter.queryList(
        'SELECT * FROM file_index WHERE server_id = ?1 AND (name LIKE ?2 OR full_path LIKE ?2) ORDER BY name LIMIT ?3',
        mapper: (Map<String, Object?> row) => FileIndexEntity(id: row['id'] as int?, serverId: row['server_id'] as int, fullPath: row['full_path'] as String, parentPath: row['parent_path'] as String, name: row['name'] as String, type: row['type'] as int, size: row['size'] as int?, modified: row['modified'] as int?),
        arguments: [serverId, like, limit]);
  }

  @override
  Future<void> deleteByFullPath(
    int serverId,
    String fullPath,
  ) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM file_index WHERE server_id = ?1 AND full_path = ?2',
        arguments: [serverId, fullPath]);
  }

  @override
  Future<void> deleteByDirectory(
    int serverId,
    String parentPath,
    String prefix,
  ) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM file_index WHERE server_id = ?1 AND (parent_path = ?2 OR full_path = ?2 OR full_path LIKE ?3)',
        arguments: [serverId, parentPath, prefix]);
  }

  @override
  Future<void> deleteByServerId(int serverId) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM file_index WHERE server_id = ?1',
        arguments: [serverId]);
  }

  @override
  Future<void> renameByPath(
    int serverId,
    String oldPath,
    String newPath,
    String oldParent,
    String newParent,
    String newName,
    String prefix,
  ) async {
    await _queryAdapter.queryNoReturn(
        'UPDATE file_index SET full_path = REPLACE(full_path, ?2, ?3), parent_path = CASE WHEN parent_path = ?4 THEN ?5 ELSE REPLACE(parent_path, ?2, ?3) END, name = CASE WHEN full_path = ?3 THEN ?6 ELSE name END WHERE server_id = ?1 AND (full_path = ?2 OR full_path LIKE ?7)',
        arguments: [
          serverId,
          oldPath,
          newPath,
          oldParent,
          newParent,
          newName,
          prefix
        ]);
  }

  @override
  Future<void> moveByPath(
    int serverId,
    String oldPath,
    String newPath,
    String prefix,
  ) async {
    await _queryAdapter.queryNoReturn(
        'UPDATE file_index SET full_path = REPLACE(full_path, ?2, ?3), parent_path = REPLACE(parent_path, ?2, ?3) WHERE server_id = ?1 AND (full_path = ?2 OR full_path LIKE ?4)',
        arguments: [serverId, oldPath, newPath, prefix]);
  }

  @override
  Future<int> insertFileIndex(FileIndexEntity entity) {
    return _fileIndexEntityInsertionAdapter.insertAndReturnId(
        entity, OnConflictStrategy.abort);
  }
}

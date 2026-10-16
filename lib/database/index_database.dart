import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'package:xlist/database/dao/index.dart';
import 'package:xlist/database/entity/index.dart';

/// 独立文件索引数据库（与主持久化数据库分开保存）
/// 仅存放浏览时自动写入的文件索引，损坏/清空不影响服务器、下载等业务数据
part 'index_database.g.dart';

@Database(version: 1, entities: [
  FileIndexEntity,
])
abstract class IndexDatabase extends FloorDatabase {
  FileIndexDao get fileIndexDao;
}

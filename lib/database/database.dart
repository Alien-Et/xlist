import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'package:xlist/database/dao/index.dart';
import 'package:xlist/database/entity/index.dart';

part 'database.g.dart'; // the generated code will be there

@Database(version: 5, entities: [
  ServerEntity,
  RecentEntity,
  DownloadEntity,
  ProgressEntity,
  FavoriteEntity,
  PasswordManagerEntity,
  FileIndexEntity,
])
abstract class XlistDatabase extends FloorDatabase {
  ServerDao get serverDao;
  RecentDao get recentDao;
  DownloadDao get downloadDao;
  ProgressDao get progressDao;
  FavoriteDao get favoriteDao;
  PasswordManagerDao get passwordManagerDao;
  FileIndexDao get fileIndexDao;
}

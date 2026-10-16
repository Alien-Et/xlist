import 'package:get_storage/get_storage.dart';

class CommonStorage {
  // 通用存储
  static final _prefBox = () => GetStorage();

  final themeMode = 'system'.val('themeMode', getBox: _prefBox);
}

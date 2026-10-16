import 'package:get/get.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';

class UserRepository {
  /// 获取用户信息
  static Future<UserModel> me() async {
    final response = await DioService.to.dio.get('/api/me');
    final userInfo = UserModel.fromJson(response.data['data']);

    // 保存用户 ID
    Get.find<UserStorage>().id.value = userInfo.id.toString();

    return userInfo;
  }
}

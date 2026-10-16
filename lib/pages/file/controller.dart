import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/services/core_service.dart';
import 'package:xlist/services/index.dart';

class FileController extends GetxController {
  final object = ObjectModel().obs;
  final userInfo = UserModel().obs; // 用户信息
  final isLoading = true.obs; // 是否正在加载

  // 获取参数
  final String path = Get.arguments['path'] ?? '';
  final String name = Get.arguments['name'] ?? '';

  late CoreService coreService;

  @override
  void onInit() async {
    super.onInit();
    coreService = CoreService.to;

    // 获取文件信息
    // 暂时使用模拟数据
    object.value = ObjectModel();
    object.value.name = name;
    object.value.type = 1;
    object.value.size = 1024 * 1024;
    object.value.rawUrl = '${path}${name}';
    userInfo.value = coreService.currentUser.value ?? UserModel(); // 获取用户信息
    isLoading.value = false;

    // 加入最近浏览（path 为父目录相对路径）
    await coreService.addToRecent(object.value, path: path);

    // 绑定进度监听
    try {
      DownloadService.to.bindBackgroundIsolate((id, status, progress) {});
    } catch (e) {
      print('Error binding background isolate: $e');
    }
  }

  /// 复制链接
  void copyLink() {
    Clipboard.setData(ClipboardData(
      text: CommonUtils.getDownloadLink(
        path,
        object: object.value,
        userInfo: userInfo.value,
      ),
    ));
    SmartDialog.showToast('toast_copy_success'.tr);
  }

  /// 下载文件（真实下载，走 FlutterDownloader）
  void download() async {
    await DownloadHelper.file(
        path, name, object.value.type ?? 0, object.value.size ?? 0);
  }

  /// 添加到收藏
  Future<void> addToFavorites() async {
    await coreService.addToFavorites(object.value, path: path);
    SmartDialog.showToast('toast_add_favorite_success'.tr);
  }

  @override
  void onClose() {
    super.onClose();

    // 取消进度监听
    try {
      DownloadService.to.unbindBackgroundIsolate();
    } catch (e) {
      print('Error unbinding background isolate: $e');
    }
  }
}

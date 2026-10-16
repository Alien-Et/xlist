import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/constants/common.dart'; // 导入 LayoutType
import 'package:xlist/services/core_service.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/database/entity/index.dart';

class DetailController extends GetxController {
  final userInfo = UserModel().obs; // 用户信息
  final objects = <ObjectModel>[].obs; // Object 数据
  final isFirstLoading = true.obs; // 是否是第一次加载
  final serverId = 0.obs;
  final sortType = 0.obs; // 排序方式
  final layoutType = LayoutType.GRID.obs; // 布局方式

  // 显示预览图
  late final isShowPreview = false.obs;

  // 获取参数
  final String path = Get.arguments['path'];
  final String name = Get.arguments['name'];

  // ScrollController
  final ScrollController scrollController = ScrollController();
  EasyRefreshController easyRefreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  // 目录密码
  String password = '';
  
  late CoreService coreService;

  @override
  void onInit() async {
    super.onInit();
    coreService = CoreService.to;

    // 获取服务器信息
    serverId.value = coreService.userStorage.serverId.value;

    // 获取设置
    sortType.value = coreService.preferencesStorage.sortType.val ?? 0;
    layoutType.value = coreService.preferencesStorage.layoutType.val ?? LayoutType.GRID;
    isShowPreview.value = coreService.preferencesStorage.isShowPreview.val ?? true;

    // 获取目录密码
    final passwordManager = await coreService.passwordManagerDao
        .findPasswordManagerByPath(serverId.value, '${path}${name}');
    if (passwordManager != null && passwordManager.isNotEmpty) {
      password = passwordManager.last.password;
    }

    // 获取用户信息
    userInfo.value = coreService.currentUser.value ?? UserModel();

    // 加载完成
    await getObjectList();
    isFirstLoading.value = false;

    // 绑定进度监听
    try {
      DownloadService.to.bindBackgroundIsolate((id, status, progress) {});
    } catch (e) {
      print('Error binding background isolate: $e');
    }
  }

  /// 获取对象列表
  Future<void> getObjectList({bool refresh = false}) async {
    try {
      await coreService.navigateToPath('${path}${name}');
      
      // 权限校验 - 这里可以添加权限检查逻辑
      
      // 排序
      final _list = CommonUtils.sortObjectList(coreService.currentObjects, sortType.value);

      objects.clear(); // 清空数据
      objects.addAll(_list);
      objects.refresh(); // 刷新数据
      // 浏览时自动写入本地文件索引（搜索先查索引，加快搜索）
      FileIndexService.saveObjects(
        serverId: Get.find<UserStorage>().serverId.value,
        path: '${path}${name}',
        objects: _list,
      );
    } catch (e) {
      print('Error getting object list: $e');
    }
  }

  @override
  void onClose() {
    super.onClose();

    // 解绑进度监听
    try {
      DownloadService.to.unbindBackgroundIsolate();
    } catch (e) {
      print('Error unbinding background isolate: $e');
    }
  }
}

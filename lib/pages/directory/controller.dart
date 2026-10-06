import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:easy_refresh/easy_refresh.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/services/core_service.dart';
import 'package:xlist/constants/index.dart';

class DirectoryController extends GetxController {
  final userInfo = UserModel().obs; // 用户信息
  final objects = <ObjectModel>[].obs; // Object 目录数据
  final isFirstLoading = true.obs; // 是否是第一次加载

  // 显示预览图
  late final isShowPreview = false.obs;

  // 布局类型: list / grid
  final layoutType = 'list'.obs;

  // 排序类型
  final sortType = SortType.TIME_DESC.obs;

  // 多选模式
  final isSelectMode = false.obs;
  final selectedObjects = <ObjectModel>[].obs;

  // 获取参数
  String path = Get.arguments['path'] ?? '/';
  final ObjectModel currentObject = Get.arguments['object'] ?? ObjectModel();
  final String tag = Get.arguments['tag'] ?? '';
  final bool isCopy = Get.arguments['isCopy'] ?? false;
  final bool root = Get.arguments['root'] ?? false;
  final String source = Get.arguments['source'] ?? '';
  final String srcDir = Get.arguments['srcDir'] ?? '';
  final ObjectModel srcObject = Get.arguments['srcObject'] ?? ObjectModel();

  // ScrollController
  final ScrollController scrollController = ScrollController();
  EasyRefreshController easyRefreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  // 目录密码
  String password = '';
  late String pageTitle;
  late CoreService coreService;

  @override
  void onInit() async {
    super.onInit();
    coreService = CoreService.to;

    // 设置页面标题
    pageTitle = root ? 'directory_root_title'.tr : currentObject.name ?? '';

    // 显示预览图设置
    isShowPreview.value = coreService.preferencesStorage.isShowPreview.val ?? true;

    // 获取目录密码
    final serverId = coreService.userStorage.serverId.value;
    final passwordManager = await coreService.passwordManagerDao
        .findPasswordManagerByPath(serverId, path);
    if (passwordManager != null && passwordManager.isNotEmpty) {
      password = passwordManager.last.password;
    }

    // 获取用户信息
    userInfo.value = coreService.currentUser.value ?? UserModel();
    await getDirectoryList();

    // 加载完成
    isFirstLoading.value = false;
  }

  /// 获取目录列表
  Future<void> getDirectoryList() async {
    try {
      await coreService.navigateToPath(path);
      
      // 权限校验 - 这里可以添加权限检查逻辑
      
      // 暂时使用模拟数据
      objects.clear();
      objects.addAll(
        ObjectHelper.sortObjects(coreService.currentObjects, sortType.value),
      );
      objects.refresh();
    } catch (e) {
      print('Error getting directory list: $e');
    }
  }

  /// 切换排序类型
  void changeSortType(int type) {
    sortType.value = type;
    final sorted = ObjectHelper.sortObjects(objects, type);
    objects
      ..clear()
      ..addAll(sorted);
  }

  /// 进入 / 退出多选模式
  void toggleSelectMode() {
    isSelectMode.value = !isSelectMode.value;
    selectedObjects.clear();
  }

  /// 切换单个对象选中状态
  void toggleSelect(ObjectModel object) {
    if (selectedObjects.contains(object)) {
      selectedObjects.remove(object);
    } else {
      selectedObjects.add(object);
    }
  }

  /// 判断对象是否已选中
  bool isSelected(ObjectModel object) {
    return selectedObjects.contains(object);
  }

  /// 全选 / 取消全选
  void selectAll() {
    if (selectedObjects.length == objects.length) {
      selectedObjects.clear();
    } else {
      selectedObjects.assignAll(objects);
    }
  }

  /// 批量下载
  Future<void> batchDownload() async {
    final selected = List<ObjectModel>.from(selectedObjects);
    toggleSelectMode();
    await ObjectHelper.batchDownload(selected, path);
  }

  /// 批量移动 / 复制
  Future<void> batchMoveOrCopy({required bool isCopy}) async {
    final selected = List<ObjectModel>.from(selectedObjects);
    toggleSelectMode();
    await ObjectHelper.batchMoveOrCopy(
      objects: selected,
      srcDir: path,
      isCopy: isCopy,
      source: source,
      pageTag: tag,
    );
  }

  /// 批量删除
  Future<void> batchDelete() async {
    final selected = List<ObjectModel>.from(selectedObjects);
    toggleSelectMode();
    await ObjectHelper.batchDelete(
      objects: selected,
      path: path,
      source: source,
      pageTag: tag,
    );
  }

  /// 移动和复制
  Future<void> moveOrCopy() async {
    if (isCopy) {
      return await ObjectHelper.copy(
        srcDir: srcDir,
        dstDir: path,
        name: srcObject.name!,
        source: source,
        pageTag: tag,
      );
    }

    // 移动文件
    return await ObjectHelper.move(
      srcDir: srcDir,
      dstDir: path,
      name: srcObject.name!,
      source: source,
      pageTag: tag,
    );
  }

  Future<void> addToFavorites(ObjectModel object) async {
    await coreService.addToFavorites(object);
  }

  Future<void> addToRecent(ObjectModel object) async {
    await coreService.addToRecent(object);
  }

  Future<void> downloadObject(ObjectModel object) async {
    await coreService.downloadObject(object);
  }
}

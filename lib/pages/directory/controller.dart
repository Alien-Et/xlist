import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/services/core_service.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/repositorys/index.dart';

class DirectoryController extends GetxController {
  final userInfo = UserModel().obs; // 用户信息
  final objects = <ObjectModel>[].obs; // Object 目录数据
  // 数据版本：列表内容更新时自增，用于 keframe 帧缓存 key 强制重建
  int dataVersion = 0;
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
  // 批量移动/复制：一次选中多个文件
  final List<ObjectModel> srcObjects =
      (Get.arguments['srcObjects'] as List?)?.cast<ObjectModel>() ?? [];

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

    // 读取持久化的排序/布局设置
    try {
      final pref = coreService.preferencesStorage;
      sortType.value = pref.sortType.val ?? SortType.TIME_DESC;
      final savedLayout = pref.layoutType.val;
      if (savedLayout == 0) {
        layoutType.value = 'grid';
      } else if (savedLayout == 1) {
        layoutType.value = 'list';
      }
    } catch (_) {}

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
      // 数据版本 +1：强制列表 key 变化，keframe 帧缓存重建（重命名/刷新后立即可见）
      dataVersion++;
      // 浏览时自动写入本地文件索引（搜索先查索引，加快搜索）
      FileIndexService.saveObjects(
        serverId: Get.find<UserStorage>().serverId.value,
        path: path,
        objects: objects,
      );
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
    // 持久化排序设置
    try {
      coreService.preferencesStorage.sortType.val = type;
    } catch (_) {}
  }

  /// 切换布局类型
  void toggleLayoutType() {
    layoutType.value = layoutType.value == 'grid' ? 'list' : 'grid';
    // 持久化布局设置
    try {
      coreService.preferencesStorage.layoutType.val =
          layoutType.value == 'grid' ? 0 : 1;
    } catch (_) {}
  }

  /// 进入 / 退出多选模式
  void toggleSelectMode() {
    isSelectMode.value = !isSelectMode.value;
    selectedObjects.clear();
  }

  /// 长按进入多选模式并选中该文件（长按菜单已改为二级操作栏）
  void enterSelectMode(ObjectModel object) {
    if (!isSelectMode.value) {
      isSelectMode.value = true;
    }
    if (!selectedObjects.contains(object)) {
      selectedObjects.add(object);
    }
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

  /// 批量移动 / 复制（本页多选后，跳转新的目录选择页执行）
  Future<void> batchMoveOrCopy({required bool isCopy}) async {
    final selected = List<ObjectModel>.from(selectedObjects);
    toggleSelectMode();
    Get.toNamed(Routes.DIRECTORY, arguments: {
      'srcDir': path,
      'srcObjects': selected,
      'root': true,
      'isCopy': isCopy,
      'source': source,
      'tag': tag,
      'fromRoute': Get.currentRoute,
    });
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

  /// 移动和复制（单文件）
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

  /// 粘贴到此处：批量（srcObjects）或单文件（srcObject）统一入口
  Future<void> confirmPaste() async {
    if (srcObjects.isNotEmpty) {
      // 批量移动 / 复制：逐个执行并刷新来源页
      SmartDialog.showLoading();
      try {
        for (final obj in srcObjects) {
          if (isCopy) {
            await ObjectRepository.copy(
              srcDir: srcDir,
              dstDir: path,
              name: obj.name!,
            );
          } else {
            await ObjectRepository.move(
              srcDir: srcDir,
              dstDir: path,
              name: obj.name!,
            );
          }
        }
        SmartDialog.showToast(
            isCopy ? '复制成功' : '移动成功');
        ObjectHelper.refreshObjectList(source: source, pageTag: tag);
      } catch (e) {
        SmartDialog.showToast(e.toString());
      } finally {
        SmartDialog.dismiss();
      }
    } else {
      // 单文件
      await moveOrCopy();
    }
  }
}

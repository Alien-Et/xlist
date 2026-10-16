import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/database/entity/index.dart';

class FavoriteController extends GetxController {
  static const pageSize = 20;
  final isEmpty = true.obs; // 是否为空
  final serverId = Get.find<UserStorage>().serverId.value;

  ScrollController scrollController = ScrollController();
  late final PagingController<int, FavoriteEntity> pagingController;

  @override
  void onInit() {
    super.onInit();
    // 尝试不带参数初始化 PagingController
    pagingController = PagingController(firstPageKey: 0);
    pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems = await DatabaseService.to.database.favoriteDao
          .findFavoriteByServerId(serverId, pageSize, pageKey * pageSize);
      final isLastPage = newItems.length < pageSize;
      if (isLastPage) {
        pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        pagingController.appendPage(newItems, nextPageKey);
      }
      isEmpty.value = pagingController.itemList?.isEmpty ?? true;
    } catch (error) {
      pagingController.error = error;
    }
  }

  /// 删除收藏文件
  /// [entity] 收藏实体
  Future<void> deleteFavorite(FavoriteEntity entity) async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    try {
      await DatabaseService.to.database.favoriteDao
          .deleteFavoriteById(entity.id!);
      pagingController.refresh();
      isEmpty.value = pagingController.itemList?.isEmpty ?? true;
      SmartDialog.showToast('toast_remove_success'.tr);
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  /// 清空收藏
  Future<void> clearFavorite() async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message_all'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    try {
      final _id = serverId;
      await DatabaseService.to.database.favoriteDao
          .deleteFavoriteByServerId(_id);

      // 清空数据
      pagingController.refresh();
      isEmpty.value = true;
      SmartDialog.showToast('toast_remove_success_all'.tr);
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  /// 获取对象列表
  ///
  /// [entity] 收藏实体（entity.path 为所在父目录，entity.name 为条目名）
  Future<List<ObjectModel>> getObjectList(FavoriteEntity entity) async {
    List<ObjectModel> _objects = [];
    // 确定要列出内容的路径
    String pathToList;
    if (entity.type == FileType.FOLDER) {
      // 文件夹：列出文件夹自身的内容
      pathToList =
          entity.path == '/' ? '/${entity.name}' : '${entity.path}/${entity.name}';
    } else {
      // 文件：直接列出其父目录（entity.path 即父目录，不要再 dirname）
      pathToList = entity.path;
    }

    try {
      SmartDialog.showLoading();
      final _sortType = Get.find<PreferencesStorage>().sortType.val;
      final response = await ObjectRepository.getList(path: pathToList);
      if (response['code'] == 200) {
        final data = FsListModel.fromJson(response['data']);
        _objects = CommonUtils.sortObjectList(data.content ?? [], _sortType);
      }
    } catch (e) {
      // 可以在这里添加错误处理逻辑，例如显示一个错误提示
      SmartDialog.showToast(e.toString());
    } finally {
      SmartDialog.dismiss();
    }

    return _objects;
  }
}

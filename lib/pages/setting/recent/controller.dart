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

class RecentController extends GetxController {
  static const pageSize = 20;
  final isEmpty = true.obs; // 是否为空
  final serverId = Get.find<UserStorage>().serverId.value;

  ScrollController scrollController = ScrollController();
  final PagingController<int, RecentEntity> pagingController =
      PagingController(firstPageKey: 0);

  @override
  void onInit() {
    pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    super.onInit();
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems = await DatabaseService.to.database.recentDao
          .findRecentByServerId(serverId, pageSize, pageKey * pageSize);
      final isLastPage = newItems.length < pageSize;
      if (isLastPage) {
        pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        pagingController.appendPage(newItems, nextPageKey);
      }
      isEmpty.value = (pagingController.itemList ?? []).isEmpty;
    } catch (error) {
      pagingController.error = error;
    }
  }

  /// 删除最近浏览
  /// [entity] 最近浏览实体
  Future<void> deleteRecent(RecentEntity entity) async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    try {
      await DatabaseService.to.database.recentDao.deleteRecentById(entity.id!);
      pagingController.refresh();
      isEmpty.value = (pagingController.itemList ?? []).isEmpty;
      SmartDialog.showToast('toast_remove_success'.tr);
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  /// 清空最近浏览
  Future<void> clearRecent() async {
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
      await DatabaseService.to.database.recentDao.deleteRecentByServerId(_id);
      await DatabaseService.to.database.progressDao
          .deleteProgressByServerId(_id);

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
  /// [entity] 最近浏览实体（entity.path 为所在父目录，entity.name 为条目名）
  Future<List<ObjectModel>> getObjectList(RecentEntity entity) async {
    // 确定要列出内容的路径
    String pathToList;
    if (entity.type == FileType.FOLDER) {
      // 文件夹：列出文件夹自身的内容
      pathToList =
          entity.path == '/' ? '/${entity.name}' : '${entity.path}/${entity.name}';
    } else {
      // 文件：直接列出其父目录（entity.path 即父目录）
      pathToList = entity.path;
    }

    List<ObjectModel> _objects = [
      ObjectModel.fromJson({
        'name': entity.name,
        'type': entity.type,
        'is_dir': entity.type == FileType.FOLDER,
        'size': entity.size,
      }),
    ];

    try {
      SmartDialog.showLoading();
      final _sortType = Get.find<PreferencesStorage>().sortType.val;
      final response = await ObjectRepository.getList(path: pathToList);
      if (response['code'] == 200) {
        final data = FsListModel.fromJson(response['data']);
        _objects = CommonUtils.sortObjectList(data.content ?? [], _sortType);
      }
      SmartDialog.dismiss();
    } catch (e) {
      SmartDialog.dismiss();
    }

    return _objects;
  }
}

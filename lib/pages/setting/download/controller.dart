import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/helper/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/database/entity/index.dart';

class DownloadController extends GetxController {
  final entities = <DownloadEntity>[].obs; // 下载记录列表
  final tasks = <DownloadTask>[].obs; // 实时下载任务列表
  final isFirstLoading = true.obs; // 是否是第一次加载
  final totalSize = 0.obs; // 总大小
  // 下载速度（taskId -> bytes/s）
  final speeds = <String, double>{}.obs;
  final serverId = Get.find<UserStorage>().serverId.value.obs;

  // 速度计算采样：taskId -> (上一次进度, 上一次时间)
  final Map<String, (int, DateTime)> _lastSample = {};

  // ScrollController
  final ScrollController scrollController = ScrollController();

  @override
  void onInit() async {
    super.onInit();

    // 加载完成
    isFirstLoading.value = false;

    // 绑定进度监听（后台 isolate 回调 -> 更新任务状态/速度）
    DownloadService.to.bindBackgroundIsolate((id, status, progress) {
      updateDownloadStatus(id, DownloadTaskStatus.values[status], progress);
    });

    // 获取任务列表 & 翻转（最新在前）
    final taskList = await FlutterDownloader.loadTasks() ?? [];
    tasks.value = taskList.reversed.toList();

    // 获取下载列表
    entities.value =
        await DatabaseService.to.database.downloadDao.findAllDownload();

    // 总大小
    resetTotalSize();
  }

  /// 重新获取总大小
  void resetTotalSize() {
    totalSize.value = entities.fold<int>(0, (sum, e) => sum + e.size);
  }

  /// 更新下载状态
  /// [id] 任务 id
  /// [status] 下载状态
  /// [progress] 下载进度 0-100
  void updateDownloadStatus(
    String id,
    DownloadTaskStatus status,
    int progress,
  ) {
    final index = tasks.indexWhere((t) => t.taskId == id);
    if (index == -1) return;
    final task = tasks[index];

    // 计算下载速度：进度差 * 总大小 / 时间差
    final entityIndex = entities.indexWhere((e) => e.taskId == id);
    final size = entityIndex != -1 ? entities[entityIndex].size : 0;
    final now = DateTime.now();
    final last = _lastSample[id];
    if (last != null && size > 0) {
      final dt = now.difference(last.$2).inMilliseconds;
      final dp = progress - last.$1;
      if (dt > 0 && dp > 0) {
        final bytes = dp / 100 * size;
        speeds[id] = bytes / (dt / 1000);
      }
    }
    _lastSample[id] = (progress, now);

    tasks[index] = DownloadTask(
      taskId: id,
      status: status,
      progress: progress,
      url: task.url,
      filename: task.filename,
      savedDir: task.savedDir,
      timeCreated: task.timeCreated,
      allowCellular: task.allowCellular,
    );

    // 刷新数据
    tasks.refresh();
    speeds.refresh();
  }

  /// 打开文件
  /// [task] 任务
  /// [entity] 下载实体
  void open(dynamic task, DownloadEntity entity) async {
    if (task == null) return;

    // 允许播放的视频 & 音频
    final _arguments = {
      'name': entity.name,
      'path': entity.path,
      'serverId': entity.serverId,
      'downloadId': entity.id,
      'file': '${task.savedDir}/${entity.name}',
      'objects': [
        ObjectModel.fromJson({
          'name': entity.name,
          'type': entity.type,
          'is_dir': false,
          'size': entity.size,
        }),
      ],
    };

    if (PreviewHelper.isVideo(entity.name)) {
      Get.toNamed(Routes.VIDEO_PLAYER, arguments: _arguments);
      return;
    }

    if (PreviewHelper.isAudio(entity.name)) {
      Get.toNamed(Routes.AUDIO_PLAYER, arguments: _arguments);
      return;
    }

    // 其他文件：调用安卓系统应用打开本地已下载文件
    final localFile = '${task.savedDir}/${entity.name}';
    try {
      final result = await OpenFilex.open(localFile);
      if (result.type != ResultType.done) {
        SmartDialog.showToast('没有可打开该文件的应用');
      }
    } catch (e) {
      SmartDialog.showToast('打开文件失败: $e');
    }
  }

  /// 恢复下载
  /// [id] 下载 id
  /// [taskId] 任务 id
  void resume(int id, String taskId) async {
    try {
      await FlutterDownloader.resume(taskId: taskId);
      SmartDialog.showToast('已恢复下载');
    } catch (e) {
      SmartDialog.showToast('恢复失败');
    }
  }

  /// 暂停下载
  /// [taskId] 任务 id
  void pause(String taskId) async {
    try {
      await FlutterDownloader.pause(taskId: taskId);
      SmartDialog.showToast('已暂停');
    } catch (e) {
      SmartDialog.showToast('暂停失败');
    }
  }

  /// 删除下载
  /// [id] 下载 id
  /// [taskId] 任务 id
  void delete(int id, String taskId) async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    SmartDialog.showLoading();
    await FlutterDownloader.cancel(taskId: taskId);
    await DatabaseService.to.database.downloadDao.deleteDownloadById(id);
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
    entities.removeWhere((element) => element.id == id);
    tasks.removeWhere((element) => element.taskId == taskId);
    resetTotalSize();

    SmartDialog.dismiss();
    SmartDialog.showToast('toast_remove_success'.tr);
  }

  @override
  void onClose() {
    try {
      // 尝试解绑进度监听
      DownloadService.to.unbindBackgroundIsolate();
    } catch (e) {
      print('Error unbinding background isolate: $e');
    }
    super.onClose();
  }
}

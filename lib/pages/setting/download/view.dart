import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'package:xlist/gen/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/pages/setting/download/index.dart';

class DownloadPage extends GetView<DownloadController> {
  const DownloadPage({Key? key}) : super(key: key);

  // NavigationBar
  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      backgroundColor: CommonUtils.backgroundColor,
      border: Border.all(width: 0, color: Colors.transparent),
      leading: CommonUtils.backButton,
      middle: Text('download_manager'.tr),
    );
  }

  /// 构建图标
  Widget _buildIcon(int type, String name) {
    return Icon(
      FileType.getIcon(type, name),
      size: CommonUtils.isPad ? 60 : 130.sp,
      color: Get.theme.primaryColor,
    );
  }

  /// 状态文案
  String _statusText(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.running:
        return '下载中';
      case DownloadTaskStatus.complete:
        return '已完成';
      case DownloadTaskStatus.failed:
        return '失败';
      case DownloadTaskStatus.paused:
        return '已暂停';
      case DownloadTaskStatus.canceled:
        return '已取消';
      case DownloadTaskStatus.enqueued:
        return '等待中';
      default:
        return '';
    }
  }

  /// 列表项
  Widget _buildItem(int index) {
    final entity = controller.entities[index];
    // 关联实时任务（按 taskId 匹配）
    final task = controller.tasks
        .where((t) => t.taskId == entity.taskId)
        .firstOrNull;

    String path = entity.path;
    if (entity.path.endsWith('/')) {
      path = entity.path.substring(0, entity.path.length - 1);
    }

    // 进度与速度
    final progress = task?.progress ?? 0;
    final speed = controller.speeds[entity.taskId];
    final isRunning = task?.status == DownloadTaskStatus.running;
    final isComplete = task?.status == DownloadTaskStatus.complete;
    final isPaused = task?.status == DownloadTaskStatus.paused;

    return CupertinoListSection.insetGrouped(
      backgroundColor: CommonUtils.backgroundColor,
      margin: CommonUtils.isPad
          ? EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 5)
          : EdgeInsets.symmetric(horizontal: 50.w).copyWith(bottom: 30.h),
      children: [
        Container(
          height: CommonUtils.isPad ? 96 : 210.h,
          width: double.infinity,
          child: Slidable(
            startActionPane: isComplete
                ? ActionPane(
                    motion: ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) => Share.shareXFiles(
                            [XFile('${task?.savedDir}/${entity.name}')]),
                        backgroundColor: CupertinoColors.systemBlue,
                        foregroundColor: Colors.white,
                        icon: CupertinoIcons.share,
                        label: '分享',
                      ),
                    ],
                  )
                : null,
            endActionPane: ActionPane(
              motion: ScrollMotion(),
              children: [
                if (isRunning)
                  SlidableAction(
                    onPressed: (context) =>
                        controller.pause(entity.taskId),
                    backgroundColor: Colors.grey,
                    icon: CupertinoIcons.pause_circle,
                    foregroundColor: Colors.white,
                    label: '暂停',
                  ),
                if (isPaused)
                  SlidableAction(
                    onPressed: (context) =>
                        controller.resume(entity.id!, entity.taskId),
                    backgroundColor: Get.theme.primaryColor,
                    icon: CupertinoIcons.play_circle,
                    foregroundColor: Colors.white,
                    label: '恢复',
                  ),
                SlidableAction(
                  onPressed: (context) =>
                      controller.delete(entity.id!, entity.taskId),
                  backgroundColor: Colors.red,
                  icon: CupertinoIcons.delete,
                  label: 'delete'.tr,
                ),
              ],
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.open(task, entity),
              child: Row(
                children: [
                  SizedBox(width: 30.w),
                  _buildIcon(entity.type, entity.name),
                  SizedBox(width: 20.w),
                  // 自适应宽度，避免窄屏溢出
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: CommonUtils.isPad ? 12 : 24.h),
                        Text(
                          entity.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Get.textTheme.bodyLarge,
                        ),
                        // 路径单独一行（上下排，不再与大小挤在一排）
                        if (path.isNotEmpty) ...[
                          SizedBox(height: 6.h),
                          Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Get.textTheme.bodySmall?.copyWith(
                              color: Get.theme.disabledColor,
                            ),
                          ),
                        ],
                        SizedBox(height: 6.h),
                        // 大小 + 状态/进度 一行（上下排信息）
                        Text(
                          task == null
                              ? CommonUtils.formatFileSize(entity.size)
                              : '${CommonUtils.formatFileSize(entity.size)} · '
                                  '${isComplete ? '已完成' : (_statusText(task.status).isNotEmpty ? '${_statusText(task.status)} $progress%' : '$progress%')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Get.textTheme.bodySmall,
                        ),
                        // 进度条（下载中/暂停/等待时显示）
                        if (task != null && !isComplete)
                          Padding(
                            padding: EdgeInsets.only(top: CommonUtils.isPad ? 4 : 10.h),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                minHeight: CommonUtils.isPad ? 6 : 12.h,
                                backgroundColor: Get.theme.dividerColor,
                              ),
                            ),
                          ),
                        SizedBox(height: 5.h),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  // 右侧：仅下载中显示速度与状态（失败/完成状态由左侧"大小·状态"一行显示，避免重复）
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isRunning && speed != null && speed > 0)
                        Text(
                          CommonUtils.formatSpeed(speed),
                          style: Get.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Get.theme.primaryColor,
                            fontSize: CommonUtils.isPad ? 16 : 32.sp,
                          ),
                        ),
                      if (isRunning) ...[
                        SizedBox(height: 6.h),
                        Text(
                          '${task != null && _statusText(task.status).isNotEmpty ? '${_statusText(task.status)} ' : ''}$progress%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Get.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// SliverList
  Widget _buildSliverList() {
    if (controller.isFirstLoading.isTrue) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 500.h),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (controller.entities.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: 500.h),
            Assets.images.empty.image(width: 600.r),
            SizedBox(height: 30.h),
            Text('setting_download_empty'.tr, style: Get.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) => FrameSeparateWidget(
          index: index,
          child: Obx(() => _buildItem(index)),
        ),
        childCount: controller.entities.length,
      ),
    );
  }

  // ScrollView
  // Replace to [NestedScrollView]
  Widget _buildCustomScrollView() {
    return CustomScrollView(
      shrinkWrap: false,
      controller: controller.scrollController,
      physics: AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: controller.entities.isNotEmpty
              ? Container(
                  padding: CommonUtils.isPad
                      ? EdgeInsets.only(left: 40, top: 30.h, bottom: 10.h)
                      : EdgeInsets.only(left: 80.w, top: 30.h, bottom: 10.h),
                  child: Obx(
                    () => Text(
                        '${'setting_download_used'.tr} ${CommonUtils.formatFileSize(controller.totalSize.value)}, ${'setting_download_manager_file'.tr}',
                        style: Get.textTheme.bodySmall),
                  ),
                )
              : SizedBox(),
        ),
        Obx(() => SizeCacheWidget(child: _buildSliverList())),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      backgroundColor: CommonUtils.backgroundColor,
      child: Obx(
        () => controller.isFirstLoading.isTrue
            ? Center(child: CupertinoActivityIndicator())
            : _buildCustomScrollView(),
      ),
    );
  }
}

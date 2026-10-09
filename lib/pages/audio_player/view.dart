import 'dart:math';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:xlist/gen/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/pages/audio_player/index.dart';
import 'package:xlist/routes/app_pages.dart';

class AudioPlayerPage extends GetView<AudioPlayerController> {
  const AudioPlayerPage({Key? key}) : super(key: key);

  /// 构建下拉按钮
  Widget _buildPullDownButton() {
    List<PullDownMenuEntry> items = [];

    // 收藏
    items.add(PullDownMenuItem(
      title: 'favorite'.tr,
      onTap: () => controller.favorite(),
    ));

    items.addAll([
      PullDownMenuItem(
        title: 'play_speed'.tr,
        onTap: () => controller.changeSpeed(),
      ),
      PullDownMenuItem(
        title: 'pull_down_copy_link'.tr,
        onTap: () => controller.copyLink(),
      ),
      PullDownMenuItem(
        title: 'pull_down_download_file'.tr,
        onTap: () => controller.download(),
      ),
    ]);

    return PullDownButton(
      itemBuilder: (context) => items,
      buttonBuilder: (context, showMenu) => CupertinoButton(
        onPressed: showMenu,
        padding: EdgeInsets.zero,
        alignment: Alignment.centerRight,
        child: Icon(
          CupertinoIcons.ellipsis_circle,
          size: CommonUtils.navIconSize,
        ),
      ),
    );
  }

  // NavigationBar
  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      backgroundColor: Get.theme.scaffoldBackgroundColor,
      border: Border.all(width: 0, color: Colors.transparent),
      transitionBetweenRoutes: false,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        child: Icon(CupertinoIcons.chevron_down,
            size: CommonUtils.isPad ? 25 : 70.sp),
        onPressed: () => Get.back(),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Icon(CupertinoIcons.download_circle),
            onPressed: () => Get.toNamed(Routes.SETTING_DOWNLOAD),
          ),
          _buildPullDownButton(),
        ],
      ),
    );
  }

  /// 封面图
  Widget _buildCover() {
    return Hero(
      tag: 'cover',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50.r),
        child: CachedNetworkImage(
          imageUrl: controller.object.value.thumb ?? '',
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              CupertinoActivityIndicator(radius: 13.0),
          errorWidget: (context, url, error) => Assets.common.logo.image(),
        ),
      ),
    );
  }

  /// 构建单个文件
  Widget _buildSingleFile() {
    return Container(
      key: PageStorageKey('single'),
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(top: CommonUtils.isPad ? 20 : 60.h),
      child: Column(
        children: [
          Container(
            width: CommonUtils.isPad ? 300 : 600.r,
            height: CommonUtils.isPad ? 300 : 600.r,
            child: _buildCover(),
          ),
          SizedBox(height: 50.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 50.w),
            child: Text(
              CommonUtils.formatFileNme(controller.currentName.value),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 播放列表
  Widget _buildPlaylist() {
    return Container(
      key: PageStorageKey('playlist'),
      padding: EdgeInsets.only(
          top: CommonUtils.isPad ? 20 : 40.h, left: 50.w, right: 50.w),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: CommonUtils.isPad ? 150 : 300.r,
                height: CommonUtils.isPad ? 150 : 300.r,
                child: _buildCover(),
              ),
              SizedBox(width: 50.w),
              Expanded(
                child: Text(
                  CommonUtils.formatFileNme(controller.currentName.value),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Get.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 60.h),
          Expanded(
            child: ListView.builder(
              physics: AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: controller.objects.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => controller.changePlaylist(index),
                  child: Container(
                    height: CommonUtils.isPad ? 50 : 100.h,
                    child: Text(
                      CommonUtils.formatFileNme(
                          controller.objects[index].name!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Get.textTheme.titleMedium?.copyWith(
                        color: controller.currentIndex.value == index
                            ? Get.theme.primaryColor
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 播放进度
  Widget _buildFijkSlider() {
    // 计算进度时间
    double duration = controller.duration.value.inMilliseconds.toDouble();
    double currentValue = controller.seekPos > 0
        ? controller.seekPos
        : controller.currentPos.value.inMilliseconds.toDouble();
    currentValue = min(currentValue, duration);
    currentValue = max(currentValue, 0);

    // 计算缓存进度
    double cacheValue = controller.bufferPos.value.inMilliseconds.toDouble();
    cacheValue = min(cacheValue, duration);
    cacheValue = max(cacheValue, 0);

    return SliderTheme(
      data: SliderTheme.of(Get.context!).copyWith(
        activeTrackColor: Get.theme.primaryColor,
        inactiveTrackColor: Get.theme.primaryColor.withOpacity(0.3),
        thumbColor: Get.theme.primaryColor,
        overlayColor: Get.theme.primaryColor.withOpacity(0.2),
        trackHeight: 2.0,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 12.0),
      ),
      child: Slider(
        value: currentValue,
        min: 0.0,
        // 总时长未知时为 1，避免 Slider(max <= min) 断言崩溃
        max: duration > 0 ? duration : 1.0,
        onChanged: (v) {
          controller.seekPos = v;
        },
        onChangeEnd: (v) {
          if (controller.seekPos.toInt() == -1) return;
          controller.player.seekTo(Duration(milliseconds: v.toInt()));
          controller.currentPos.value = Duration(
            milliseconds: controller.seekPos.toInt(),
          );
          controller.seekPos = -1;
        },
      ),
    );
  }

  /// 播放时间
  Widget _buildDuration() {
    return Container(
      height: 70.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 500.w,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(left: 50.w),
            child: Obx(
              () => Text(
                CommonUtils.formatDuration(controller.currentPos.value),
              ),
            ),
          ),
          Container(
            width: 500.w,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 50.w),
            child: Obx(
              () => Text(
                CommonUtils.formatDuration(controller.duration.value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建播放器控制按钮
  Widget _buildControlButton() {
    return Container(
      height: 120.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CupertinoButton(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
            child: Icon(
              CupertinoIcons.backward_end_alt_fill,
              size: CommonUtils.isPad ? 50 : 100.sp,
              color: Get.isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              final _ct = controller;
              if (_ct.playMode.value == PlayMode.SHUFFLE) {
                _ct.changePlaylist(Random().nextInt(_ct.objects.length));
                return;
              }

              _ct.currentIndex.value == 0
                  ? _ct.changePlaylist(_ct.objects.length - 1)
                  : _ct.changePlaylist(_ct.currentIndex.value - 1);
            },
          ),
          CupertinoButton(
            alignment: Alignment.center,
            padding: EdgeInsets.zero,
            child: Obx(
              () => Icon(
                controller.isPlaying.value
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                size: CommonUtils.isPad ? 65 : 150.sp,
                color: Get.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            onPressed: () {
              controller.isPlaying.value
                  ? controller.player.pause()
                  : controller.player.play();
            },
          ),
          CupertinoButton(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.zero,
            child: Icon(
              CupertinoIcons.forward_end_alt_fill,
              size: CommonUtils.isPad ? 50 : 100.sp,
              color: Get.isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              final _ct = controller;
              if (_ct.playMode.value == PlayMode.SHUFFLE) {
                _ct.changePlaylist(Random().nextInt(_ct.objects.length));
                return;
              }

              _ct.currentIndex.value == _ct.objects.length - 1
                  ? _ct.changePlaylist(0)
                  : _ct.changePlaylist(_ct.currentIndex.value + 1);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Get.isDarkMode ? Colors.black : Color(0xFFF5F5F5),
              Get.isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFE8E8E8),
            ],
          ),
        ),
        child: SafeArea(
          child: DefaultTabController(
            length: 2,
            child: Obx(() {
              // 播放错误：显示错误视图 + 重试
              if (controller.errorMessage.value.isNotEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 80.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 120.sp,
                          color: Get.theme.primaryColor,
                        ),
                        SizedBox(height: 40.h),
                        Text(
                          controller.errorMessage.value,
                          textAlign: TextAlign.center,
                          style: Get.textTheme.bodyMedium?.copyWith(
                            color: Get.isDarkMode
                                ? Colors.white70
                                : Colors.black54,
                          ),
                        ),
                        SizedBox(height: 40.h),
                        CupertinoButton.filled(
                          child: Text('重试'),
                          onPressed: () => controller.retry(),
                        ),
                        SizedBox(height: 16.h),
                        CupertinoButton(
                          child: Text('返回'),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // 封面 / 播放列表（弹性分配高度，避免固定高度溢出）
                  Expanded(
                    child: Obx(
                      () => TabBarView(
                        controller: controller.tabController,
                        children: [_buildSingleFile(), _buildPlaylist()],
                      ),
                    ),
                  ),
                  // 进度条（总时长未知时隐藏，避免 Slider max=0 崩溃）
                  if (controller.duration.value.inMilliseconds > 0)
                    Container(
                      height: 30.h,
                      padding: EdgeInsets.symmetric(horizontal: 50.w),
                      child: Obx(() => _buildFijkSlider()),
                    ),
                  _buildDuration(),
                  SizedBox(height: 20.h),
                  // 控制按钮
                  _buildControlButton(),
                  SizedBox(height: 20.h),
                  // 播放模式 / 列表 / 定时
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 100.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Obx(
                          () => CupertinoButton(
                            alignment: Alignment.centerLeft,
                            child: Icon(
                              PlayMode.getIcon(controller.playMode.value),
                              size: CommonUtils.isPad ? 30 : 70.sp,
                              color: Get.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            onPressed: () {
                              controller.playMode.value =
                                  controller.playMode.value == PlayMode.SHUFFLE
                                      ? PlayMode.LIST_LOOP
                                      : controller.playMode.value + 1;
                            },
                          ),
                        ),
                        Obx(
                          () => CupertinoButton(
                            alignment: Alignment.center,
                            child: Icon(
                              CupertinoIcons.list_bullet,
                              size: CommonUtils.isPad ? 30 : 70.sp,
                              color: controller.isPlaylist.value
                                  ? Get.theme.primaryColor
                                  : Get.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                            ),
                            onPressed: () {
                              controller.isPlaylist.value =
                                  !controller.isPlaylist.value;
                              controller.tabController.index =
                                  controller.isPlaylist.value ? 1 : 0;
                            },
                          ),
                        ),
                        Obx(
                          () => CupertinoButton(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              CupertinoIcons.clock,
                              size: CommonUtils.isPad ? 30 : 70.sp,
                              color:
                                  controller.timerDuration.value.inSeconds > 0
                                      ? Get.theme.primaryColor
                                      : Get.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                            ),
                            onPressed: () => controller.timedShutdown(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30.h),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

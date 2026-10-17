import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/repositorys/index.dart';

// 添加布局模式枚举
enum PreviewLayoutMode { carousel, grid, list }

class ImagePreviewController extends GetxController {
  final imageUrls = <String>[].obs;
  final imageHeaders = <String, String>{}.obs;
  final userInfo = UserModel().obs; // 用户信息
  final serverUrl = Get.find<CoreService>().currentServer.value?.url ?? '';
  // 添加布局模式状态
  final layoutMode = PreviewLayoutMode.carousel.obs;
  // 网格布局列数
  final gridCrossAxisCount = 2.obs;

  // 获取参数
  final String path = Get.arguments['path'] ?? '';
  final String name = Get.arguments['name'] ?? '';
  List<ObjectModel> objects = Get.arguments['objects'] ?? [];

  // 图片控制器
  final currentIndex = 0.obs;
  final isDragUpdate = false.obs;
  late PageController pageController;

  @override
  Future<void> onInit() async {
    super.onInit();

    // 过滤非图片
    objects = objects.where((o) => PreviewHelper.isImage(o.name!)).toList();
    userInfo.value = UserModel();

    // 获取对象信息
    ObjectModel object;
    try {
      final fullPath = path == '/' ? '$path$name' : '$path/$name';
      object = await ObjectRepository.get(path: fullPath);
    } catch (e) {
      print('Error getting object: $e');
      // 创建一个默认的object对象，避免后续代码崩溃
      object = ObjectModel()
        ..name = name
        ..rawUrl = '';
    }

    // 获取请求头
    imageHeaders.value = DriverHelper.getWebDAVHeaders();

    // 获取图片链接（并发获取，避免几十张图串行请求导致打开慢）
    final urls = <String>[];
    final futures = objects.map((o) async {
      final fullPath = path == '/' ? '$path${o.name}' : '$path/${o.name}';
      try {
        // 尝试获取对象信息以获取正确的URL
        final obj = await ObjectRepository.get(path: fullPath);
        if (obj.rawUrl != null && obj.rawUrl!.isNotEmpty) {
          return obj.rawUrl!;
        }
        // 如果没有rawUrl，使用CommonUtils.getDownloadLink
        return CommonUtils.getDownloadLink(
          path,
          object: o,
          userInfo: userInfo.value,
        );
      } catch (e) {
        // 出错时，使用CommonUtils.getDownloadLink
        return CommonUtils.getDownloadLink(
          path,
          object: o,
          userInfo: userInfo.value,
        );
      }
    });
    urls.addAll(await Future.wait(futures));
    imageUrls.value = urls;

    // 初始化图片控制器
    currentIndex.value = objects.indexWhere((e) => e.name == name);
    // 确保currentIndex在有效范围内
    if (currentIndex.value < 0 || currentIndex.value >= imageUrls.length) {
      currentIndex.value = 0;
    }
    pageController = PageController(initialPage: currentIndex.value);

    // 加入最近浏览
    await CommonUtils.addRecent(object, path, name);

    // 添加当前图片（如果urls为空）
    if (imageUrls.isEmpty) {
      if (object.rawUrl != null && object.rawUrl!.isNotEmpty) {
        imageUrls.add(object.rawUrl!);
      } else {
        // 尝试构建一个下载链接
        final downloadLink = CommonUtils.getDownloadLink(
          path,
          object: object,
          userInfo: userInfo.value,
        );
        imageUrls.add(downloadLink);
      }
      // 重新初始化页面控制器
      pageController = PageController(initialPage: 0);
    }
  }

  /// 页面切换
  /// [index] 当前页面索引
  void onPageChanged(int index) {
    currentIndex.value = index;
  }

  /// 显示更多操作
  void moreActionSheet() async {
    final value = await showModalActionSheet(
      context: Get.overlayContext!,
      actions: [
        SheetAction(label: 'pull_down_copy_link'.tr, key: 'copy'),
        SheetAction(label: 'pull_down_save_image'.tr, key: 'save'),
        // 添加布局切换选项
        SheetAction(
          label: layoutMode.value == PreviewLayoutMode.carousel
              ? '切换到网格布局'
              : '切换到轮播布局',
          key: 'layout',
        ),
      ],
      cancelLabel: 'cancel'.tr,
    );
    if (value == null) return;
    if (value == 'save') await saveImage();
    if (value == 'copy') copyLink();
    // 处理布局切换
    if (value == 'layout') {
      layoutMode.value = layoutMode.value == PreviewLayoutMode.carousel
          ? PreviewLayoutMode.grid
          : PreviewLayoutMode.carousel;
    }
  }

  /// 复制链接
  void copyLink() {
    Clipboard.setData(ClipboardData(
      text: CommonUtils.getDownloadLink(
        path,
        object: objects[currentIndex.value],
        userInfo: userInfo.value,
      ),
    ));
    SmartDialog.showToast('toast_copy_success'.tr);
  }

  /// 保存图片
  Future<void> saveImage() async {
    try {
      SmartDialog.showLoading();
      final response = await DioService.to.dio.get(
        imageUrls[currentIndex.value],
        options: Options(
          responseType: ResponseType.bytes,
          headers: imageHeaders,
        ),
      );

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(response.data),
        quality: 100,
        name: "xlist_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      SmartDialog.dismiss();
      if (result['isSuccess'] == false) throw 'toast_save_image_fail'.tr;
      SmartDialog.showToast('toast_save_success'.tr);
    } catch (e) {}
  }
}

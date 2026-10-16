import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:xlist/pages/image_preview/index.dart';
import 'package:xlist/services/index.dart';

class ImagePreviewPage extends GetView<ImagePreviewController> {
  ImagePreviewPage({Key? key}) : super(key: key);
  late final _thumbnailPaths = RxList<String?>([]);
  final _isInitialized = false.obs;

  void _preloadThumbnails() async {
    if (_isInitialized.value) return;
    _isInitialized.value = true;

    // 只预取当前页 ±2 张：避免一次性串行下载全部原图副本导致打开慢
    // （全部图片仍由 CachedNetworkImage 渐进加载）
    if (controller.imageUrls.isEmpty) return;
    final center = controller.currentIndex.value;
    final start = (center - 2).clamp(0, controller.imageUrls.length - 1);
    final end =
        (center + 2).clamp(0, controller.imageUrls.length - 1).toInt();
    for (var i = start; i <= end; i++) {
      final url = controller.imageUrls[i];
      try {
        final path = await ThumbnailCache().getThumbnail(
          url: url,
          headers: controller.imageHeaders,
          isVideo: false,
        );
        if (path != null) {
          // 确保索引对齐（未预取的索引用 null 占位）
          while (_thumbnailPaths.length <= i) {
            _thumbnailPaths.add(null);
          }
          _thumbnailPaths[i] = path!;
        }
      } catch (e) {
        print('Error preloading thumbnail for $url: $e');
      }
    }
  }

  /// 页面指示器
  Widget _buildExtendedPageIndicator() {
    return Positioned(
      left: 0,
      right: 50.r,
      bottom: 60.r,
      child: AnimatedOpacity(
        opacity: controller.isDragUpdate.value ? 0.0 : 1,
        duration: Duration(milliseconds: 300),
        child: Container(
          alignment: Alignment.bottomRight,
          child: Text(
            '${controller.currentIndex.value + 1}/${controller.objects.length}',
            style: Get.textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// 图片
  /// [url] 图片地址
  Widget _buildNetworkImage(String url) {
    return Obx(() {
      final index = controller.imageUrls.indexOf(url);
      final thumbnailPath = index >= 0 && index < _thumbnailPaths.length
          ? _thumbnailPaths[index]
          : null;
      
      if (thumbnailPath != null && thumbnailPath!.isNotEmpty) {
        return Image.file(
          File(thumbnailPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildCachedNetworkImage(url),
        );
      }
      
      return _buildCachedNetworkImage(url);
    });
  }

  Widget _buildCachedNetworkImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      httpHeaders: controller.imageHeaders,
      placeholder: (context, url) => CupertinoActivityIndicator(),
      errorWidget: (context, url, error) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.wifi_exclamationmark,
            size: 100.sp,
            color: Colors.grey,
          ),
          SizedBox(height: 10.h),
          Text(
            error.toString(),
            style: Get.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 轮播布局
  Widget _buildCarouselLayout() {
    return PhotoViewGallery.builder(
      wantKeepAlive: true,
      pageController: controller.pageController,
      onPageChanged: controller.onPageChanged,
      itemCount: controller.imageUrls.length,
      builder: (context, index) {
        return PhotoViewGalleryPageOptions.customChild(
          minScale: PhotoViewComputedScale.contained * 1.0,
          maxScale: PhotoViewComputedScale.covered * 2.0,
          child: Obx(
            () => Center(
              child: _buildNetworkImage(controller.imageUrls[index]),
            ),
          ),
        );
      },
      backgroundDecoration: BoxDecoration(color: Colors.transparent),
      loadingBuilder: (context, event) =>
          Center(child: CupertinoActivityIndicator()),
    );
  }

  /// 网格布局
  Widget _buildGridLayout() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: controller.gridCrossAxisCount.value,
        crossAxisSpacing: 2.w,
        mainAxisSpacing: 2.h,
      ),
      itemCount: controller.imageUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            controller.currentIndex.value = index;
            controller.pageController.jumpToPage(index);
            controller.layoutMode.value = PreviewLayoutMode.carousel;
          },
          child: _buildNetworkImage(controller.imageUrls[index]),
        );
      },
    );
  }

  /// 根据布局模式构建不同布局
  Widget _buildLayoutByMode() {
    return Obx(() {
      switch (controller.layoutMode.value) {
        case PreviewLayoutMode.carousel:
          return _buildCarouselLayout();
        case PreviewLayoutMode.grid:
          return _buildGridLayout();
        default:
          return _buildCarouselLayout();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DismissiblePage(
      onDismissed: () => Get.back(),
      isFullScreen: true,
      direction: DismissiblePageDismissDirection.vertical,
      backgroundColor: Colors.black,
      startingOpacity: 1.0,
      onDragUpdate: (details) {
        controller.isDragUpdate.value = details.opacity != 1.0;
      },
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => Get.back(),
          onLongPress: () => controller.moreActionSheet(),
          child: CupertinoPageScaffold(
            backgroundColor: Colors.transparent,
            child: DefaultTextStyle(
              style: TextStyle(color: Colors.white),
              child: Obx(
                () => Stack(
                  children: [
                    _buildLayoutByMode(),
                    // 只在轮播模式显示页码指示器
                    if (controller.layoutMode.value ==
                        PreviewLayoutMode.carousel)
                      _buildExtendedPageIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

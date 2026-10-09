import 'dart:io';

import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:xlist/gen/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/services/index.dart';

class ObjectGridItem extends StatefulWidget {
  final ObjectModel object;
  final bool isShowPreview;

  const ObjectGridItem({
    Key? key,
    required this.object,
    required this.isShowPreview,
  }) : super(key: key);

  @override
  _ObjectGridItemState createState() => _ObjectGridItemState();
}

class _ObjectGridItemState extends State<ObjectGridItem>
    with AutomaticKeepAliveClientMixin {
  ObjectModel get object => widget.object;
  final _thumbnailPath = Rxn<String>();

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (!widget.isShowPreview ||
        object.thumb == null ||
        object.thumb!.isEmpty) {
      return;
    }
    // 视频：WebDAV 无缩略图服务，下载整个视频文件成本过高，直接使用类型图标
    if (PreviewHelper.isVideo(object.name ?? '')) return;
    // 图片：携带 WebDAV 认证头下载缩略图（缺少认证头会 401 导致缩略图缺失）
    final path = await ThumbnailCache().getThumbnail(
      url: object.thumb!,
      headers: DriverHelper.getWebDAVHeaders(),
    );
    if (path != null && path.isNotEmpty) {
      _thumbnailPath.value = path;
    }
  }

  /// 构建图标
  Widget _buildIcon() {
    final isVideoFile = PreviewHelper.isVideo(object.name ?? '');
    if (widget.isShowPreview &&
        !isVideoFile &&
        object.thumb != null &&
        object.thumb!.isNotEmpty) {
      return Obx(() {
        final thumbnailPath = _thumbnailPath.value;
        final useCached = thumbnailPath != null && thumbnailPath!.isNotEmpty;

        return Container(
          width: 65,
          height: 65,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: useCached
                ? Image.file(
                    File(thumbnailPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildNetworkImage(),
                  )
                : _buildNetworkImage(),
          ),
        );
      });
    }

    // 视频 / 无缩略图：类型图标 + 播放角标
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          FileType.getIcon(object.type ?? 0, object.name ?? ''),
          size: 65,
          color: Get.theme.primaryColor,
        ),
        if (isVideoFile)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(2.r),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(
                CupertinoIcons.play_fill,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: object.thumb!,
      fit: BoxFit.cover,
      httpHeaders: DriverHelper.getWebDAVHeaders(),
      placeholder: (context, url) => CupertinoActivityIndicator(),
      errorWidget: (context, url, error) =>
          Assets.common.logo.image(),
    );
  }

  /// 构建列表项
  Widget _buildTitleAndTime() {
    // 格式化时间
    final modified = object.modified == null
        ? ''
        : '${Jiffy.parseFromDateTime(object.modified!).format(pattern: 'yyyy/MM/dd')}';

    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          child: Text(
            object.name ?? '',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Get.textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          modified,
          style: Get.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        _buildIcon(),
        SizedBox(height: 5.h),
        _buildTitleAndTime(),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

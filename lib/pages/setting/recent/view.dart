import 'dart:io';

import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:xlist/gen/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/database/entity/index.dart';
import 'package:xlist/pages/setting/recent/index.dart';

class RecentPage extends GetView<RecentController> {
  const RecentPage({Key? key}) : super(key: key);

  // NavigationBar
  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      backgroundColor: CommonUtils.backgroundColor,
      border: Border.all(width: 0, color: Colors.transparent),
      leading: CommonUtils.backButton,
      middle: Text('setting_recent_title'.tr),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: Text('setting_recent_clear'.tr),
        onPressed: () => controller.clearRecent(),
      ),
    );
  }

  /// 构建图标
  /// 图标/缩略图：图片且带 thumb 时显示缩略图，否则类型图标
  /// [type] 文件类型
  /// [name] 文件名
  Widget _buildIcon(int type, String name, RecentEntity entity) {
    // 非视频且带缩略图地址 → 显示缩略图（与文件列表一致）
    if (!PreviewHelper.isVideo(name) &&
        entity.thumb != null &&
        entity.thumb!.isNotEmpty) {
      return _RecentThumbnail(thumb: entity.thumb!);
    }
    return Icon(
      FileType.getIcon(type, name),
      size: CommonUtils.isPad ? 60 : 130.sp,
      color: Get.theme.primaryColor,
    );
  }

  /// 列表项
  Widget _buildItem(RecentEntity entity) {
    String path = entity.path;
    if (entity.path.endsWith('/')) {
      path = entity.path.substring(0, entity.path.length - 1);
    }

    return CupertinoListSection.insetGrouped(
      backgroundColor: CommonUtils.backgroundColor,
      margin: EdgeInsets.zero,
      children: [
        Container(
          height: CommonUtils.isPad ? 80 : 170.h,
          width: double.infinity,
          child: Slidable(
            endActionPane: ActionPane(
              motion: ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => controller.deleteRecent(entity),
                  backgroundColor: Colors.red,
                  icon: CupertinoIcons.delete,
                  label: 'delete'.tr,
                ),
              ],
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                // 文件：直接用本地索引信息秒开（避免每次点击都网络加载父目录导致极慢）
                // 文件夹：仍需网络加载目录内容
                List<ObjectModel> objects;
                if (entity.type != FileType.FOLDER) {
                  objects = [
                    ObjectModel.fromJson({
                      'name': entity.name,
                      'type': entity.type,
                      'is_dir': false,
                      'size': entity.size,
                    }),
                  ];
                } else {
                  objects = await controller.getObjectList(entity);
                }
                ObjectHelper.click(
                  path: entity.path,
                  type: entity.type,
                  name: entity.name,
                  objects: objects,
                );
              },
              child: Row(
                children: [
                  SizedBox(width: CommonUtils.isPad ? 15 : 30.w),
                  _buildIcon(entity.type, entity.name, entity),
                  SizedBox(width: CommonUtils.isPad ? 10 : 20.w),
                  Container(
                    width: 750.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: CommonUtils.isPad ? 15 : 30.h),
                        Text(
                          entity.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Get.textTheme.bodyLarge,
                        ),
                        SizedBox(height: 7.h),
                        Text(
                          '${CommonUtils.formatFileSize(entity.size)}${path.isNotEmpty ? ' - $path' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Get.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // SliverList
  Widget _buildSliverList() {
    return PagedSliverList<int, RecentEntity>.separated(
      pagingController: controller.pagingController,
      builderDelegate: PagedChildBuilderDelegate<RecentEntity>(
        animateTransitions: false,
        noItemsFoundIndicatorBuilder: (context) => _buildEmptyData(),
        firstPageProgressIndicatorBuilder: (context) => _buildLoading(),
        newPageProgressIndicatorBuilder: (context) => _buildLoading(),
        itemBuilder: (context, item, index) {
          return FrameSeparateWidget(
            index: index,
            child: _buildItem(item),
          );
        },
      ),
      separatorBuilder: (context, index) => SizedBox(height: 30.h),
    );
  }

  /// Loading
  Widget _buildLoading() {
    return Center(child: CupertinoActivityIndicator());
  }

  /// EmptyData
  Widget _buildEmptyData() {
    return Column(
      children: [
        SizedBox(height: 500.h),
        Assets.images.empty.image(width: 600.r),
        SizedBox(height: 30.h),
        Text('setting_recent_empty'.tr, style: Get.textTheme.bodyLarge),
      ],
    );
  }

  // ScrollView
  // Replace to [NestedScrollView]
  Widget _buildCustomScrollView() {
    return CustomScrollView(
      shrinkWrap: false,
      physics: AlwaysScrollableScrollPhysics(),
      controller: controller.scrollController,
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Obx(
            () => controller.isEmpty.isFalse
                ? Container(
                    padding: CommonUtils.isPad
                        ? EdgeInsets.only(left: 40, top: 30.h, bottom: 10.h)
                        : EdgeInsets.only(left: 80.w, top: 30.h, bottom: 10.h),
                    child: Text(
                      'setting_recent_description'.tr,
                      style: Get.textTheme.bodySmall,
                    ),
                  )
                : SizedBox(),
          ),
        ),
        SliverPadding(
          padding:
              EdgeInsets.symmetric(horizontal: 50.r).copyWith(bottom: 50.h),
          sliver: SizeCacheWidget(child: _buildSliverList()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      backgroundColor: CommonUtils.backgroundColor,
      child: _buildCustomScrollView(),
    );
  }
}

/// 最近浏览缩略图：携带 WebDAV 认证头缓存拉取（与文件列表缩略图一致）
class _RecentThumbnail extends StatefulWidget {
  final String thumb;

  const _RecentThumbnail({Key? key, required this.thumb}) : super(key: key);

  @override
  State<_RecentThumbnail> createState() => _RecentThumbnailState();
}

class _RecentThumbnailState extends State<_RecentThumbnail> {
  final _thumbnailPath = Rxn<String>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await ThumbnailCache().getThumbnail(
      url: widget.thumb,
      headers: DriverHelper.getWebDAVHeaders(),
    );
    if (path != null && path.isNotEmpty) {
      _thumbnailPath.value = path;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final thumbnailPath = _thumbnailPath.value;
      final useCached = thumbnailPath != null && thumbnailPath!.isNotEmpty;
      return Container(
        width: CommonUtils.isPad ? 60 : 130.sp,
        height: CommonUtils.isPad ? 60 : 130.sp,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.r),
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

  Widget _buildNetworkImage() {
    return Image.network(
      widget.thumb,
      fit: BoxFit.cover,
      headers: DriverHelper.getWebDAVHeaders(),
      errorBuilder: (context, error, stackTrace) => Icon(
        CupertinoIcons.photo,
        size: CommonUtils.isPad ? 30 : 60.sp,
        color: Get.theme.disabledColor,
      ),
    );
  }
}

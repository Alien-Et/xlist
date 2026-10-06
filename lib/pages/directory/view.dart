import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/pages/directory/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/components/object_list/object_list_item.dart';
import 'package:xlist/components/object_grid/object_grid_item.dart';
import 'package:xlist/components/index.dart';

class DirectoryPage extends GetView<DirectoryController> {
  final String? tag;
  final String? previousPageTitle;
  DirectoryController get controller => Get.find<DirectoryController>(tag: tag);

  /// 构造函数
  DirectoryPage({
    Key? key,
    this.tag,
    this.previousPageTitle,
  }) : super(key: key) {
    Get.put<DirectoryController>(DirectoryController(), tag: tag);
  }

  /// 构建下拉菜单
  Widget _buildPullDownButton() {
    List<PullDownMenuEntry> items = [];

    // 新建文件夹
    if (controller.userInfo.value.permission != null &&
        PermissionHelper.canWrite(controller.userInfo.value)) {
      items.addAll([
        PullDownMenuItem(
          title: 'pull_down_new_folder'.tr,
          icon: CupertinoIcons.folder,
          onTap: () => ObjectHelper.mkdir(
            path: controller.path,
            source: PageSource.DIRECTORY,
            pageTag: tag ?? '',
          ),
        ),
        PullDownMenuDivider.large(),
      ]);
    }

    // 排序
    items.addAll([
      PullDownMenuItem(
        title: '排序',
        icon: CupertinoIcons.arrow_up_arrow_down,
        onTap: () async {
          final selected = await ObjectHelper.showSortMenu(
            controller.sortType.value,
          );
          if (selected != null) {
            controller.changeSortType(selected);
          }
        },
      ),
    ]);

    // 刷新
    items.addAll([
      PullDownMenuItem(
        title: 'pull_down_refresh'.tr,
        icon: CupertinoIcons.refresh,
        onTap: () async => await controller.getDirectoryList(),
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
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        child: controller.root
            ? Icon(FontAwesomeIcons.xmark.data, size: CommonUtils.navIconSize)
            : Icon(
                CupertinoIcons.chevron_back,
                size: CommonUtils.isPad ? 30 : 80.sp,
              ),
        onPressed: () => Get.back(),
      ),
      middle: Text(
        controller.pageTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        width: 360.w,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.download_circle),
              onPressed: () => Get.toNamed(Routes.SETTING_DOWNLOAD),
            ),
            // 多选模式切换
            Obx(
              () => CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(
                  controller.isSelectMode.value
                      ? CupertinoIcons.xmark_circle
                      : CupertinoIcons.checkmark_circle,
                  size: CommonUtils.navIconSize,
                ),
                onPressed: () => controller.toggleSelectMode(),
              ),
            ),
            // 视图切换: 列表 / 网格
            Obx(
              () => CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(
                  controller.layoutType.value == 'grid'
                      ? CupertinoIcons.square_list
                      : CupertinoIcons.square_grid_2x2,
                  size: CommonUtils.navIconSize,
                ),
                onPressed: () {
                  controller.layoutType.value =
                      controller.layoutType.value == 'grid'
                          ? 'list'
                          : 'grid';
                },
              ),
            ),
            Obx(() => _buildPullDownButton()),
            SizedBox(width: 15.w),
            // 移动/复制模式下的直达按钮（仅当有源对象时显示）
            if (controller.srcObject.name != null &&
                controller.srcObject.name!.isNotEmpty)
              CupertinoButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerRight,
                child: Text(controller.isCopy ? 'copy'.tr : 'move'.tr),
                onPressed: controller.moveOrCopy,
              )
          ],
        ),
      ),
    );
  }

  /// SliverList / SliverGrid（根据布局类型）
  Widget _buildSliverList() {
    if (controller.isFirstLoading.isTrue) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 500.h),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (controller.objects.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 300.h),
          child: EmptyState(
            icon: CupertinoIcons.folder_open,
            title: '目录为空',
            description: 'directory_empty_description'.tr,
            action: CupertinoButton(
              child: Text('pull_down_refresh'.tr),
              onPressed: () => controller.getDirectoryList(),
            ),
          ),
        ),
      );
    }

    return Obx(
      () => controller.layoutType.value == 'grid'
          ? _buildSliverGrid()
          : _buildSliverListItems(),
    );
  }

  /// 网格视图
  Widget _buildSliverGrid() {
    return SliverPadding(
      padding: EdgeInsets.only(top: 20.r),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: CommonUtils.isPad ? 130 : 260.w,
          mainAxisExtent: CommonUtils.isPad ? 110 : 150.r,
          mainAxisSpacing: 20.r,
          crossAxisSpacing: 12.w,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            final object = controller.objects[index];
            return FrameSeparateWidget(
              index: index,
              child: Obx(
                () => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (controller.isSelectMode.value) {
                      controller.toggleSelect(object);
                    } else {
                      _openObject(object);
                    }
                  },
                  child: Stack(
                    children: [
                      ObjectGridItem(
                        object: object,
                        isShowPreview: controller.isShowPreview.value,
                      ),
                      if (controller.isSelectMode.value)
                        Positioned(
                          top: 8.r,
                          right: 8.r,
                          child: _buildSelectBadge(object),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: controller.objects.length,
        ),
      ),
    );
  }

  /// 选择角标
  Widget _buildSelectBadge(ObjectModel object) {
    final selected = controller.isSelected(object);
    return Container(
      width: 44.r,
      height: 44.r,
      decoration: BoxDecoration(
        color: selected ? Get.theme.primaryColor : Colors.black26,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.r),
      ),
      child: Icon(
        selected ? Icons.check : Icons.circle_outlined,
        size: 28.r,
        color: Colors.white,
      ),
    );
  }

  /// 列表视图
  Widget _buildSliverListItems() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          final object = controller.objects[index];
          return FrameSeparateWidget(
            index: index,
            child: Obx(
              () => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (controller.isSelectMode.value) {
                    controller.toggleSelect(object);
                  } else {
                    _openObject(object);
                  }
                },
                child: Stack(
                  children: [
                    Column(
                      children: [
                        ObjectListItem(
                          object: object,
                          isShowPreview: controller.isShowPreview.value,
                        ),
                        CommonUtils.isPad
                            ? Divider(height: 1.r, indent: 90, endIndent: 10)
                            : Container(
                                padding: EdgeInsets.only(top: 20.r),
                                child: Divider(
                                    height: 1.r, indent: 190.r, endIndent: 15.r),
                              ),
                      ],
                    ),
                    if (controller.isSelectMode.value)
                      Positioned(
                        top: 12.r,
                        right: 12.r,
                        child: _buildSelectBadge(object),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: controller.objects.length,
      ),
    );
  }

  /// 打开对象（点击进入子目录或预览）
  void _openObject(ObjectModel object) {
    final path =
        '${controller.root ? '' : controller.path}/${object.name}';
    Get.to(
      () => DirectoryPage(tag: path),
      routeName: '${Routes.DIRECTORY}${path}',
      arguments: {
        'path': path,
        'object': object,
        'tag': controller.tag,
        'srcDir': controller.srcDir,
        'srcObject': controller.srcObject,
        'isCopy': controller.isCopy,
        'source': controller.source,
      },
    );
  }

  // ScrollView
  // Replace to [NestedScrollView]
  Widget _buildCustomScrollView() {
    return CustomScrollView(
      shrinkWrap: false,
      controller: controller.scrollController,
      slivers: <Widget>[
        HeaderLocator.sliver(),
        Obx(
          () => SliverPadding(
            padding:
                EdgeInsets.symmetric(horizontal: CommonUtils.isPad ? 15 : 30.r),
            sliver: SizeCacheWidget(child: _buildSliverList()),
          ),
        ),
        FooterLocator.sliver(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      backgroundColor: Get.theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: EasyRefresh(
                controller: controller.easyRefreshController,
                header: CupertinoHeader(
                    position: IndicatorPosition.locator, safeArea: false),
                footer: CupertinoFooter(position: IndicatorPosition.locator),
                onRefresh: () async {
                  await HapticFeedback.selectionClick();
                  await controller.getDirectoryList();
                  controller.easyRefreshController.finishRefresh();
                  controller.easyRefreshController.resetFooter();
                },
                child: _buildCustomScrollView(),
              ),
            ),
            Obx(() {
              // 多选模式: 显示批量操作栏
              if (controller.isSelectMode.value) {
                return _buildBatchActionBar();
              }
              // 移动/复制模式: 显示粘贴底栏
              if (controller.srcObject.name != null &&
                  controller.srcObject.name!.isNotEmpty) {
                return _buildPasteBar();
              }
              return SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  /// 批量操作栏
  Widget _buildBatchActionBar() {
    final isNarrow = Get.width < 400;
    return Container(
      height: CommonUtils.isPad ? 90 : (isNarrow ? 120.h : 140.h),
      decoration: BoxDecoration(
        color: Get.theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(width: 1.r, color: Get.theme.dividerColor),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 30.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _batchAction(
            CupertinoIcons.checkmark_circle,
            Obx(
              () => Text(
                controller.selectedObjects.length == controller.objects.length &&
                        controller.objects.isNotEmpty
                    ? '取消全选'
                    : '全选',
                style: Get.textTheme.bodySmall,
              ),
            ),
            () => controller.selectAll(),
          ),
          _batchAction(
            CupertinoIcons.download_circle,
            Text('下载'),
            () => controller.batchDownload(),
          ),
          _batchAction(
            CupertinoIcons.folder,
            Text('移动'),
            () => controller.batchMoveOrCopy(isCopy: false),
          ),
          _batchAction(
            CupertinoIcons.doc_on_doc,
            Text('复制'),
            () => controller.batchMoveOrCopy(isCopy: true),
          ),
          _batchAction(
            CupertinoIcons.trash,
            Text('删除'),
            () => controller.batchDelete(),
          ),
          _batchAction(
            CupertinoIcons.xmark_circle,
            Text('退出'),
            () => controller.toggleSelectMode(),
          ),
        ],
      ),
    );
  }

  /// 单个批量操作按钮
  Widget _batchAction(
    IconData icon,
    Widget label,
    VoidCallback onTap,
  ) {
    final isNarrow = Get.width < 400;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: CommonUtils.isPad ? 48 : (isNarrow ? 52.sp : 70.sp),
            color: Get.theme.primaryColor,
          ),
          SizedBox(height: 8.h),
          label,
        ],
      ),
    );
  }

  /// 移动/复制粘贴底栏
  Widget _buildPasteBar() {
    return Container(
      height: CommonUtils.isPad ? 80 : 130.h,
      decoration: BoxDecoration(
        color: Get.theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(width: 1.r, color: Get.theme.dividerColor),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 30.r, vertical: 20.r),
      child: Row(
        children: [
          Icon(
            FileType.getIcon(
              controller.srcObject.type ?? 0,
              controller.srcObject.name ?? '',
            ),
            size: CommonUtils.isPad ? 60 : 100.sp,
            color: Get.theme.primaryColor,
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.isCopy ? 'copy'.tr : 'move'.tr,
                  style: Get.textTheme.bodySmall,
                ),
                SizedBox(height: 4.h),
                Text(
                  controller.srcObject.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Get.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          // 粘贴到此处
          CupertinoButton(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              'paste_to_here'.tr,
              style: TextStyle(
                color: Get.theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => ObjectHelper.paste(
              path: controller.path,
              source: controller.source,
              pageTag: controller.tag,
            ),
          ),
          // 取消操作
          CupertinoButton(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Text('cancel'.tr),
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }
}

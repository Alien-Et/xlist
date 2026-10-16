import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/services/index.dart';
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
        width: 240.w,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.download_circle),
              onPressed: () => Get.toNamed(Routes.SETTING_DOWNLOAD),
            ),
            SizedBox(width: 30.w),
            // 移动/复制模式下的直达按钮（仅当有源对象时显示）
            if (controller.srcObject.name != null &&
                controller.srcObject.name!.isNotEmpty)
              CupertinoButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerRight,
                child: Text(controller.isCopy ? 'copy'.tr : 'move'.tr),
                // 单文件移动/复制：执行完成后返回长按前的界面（回退所有选择目录层）
                onPressed: () async {
                  await controller.moveOrCopy();
                  _finishPaste();
                },
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
      () => KeyedSubtree(
        // key 绑定布局+排序+多选+数据版本：变化时强制重建，避免 keframe 缓存
        // 残留旧索引内容 / 多选选中态不刷新 / 重命名后点开旧对象
        key: ValueKey(
            '${controller.layoutType.value}-${controller.sortType.value}-${controller.isSelectMode.value}-${controller.dataVersion}'),
        child: controller.layoutType.value == 'grid'
            ? _buildSliverGrid()
            : _buildSliverListItems(),
      ),
    );
  }

  /// 网格视图
  Widget _buildSliverGrid() {
    return SliverPadding(
      padding: EdgeInsets.only(top: 20.r),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          // 与主页文件网格参数保持一致，避免选择目录时卡片更密更挤
          maxCrossAxisExtent: CommonUtils.isPad ? 120 : 280.w,
          mainAxisExtent: CommonUtils.isPad ? 110 : 100,
          mainAxisSpacing: CommonUtils.isPad ? 10 : 0,
          crossAxisSpacing: CommonUtils.isPad ? 10 : 8,
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
                  onLongPress: () {
                    // 长按 → 进入多选并选中该文件，底部显示二级操作栏
                    // （选目标文件夹模式：仅长按菜单需被拦截？保持选目录流程纯粹，禁用长按）
                    if (!controller.isSelectMode.value &&
                        !(controller.srcObject.name?.isNotEmpty ?? false) &&
                        controller.srcObjects.isEmpty) {
                      controller.enterSelectMode(object);
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
                onLongPress: () {
                  // 长按 → 进入多选并选中该文件，底部显示二级操作栏
                  // （选目标文件夹模式：保持选目录流程纯粹，禁用长按）
                  if (!controller.isSelectMode.value &&
                      !(controller.srcObject.name?.isNotEmpty ?? false) &&
                      controller.srcObjects.isEmpty) {
                    controller.enterSelectMode(object);
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
        // 底部留白，避免悬浮导航栏遮挡最后一行
        SliverToBoxAdapter(child: SizedBox(height: 180.h)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope 拦截系统返回键与边缘滑动返回：
    // - 多选模式：先退出多选与二级操作栏（再按一次返回上一级/退出）
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (controller.isSelectMode.value) {
          controller.toggleSelectMode();
          return;
        }
        Get.back();
      },
      child: CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      backgroundColor: Get.theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
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
              ],
            ),
            Obx(() {
              // 多选模式: 显示批量操作栏
              if (controller.isSelectMode.value) {
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: _buildBatchActionBar(),
                );
              }
              // 移动/复制模式: 显示粘贴底栏
              if (controller.srcObject.name != null &&
                  controller.srcObject.name!.isNotEmpty) {
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildPasteBar(),
                );
              }
              // 普通模式: 显示底部悬浮圆角导航栏
              return Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: _buildFloatingNavBar(),
              );
            }),
          ],
        ),
      ),
      ),
    );
  }

  /// 底部悬浮圆角导航栏（排序/布局/刷新/新建；多选入口已并入长按菜单）
  Widget _buildFloatingNavBar() {
    final canWrite = controller.userInfo.value.permission != null &&
        PermissionHelper.canWrite(controller.userInfo.value);
    return FloatingNavBar(
      items: [
        FloatingNavItem(
          icon: CupertinoIcons.arrow_up_arrow_down,
          label: '排序',
          onTap: () async {
            final selected = await ObjectHelper.showSortMenu(
              controller.sortType.value,
            );
            if (selected != null) {
              controller.changeSortType(selected);
            }
          },
        ),
        FloatingNavItem(
          icon: controller.layoutType.value == 'grid'
              ? CupertinoIcons.square_list
              : CupertinoIcons.square_grid_2x2,
          label: '布局',
          onTap: () => controller.toggleLayoutType(),
        ),
        FloatingNavItem(
          icon: CupertinoIcons.refresh,
          label: '刷新',
          onTap: () async => await controller.getDirectoryList(),
        ),
        if (canWrite)
          FloatingNavItem(
            icon: CupertinoIcons.folder,
            label: '新建',
            onTap: () => ObjectHelper.mkdir(
              path: controller.path,
              source: PageSource.DIRECTORY,
              pageTag: tag ?? '',
            ),
          ),
      ],
    );
  }

  /// 二级操作导航栏（多选模式底部，导航栏同款 UI，可横向滑动）
  /// 属性/下载/移动/复制/删除/重命名/复制链接/完成
  Widget _buildBatchActionBar() {
    return FloatingActionBar(
      items: [
        FloatingNavItem(
          icon: CupertinoIcons.info_circle,
          label: '属性',
          onTap: () => _actionProperties(),
        ),
        FloatingNavItem(
          icon: CupertinoIcons.download_circle,
          label: '下载文件',
          onTap: () => _actionDownload(),
        ),
        FloatingNavItem(
          icon: CupertinoIcons.folder,
          label: '移动',
          onTap: () => _actionMove(),
        ),
        FloatingNavItem(
          icon: CupertinoIcons.doc_on_doc,
          label: '复制',
          onTap: () => _actionCopy(),
        ),
        FloatingNavItem(
          icon: CupertinoIcons.trash,
          label: '删除',
          onTap: () => _actionDelete(),
        ),
        FloatingNavItem(
          icon: CupertinoIcons.pencil,
          label: '重命名',
          onTap: () => _actionRename(),
        ),
        FloatingNavItem(
          icon: CupertinoIcons.link,
          label: '复制链接',
          onTap: () => _actionCopyLink(),
        ),
        FloatingNavItem(
          icon: CupertinoIcons.xmark_circle,
          label: '完成',
          onTap: () => controller.toggleSelectMode(),
        ),
      ],
    );
  }

  // ---- 二级操作栏动作（单个对象走单文件逻辑，多个走批量逻辑）----

  /// 粘贴完成：回退所有"选择目标文件夹"层，返回长按前的来源界面
  void _finishPaste() {
    final fromRoute = Get.arguments['fromRoute'] as String?;
    if (fromRoute != null && fromRoute.isNotEmpty) {
      Get.until((route) => route.settings.name == fromRoute);
    } else {
      Get.back();
    }
  }

  void _exitSelect() {
    if (controller.isSelectMode.value) controller.toggleSelectMode();
  }

  ObjectModel? _single() {
    if (controller.selectedObjects.length == 1) {
      return controller.selectedObjects.first;
    }
    return null;
  }

  void _actionProperties() {
    final obj = _single();
    if (obj == null) {
      SmartDialog.showToast('请仅选择一个文件查看属性');
      return;
    }
    _exitSelect();
    ObjectHelper.showFileProperties(obj);
  }

  void _actionDownload() {
    final obj = _single();
    if (obj == null) {
      controller.batchDownload();
      return;
    }
    _exitSelect();
    final path = controller.path;
    if (obj.isDir == true) {
      DownloadHelper.directory(path, obj.name!);
    } else {
      DownloadHelper.file(path, obj.name!, obj.type ?? 0, obj.size ?? 0);
    }
  }

  void _actionMove() {
    final obj = _single();
    if (obj == null) {
      controller.batchMoveOrCopy(isCopy: false);
      return;
    }
    _exitSelect();
    Get.toNamed(Routes.DIRECTORY, arguments: {
      'srcDir': controller.path,
      'srcObject': obj,
      'root': true,
      'isCopy': false,
      'source': PageSource.DIRECTORY,
      'tag': controller.tag,
      'fromRoute': Get.currentRoute,
    });
  }

  void _actionCopy() {
    final obj = _single();
    if (obj == null) {
      controller.batchMoveOrCopy(isCopy: true);
      return;
    }
    _exitSelect();
    Get.toNamed(Routes.DIRECTORY, arguments: {
      'srcDir': controller.path,
      'srcObject': obj,
      'root': true,
      'isCopy': true,
      'source': PageSource.DIRECTORY,
      'tag': controller.tag,
      'fromRoute': Get.currentRoute,
    });
  }

  void _actionDelete() {
    final obj = _single();
    if (obj == null) {
      controller.batchDelete();
      return;
    }
    _exitSelect();
    ObjectHelper.remove(
      path: controller.path,
      name: obj.name!,
      source: PageSource.DIRECTORY,
      pageTag: controller.tag,
    );
  }

  void _actionRename() {
    final obj = _single();
    if (obj == null) {
      SmartDialog.showToast('请仅选择一个文件重命名');
      return;
    }
    _exitSelect();
    ObjectHelper.rename(
      path: controller.path,
      object: obj,
      source: PageSource.DIRECTORY,
      pageTag: controller.tag,
    );
  }

  void _actionCopyLink() {
    final obj = _single();
    if (obj == null) {
      SmartDialog.showToast('请仅选择一个文件复制链接');
      return;
    }
    _exitSelect();
    final userInfo =
        Get.find<CoreService>().currentUser.value ?? UserModel();
    ObjectHelper.copyLink(
      controller.path,
      object: obj,
      userInfo: userInfo,
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
          // 粘贴到此处（执行移动/复制并返回来源页）
          CupertinoButton(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              'paste_to_here'.tr,
              style: TextStyle(
                color: Get.theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () async {
              await controller.confirmPaste();
              _finishPaste();
            },
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

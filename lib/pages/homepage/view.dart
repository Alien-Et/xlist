import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/pages/homepage/index.dart';
import 'package:xlist/components/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/models/index.dart';

class Homepage extends GetView<HomepageController> {
  const Homepage({Key? key}) : super(key: key);

  Widget _buildGridView() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        // 长按空白处显示上下文菜单，仅包含粘贴选项
        if (ObjectHelper.clipboardData != null && ObjectHelper.clipboardOperation != ClipboardOperation.none) {
          showModalActionSheet(
            context: Get.context!,
            actions: [
              SheetAction(
                label: '粘贴',
                key: 'paste',
              ),
            ],
            cancelLabel: '取消',
          ).then((value) {
            if (value == 'paste') {
              ObjectHelper.paste(
                path: controller.currentPath.value,
                source: 'HOMEPAGE',
                pageTag: '',
              );
            }
          });
        }
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: CommonUtils.isPad ? 120 : 280.w,
                mainAxisExtent: 100,
                mainAxisSpacing: 0,
                crossAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final object = controller.objects.value[index];
                  
                  return FrameSeparateWidget(
                    index: index,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (controller.isSelectMode.value) {
                          controller.toggleSelect(object);
                        } else {
                          ObjectHelper.click(
                            path: controller.currentPath.value,
                            type: object.type ?? 0,
                            name: object.name ?? '',
                            objects: controller.objects.value,
                          );
                        }
                      },
                      onLongPress: () {
                        if (!controller.isSelectMode.value) {
                          ObjectHelper.showContextMenu(
                            path: controller.currentPath.value,
                            object: object,
                            objects: controller.objects.value,
                            source: 'HOMEPAGE',
                            pageTag: '',
                          );
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
                              top: 6.r,
                              right: 6.r,
                              child: _buildSelectBadge(object),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: controller.objects.value.length,
              ),
            ),
          ),
          // 底部留白，避免悬浮导航栏遮挡最后一行
          SliverToBoxAdapter(child: SizedBox(height: 180.h)),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final object = controller.objects.value[index];
              
              return FrameSeparateWidget(
                index: index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (controller.isSelectMode.value) {
                      controller.toggleSelect(object);
                    } else {
                      ObjectHelper.click(
                        path: controller.currentPath.value,
                        type: object.type ?? 0,
                        name: object.name ?? '',
                        objects: controller.objects.value,
                      );
                    }
                  },
                  onLongPress: () {
                    if (!controller.isSelectMode.value) {
                      ObjectHelper.showContextMenu(
                        path: controller.currentPath.value,
                        object: object,
                        objects: controller.objects.value,
                        source: 'HOMEPAGE',
                        pageTag: '',
                      );
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
                          Container(
                            padding: EdgeInsets.only(top: CommonUtils.isPad ? 0 : 20.r),
                            child: CommonUtils.isPad
                                ? Divider(height: 1.r, indent: 90, endIndent: 10)
                                : Divider(height: 1.r, indent: 190.r, endIndent: 15.r),
                          ),
                        ],
                      ),
                      if (controller.isSelectMode.value)
                        Positioned(
                          top: 10.r,
                          right: 10.r,
                          child: _buildSelectBadge(object),
                        ),
                    ],
                  ),
                ),
              );
            },
            childCount: controller.objects.value.length,
          ),
        ),
        // 底部留白，避免悬浮导航栏遮挡最后一行
        SliverToBoxAdapter(child: SizedBox(height: 180.h)),
      ],
    );
  }

  /// 面包屑路径导航
  Widget _buildBreadcrumb() {
    final path = controller.currentPath.value;
    final parts = path == '/'
        ? <String>[]
        : path.split('/').where((p) => p.isNotEmpty).toList();

    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _crumbItem('/root'.tr, 0),
          for (var i = 0; i < parts.length; i++)
            _crumbItem(parts[i], i + 1, isLast: i == parts.length - 1),
        ],
      ),
    );
  }

  /// 单个面包屑项
  Widget _crumbItem(String name, int depth, {bool isLast = false}) {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isLast ? null : () => controller.navigateToPath(_pathAt(depth)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                color: isLast
                    ? Get.theme.textTheme.bodyLarge?.color
                    : Get.theme.primaryColor,
              ),
            ),
          ),
        ),
        if (!isLast)
          Icon(
            CupertinoIcons.chevron_right,
            size: 12,
            color: Get.theme.dividerColor,
          ),
      ],
    );
  }

  /// 根据深度计算路径
  String _pathAt(int depth) {
    final parts = controller.currentPath.value
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();
    if (depth <= 0) return '/';
    return '/${parts.take(depth).join('/')}';
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

  /// 底部悬浮圆角导航栏（多选/排序/布局/刷新）
  Widget _buildFloatingNavBar() {
    return FloatingNavBar(
      items: [
        FloatingNavItem(
          icon: CupertinoIcons.checkmark_circle,
          label: '多选',
          onTap: () => controller.toggleSelectMode(),
        ),
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
          onTap: () {
            controller.layoutType.value =
                controller.layoutType.value == 'grid' ? 'list' : 'grid';
          },
        ),
        FloatingNavItem(
          icon: CupertinoIcons.refresh,
          label: '刷新',
          onTap: () => controller.getObjectList(refresh: true),
        ),
      ],
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
                controller.selectedObjects.length == controller.objects.value.length &&
                        controller.objects.value.isNotEmpty
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

  @override
  Widget build(BuildContext context) {
    // PopScope 拦截系统返回键与边缘滑动返回：
    // - 非根目录：返回上一级（与安卓系统返回逻辑一致）
    // - 根目录：允许退出应用
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (controller.currentPath.value != '/') {
          controller.navigateUp();
        } else {
          SystemNavigator.pop();
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Get.isDarkMode ? Color.fromARGB(255, 18, 18, 18) : Colors.white,
          border: Border.all(width: 0, color: Colors.transparent),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Icon(CupertinoIcons.umbrella_fill, size: CommonUtils.navIconSize),
                onPressed: () => Get.toNamed(Routes.SETTING)
                    ?.then((value) => controller.getObjectList()),
              ),
              CupertinoButton(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Icon(CupertinoIcons.download_circle, size: CommonUtils.navIconSize),
                onPressed: () => Get.toNamed(Routes.SETTING_DOWNLOAD),
              ),
            ],
          ),
          middle: Container(
            width: Get.width * 0.6,
            height: 36,
            child: Obx(() {
              // 提取当前目录名称
              String currentDirName = controller.currentPath.value;
              if (currentDirName != '/') {
                final parts = currentDirName.split('/').where((part) => part.isNotEmpty).toList();
                if (parts.isNotEmpty) {
                  currentDirName = parts.last;
                }
              }
              
              return CupertinoTextField(
                controller: TextEditingController(text: currentDirName),
                placeholder: currentDirName,
                placeholderStyle: TextStyle(color: Colors.grey),
                style: TextStyle(color: Get.theme.textTheme.bodyLarge?.color),
                decoration: BoxDecoration(
                  color: Get.isDarkMode ? Color.fromARGB(255, 40, 40, 40) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16),
                onSubmitted: (value) {
                  controller.handleAddressInput(value);
                },
                onChanged: (value) {
                  controller.searchQuery.value = value;
                },
                suffix: IconButton(
                  icon: Icon(CupertinoIcons.search, size: 20, color: Get.theme.textTheme.bodyLarge?.color),
                  onPressed: () {
                    controller.handleSearch(controller.searchQuery.value);
                  },
                ),
              );
            }),
          ),
          // 顶栏精简：多选/排序/布局已移入底部悬浮导航栏
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 30.w),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 面包屑路径导航
                  Obx(
                    () => controller.searchQuery.value.isEmpty &&
                            controller.isServerConfigured &&
                            controller.objects.value.isNotEmpty
                        ? _buildBreadcrumb()
                        : SizedBox.shrink(),
                  ),
                  // 搜索进度
                  Obx(() {
                    if (!controller.isSearching.value) {
                      return SizedBox.shrink();
                    }
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(minHeight: 4),
                            ),
                          ),
                          SizedBox(width: 12),
                          Obx(
                            () => Text(
                              '已扫描 ${controller.searchedCount.value} 个目录',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '取消',
                              style: TextStyle(color: Get.theme.primaryColor),
                            ),
                            onPressed: () => controller.cancelSearch(),
                          ),
                        ],
                      ),
                    );
                  }),
                  Expanded(
                    child: Obx(() {
                  if (controller.isFirstLoading.isTrue) {
                    return Center(
                      child: CupertinoActivityIndicator(),
                    );
                  }
                  final fileCount = controller.objects.value.length;
                  final isServerConfigured = controller.isServerConfigured;
                  
                  
                  if (!isServerConfigured) {
                  // 未配置服务器，显示配置提示
                  return Container(
                    padding: EdgeInsets.all(16),
                    color: Get.isDarkMode ? Color.fromARGB(255, 18, 18, 18) : Colors.white,
                    child: EmptyState(
                      icon: CupertinoIcons.cloud,
                      title: '未配置服务器',
                      description: '请先添加一个 WebDAV 服务器，即可浏览和同步云端文件',
                      action: CupertinoButton(
                        child: Text('添加服务器'),
                        onPressed: () async {
                          // 直接导航到服务器设置页面
                          await Get.toNamed(Routes.SETTING_SERVER);
                          // 刷新主页数据
                          controller.getObjectList();
                        },
                      ),
                    ),
                  );
                } else if (fileCount == 0) {
                  // 已配置服务器但目录为空 / 搜索无结果
                  final isSearchResult =
                      controller.searchQuery.value.isNotEmpty &&
                          !controller.isSearching.value;
                  return Container(
                    padding: EdgeInsets.all(16),
                    color: Get.isDarkMode ? Color.fromARGB(255, 18, 18, 18) : Colors.white,
                    child: EmptyState(
                      icon: isSearchResult
                          ? CupertinoIcons.search
                          : CupertinoIcons.folder_open,
                      title: isSearchResult
                          ? '未找到结果'
                          : (controller.errorMessage.value.isNotEmpty
                              ? controller.errorMessage.value
                              : '目录为空'),
                      description: isSearchResult
                          ? '没有找到与“${controller.searchQuery.value}”匹配的文件'
                          : '当前目录下没有文件或文件夹',
                      action: isSearchResult
                          ? null
                          : CupertinoButton(
                              child: Text('刷新'),
                              onPressed: () {
                                controller.getObjectList();
                              },
                            ),
                    ),
                  );
                } else {
                  // 显示文件列表
                  return controller.layoutType.value == 'grid' ? _buildGridView() : _buildListView();
                }
                      }),
                  ),
                ],
              ),
              // 底部：多选模式显示批量操作栏，否则显示悬浮圆角导航栏
              Obx(
                () => controller.isSelectMode.value
                    ? Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildBatchActionBar(),
                      )
                    : Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: _buildFloatingNavBar(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

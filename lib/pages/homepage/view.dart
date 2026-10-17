import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/services/index.dart';
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
      // 注：长按空白"粘贴"入口已随剪贴板机制移除（移动/复制均为选目录即执行；"剪切"与"移动"同义已合并）
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
                        // 长按 → 进入多选并选中该文件，底部显示二级操作栏
                        if (!controller.isSelectMode.value) {
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
                              top: 6.r,
                              right: 6.r,
                              child: Obx(() => _buildSelectBadge(object)),
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
                    // 长按 → 进入多选并选中该文件，底部显示二级操作栏
                    if (!controller.isSelectMode.value) {
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
                          child: Obx(() => _buildSelectBadge(object)),
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

  /// 底部悬浮圆角导航栏（排序/布局/刷新/下载/设置；多选入口已并入长按菜单）
  Widget _buildFloatingNavBar() {
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
          onTap: () => controller.getObjectList(
            refresh: true,
            path: controller.currentPath.value,
          ),
        ),
        FloatingNavItem(
          icon: CupertinoIcons.arrow_down_circle,
          label: '下载',
          onTap: () => Get.toNamed(Routes.SETTING_DOWNLOAD),
        ),
        FloatingNavItem(
          icon: CupertinoIcons.settings,
          label: '设置',
          onTap: () => Get.toNamed(Routes.SETTING)?.then(
            (value) => controller.getObjectList(
              path: controller.currentPath.value,
            ),
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
    final path = controller.currentPath.value;
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
      'srcDir': controller.currentPath.value,
      'srcObject': obj,
      'root': true,
      'isCopy': false,
      'source': PageSource.HOMEPAGE,
      'tag': '',
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
      'srcDir': controller.currentPath.value,
      'srcObject': obj,
      'root': true,
      'isCopy': true,
      'source': PageSource.HOMEPAGE,
      'tag': '',
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
      path: controller.currentPath.value,
      name: obj.name!,
      source: PageSource.HOMEPAGE,
      pageTag: '',
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
      path: controller.currentPath.value,
      object: obj,
      source: PageSource.HOMEPAGE,
      pageTag: '',
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
      controller.currentPath.value,
      object: obj,
      userInfo: userInfo,
    );
  }

  /// 单个批量操作按钮

  @override
  Widget build(BuildContext context) {
    // PopScope 拦截系统返回键与边缘滑动返回：
    // - 多选模式：先退出多选与二级操作栏
    // - 非根目录：返回上一级（与安卓系统返回逻辑一致）
    // - 根目录：允许退出应用
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (controller.isSelectMode.value) {
          controller.toggleSelectMode();
          return;
        }
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
          middle: _HomeSearchField(
            onSubmitted: (value) => controller.handleAddressInput(value),
            onChanged: (value) => controller.searchQuery.value = value,
            onSearchTap: () =>
                controller.handleSearch(controller.searchQuery.value),
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
                  // 连接/加载错误：统一优雅错误背景（少量文字 + 重试）
                  if (!isSearchResult &&
                      controller.errorMessage.value.isNotEmpty) {
                    return ConnectionErrorView(
                      message: controller.errorMessage.value,
                      onRetry: () => controller.getObjectList(
                        path: controller.currentPath.value,
                      ),
                      // 服务器不可用：提供新建服务器快捷入口
                      onCreateServer: () => Get.toNamed(Routes.SETTING_SERVER),
                    );
                  }
                  return Container(
                    padding: EdgeInsets.all(16),
                    color: Get.isDarkMode ? Color.fromARGB(255, 18, 18, 18) : Colors.white,
                    child: EmptyState(
                      icon: isSearchResult
                          ? CupertinoIcons.search
                          : CupertinoIcons.folder_open,
                      title: isSearchResult
                          ? '未找到结果'
                          : '目录为空',
                      description: isSearchResult
                          ? '没有找到与“${controller.searchQuery.value}”匹配的文件'
                          : '当前目录下没有文件或文件夹',
                      action: isSearchResult
                          ? null
                          : CupertinoButton(
                              child: Text('刷新'),
                              onPressed: () {
                                controller.getObjectList(
                                  path: controller.currentPath.value,
                                );
                              },
                            ),
                    ),
                  );
                } else {
                  // 显示文件列表
                  // key 绑定布局+排序+多选+数据版本：变化时强制重建列表，
                  // 避免 keframe 帧缓存残留旧索引/旧选中态/旧文件对象（重命名后点不开的根因）
                  return KeyedSubtree(
                    key: ValueKey(
                        '${controller.layoutType.value}-${controller.sortType.value}-${controller.isSelectMode.value}-${controller.dataVersion}'),
                    child: controller.layoutType.value == 'grid'
                        ? _buildGridView()
                        : _buildListView(),
                  );
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
                        bottom: 16,
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

/// 顶栏搜索框
/// StatefulWidget 持有稳定的 TextEditingController：
/// 避免旧实现（每次 build 新建 controller + Obx 包裹）导致输入时被重建、焦点丢失、无法点击
class _HomeSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchTap;

  const _HomeSearchField({
    Key? key,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSearchTap,
  }) : super(key: key);

  @override
  State<_HomeSearchField> createState() => _HomeSearchFieldState();
}

class _HomeSearchFieldState extends State<_HomeSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.isDarkMode;
    return Container(
      width: Get.width * 0.6,
      height: 36,
      child: CupertinoTextField(
        controller: _controller,
        placeholder: '搜索',
        placeholderStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.grey,
        ),
        style: TextStyle(
          color: Get.theme.textTheme.bodyLarge?.color ??
              (isDark ? Colors.white : Colors.black),
        ),
        decoration: BoxDecoration(
          // 搜索框底色保持透明，直接透出页面背景色，任何主题下都与背景一致；
          // 仅保留圆角与浅色描边标识输入框位置
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16),
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        suffix: IconButton(
          icon: Icon(
            CupertinoIcons.search,
            size: 20,
            color: isDark
                ? Colors.white70
                : Get.theme.textTheme.bodyLarge?.color,
          ),
          onPressed: widget.onSearchTap,
        ),
      ),
    );
  }
}

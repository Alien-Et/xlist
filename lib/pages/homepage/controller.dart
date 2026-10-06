import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/models/object.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/services/core_service.dart';
import 'package:xlist/database/entity/index.dart';
import 'package:xlist/helper/index.dart';

class HomepageController extends GetxController {
  final objects = Rx<List<ObjectModel>>([]);
  final isFirstLoading = true.obs;
  final serverId = 0.obs;
  final layoutType = 'grid'.obs;
  final isShowPreview = true.obs;
  final sortType = SortType.TIME_DESC.obs;

  // 多选模式
  final isSelectMode = false.obs;
  final selectedObjects = <ObjectModel>[].obs;
  final userInfo = Rx<dynamic>(null);
  final errorMessage = "".obs;
  final currentPath = "".obs;
  final searchQuery = "".obs;
  final isSearching = false.obs;
  final searchedCount = 0.obs; // 已扫描目录数
  bool _cancelSearch = false;

  final EasyRefreshController easyRefreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );
  final ScrollController scrollController = ScrollController();

  CoreService? coreService;

  @override
  void onInit() {
    super.onInit();

    // 初始化 CoreService
    _initCoreService();

    // 延迟获取文件列表，确保CoreService已完全初始化
    Future.delayed(Duration(milliseconds: 500), () {
      getObjectList();
    });
  }

  // 初始化 CoreService
  void _initCoreService() {
    try {
      coreService = CoreService.to;
      serverId.value = coreService?.userStorage.serverId.value ?? 0;
    } catch (e) {
      coreService = null;
      errorMessage.value = '核心服务初始化失败';
    }
  }

  // 检查服务器是否配置
  bool get isServerConfigured {
    bool configured = coreService != null && coreService!.currentServer.value != null;
    if (coreService != null) {
    }
    return configured;
  }

  // 获取当前服务器
  ServerEntity? get currentServer {
    return coreService?.currentServer.value;
  }

  Future<void> getObjectList({bool refresh = false, String path = '/'}) async {
    isFirstLoading.value = true;
    errorMessage.value = '';
    currentPath.value = path;

    try {
      
      // 检查 CoreService 是否初始化
      if (coreService == null) {
        _initCoreService();
        if (coreService == null) {
          throw Exception('核心服务不可用');
        }
      } else {
      }

      // 确保服务器配置已经加载
      if (coreService!.currentServer.value == null) {
        await coreService!.loadRecentServer();
        if (coreService!.currentServer.value == null) {
          objects.value = [];
          return;
        }
      } else {
        // 即使服务器已经加载，也再次确认，确保配置正确
        await coreService!.loadRecentServer();
        if (coreService!.currentServer.value == null) {
          objects.value = [];
          return;
        }
      }

      // 使用 CoreService 获取 WebDAV 文件列表
      
      // 测试WebDAV连接
      
      // 生产阶段使用真实数据
      final files = await coreService!.getWebDAVFiles(
        path,
        onError: (error) {
          errorMessage.value = error.message;
        },
      );
      
      // 开发阶段使用模拟数据，验证UI是否正常
      // final files = await coreService!.getMockWebDAVFiles(path);
      
      objects.value = ObjectHelper.sortObjects(files, sortType.value);
    } catch (e) {
      objects.value = [];
      errorMessage.value = '获取文件列表失败: ${e.toString()}';
    } finally {
      isFirstLoading.value = false;
    }
  }

  Future<dynamic> resetUserToken(dynamic server, {bool force = false}) async {
    try {
      
      if (coreService == null) {
        _initCoreService();
        if (coreService == null) {
          throw Exception('CoreService not available');
        }
      }

      await coreService!.refreshAllData();
      serverId.value = coreService!.userStorage.serverId.value;
      return coreService!.currentUser.value;
    } catch (e) {
      return null;
    }
  }

  Future<void> addToFavorites(ObjectModel object) async {
    try {
      if (coreService == null) {
        _initCoreService();
        if (coreService == null) {
          throw Exception('CoreService not available');
        }
      }

      await coreService!.addToFavorites(object);
    } catch (e) {
    }
  }

  Future<void> addToRecent(ObjectModel object) async {
    try {
      if (coreService == null) {
        _initCoreService();
        if (coreService == null) {
          throw Exception('CoreService not available');
        }
      }

      await coreService!.addToRecent(object);
    } catch (e) {
    }
  }

  Future<void> downloadObject(ObjectModel object) async {
    try {
      if (coreService == null) {
        _initCoreService();
        if (coreService == null) {
          throw Exception('CoreService not available');
        }
      }

      await coreService!.downloadFile(object);
    } catch (e) {
    }
  }

  // 切换布局类型
  void toggleLayoutType() {
    layoutType.value = layoutType.value == 'grid' ? 'list' : 'grid';
  }

  // 切换排序类型
  void changeSortType(int type) {
    sortType.value = type;
    objects.value = ObjectHelper.sortObjects(objects.value, type);
  }

  // 进入 / 退出多选模式
  void toggleSelectMode() {
    isSelectMode.value = !isSelectMode.value;
    selectedObjects.clear();
  }

  // 切换单个对象选中状态
  void toggleSelect(ObjectModel object) {
    if (selectedObjects.contains(object)) {
      selectedObjects.remove(object);
    } else {
      selectedObjects.add(object);
    }
  }

  // 判断对象是否已选中
  bool isSelected(ObjectModel object) {
    return selectedObjects.contains(object);
  }

  // 全选 / 取消全选
  void selectAll() {
    if (selectedObjects.length == objects.value.length) {
      selectedObjects.clear();
    } else {
      selectedObjects.assignAll(objects.value);
    }
  }

  // 批量下载
  Future<void> batchDownload() async {
    final selected = List<ObjectModel>.from(selectedObjects);
    toggleSelectMode();
    await ObjectHelper.batchDownload(selected, currentPath.value);
  }

  // 批量移动 / 复制
  Future<void> batchMoveOrCopy({required bool isCopy}) async {
    final selected = List<ObjectModel>.from(selectedObjects);
    toggleSelectMode();
    await ObjectHelper.batchMoveOrCopy(
      objects: selected,
      srcDir: currentPath.value,
      isCopy: isCopy,
      source: PageSource.HOMEPAGE,
      pageTag: '',
    );
  }

  // 批量删除
  Future<void> batchDelete() async {
    final selected = List<ObjectModel>.from(selectedObjects);
    toggleSelectMode();
    await ObjectHelper.batchDelete(
      objects: selected,
      path: currentPath.value,
      source: PageSource.HOMEPAGE,
      pageTag: '',
    );
  }

  // 切换预览显示
  void togglePreview() {
    isShowPreview.value = !isShowPreview.value;
  }

  // 导航到上级目录
  void navigateUp() {
    if (currentPath.value != '/') {
      final path = currentPath.value.substring(0, currentPath.value.lastIndexOf('/'));
      getObjectList(path: path.isEmpty ? '/' : path);
    }
  }

  // 导航到路径
  void navigateToPath(String path) {
    getObjectList(path: path);
  }

  // 处理搜索
  Future<void> handleSearch(String query) async {
    if (query.isEmpty) {
      // 如果查询为空，显示当前路径的文件
      getObjectList(path: currentPath.value);
      return;
    }

    isSearching.value = true;
    _cancelSearch = false;
    searchedCount.value = 0;
    try {
      // 全局搜索实现，递归搜索所有子目录
      final allFiles = await _searchRecursive('/', 0, (count) {
        searchedCount.value = count;
      });
      if (_cancelSearch) return;
      final filteredFiles = allFiles.where((file) {
        return file.name?.toLowerCase().contains(query.toLowerCase()) ?? false;
      }).toList();
      objects.value = filteredFiles;
    } catch (e) {
      objects.value = [];
    } finally {
      isSearching.value = false;
    }
  }

  // 取消搜索
  void cancelSearch() {
    _cancelSearch = true;
    isSearching.value = false;
  }

  // 递归搜索所有子目录
  Future<List<ObjectModel>> _searchRecursive(
    String path,
    int depth,
    void Function(int count) onProgress,
  ) async {
    final results = <ObjectModel>[];

    // 已取消则停止
    if (_cancelSearch) return results;

    try {
      final files = await coreService!.getWebDAVFiles(path);
      onProgress(depth);

      for (final file in files) {
        if (_cancelSearch) return results;
        results.add(file);

        // 如果是目录，递归搜索
        if (file.isDir == true) {
          final subPath = path == '/' ? '/${file.name}' : '$path/${file.name}';
          final subResults = await _searchRecursive(subPath, depth + 1, onProgress);
          results.addAll(subResults);
        }
      }
    } catch (e) {
    }

    return results;
  }

  // 处理地址栏输入
  void handleAddressInput(String input) {
    if (input.isEmpty) return;

    // 检查是否是路径
    if (input.startsWith('/')) {
      // 是路径，导航到该路径
      navigateToPath(input);
    } else {
      // 不是路径，执行搜索
      handleSearch(input);
    }
  }
} 

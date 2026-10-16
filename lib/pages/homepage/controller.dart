import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/models/object.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/services/core_service.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/database/entity/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:xlist/repositorys/index.dart';

class HomepageController extends GetxController {
  final objects = Rx<List<ObjectModel>>([]);
  // 数据版本：列表内容更新时自增，用于 keframe 帧缓存 key 强制重建
  int dataVersion = 0;
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

    // 从本地读取持久化的排序/布局设置
    try {
      final pref = Get.find<PreferencesStorage>();
      sortType.value = pref.sortType.val ?? SortType.TIME_DESC;
      final savedLayout = pref.layoutType.val;
      if (savedLayout == 0) {
        layoutType.value = 'grid';
      } else if (savedLayout == 1) {
        layoutType.value = 'list';
      }
    } catch (_) {
      // 读取失败使用默认值
    }

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
    return coreService != null && coreService!.currentServer.value != null;
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

      objects.value = ObjectHelper.sortObjects(files, sortType.value);
      // 数据版本 +1：强制列表 key 变化，使 keframe 帧缓存重建（重命名/刷新后立即可见）
      dataVersion++;
      // 浏览时自动写入本地文件索引（搜索先查索引，加快搜索）
      FileIndexService.saveObjects(
        serverId: Get.find<UserStorage>().serverId.value,
        path: currentPath.value,
        objects: objects.value,
      );
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

  // 切换布局类型
  void toggleLayoutType() {
    layoutType.value = layoutType.value == 'grid' ? 'list' : 'grid';
    // 持久化布局设置
    try {
      Get.find<PreferencesStorage>().layoutType.val =
          layoutType.value == 'grid' ? 0 : 1;
    } catch (_) {}
  }

  // 切换排序类型
  void changeSortType(int type) {
    sortType.value = type;
    objects.value = ObjectHelper.sortObjects(objects.value, type);
    // 持久化排序设置
    try {
      Get.find<PreferencesStorage>().sortType.val = type;
    } catch (_) {}
  }

  // 进入 / 退出多选模式
  void toggleSelectMode() {
    isSelectMode.value = !isSelectMode.value;
    selectedObjects.clear();
  }

  // 长按进入多选模式并选中该文件（长按菜单已改为二级操作栏）
  void enterSelectMode(ObjectModel object) {
    if (!isSelectMode.value) {
      isSelectMode.value = true;
    }
    if (!selectedObjects.contains(object)) {
      selectedObjects.add(object);
    }
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

  // 批量移动 / 复制（跳转目录选择页，选目录后由该页执行）
  Future<void> batchMoveOrCopy({required bool isCopy}) async {
    final selected = List<ObjectModel>.from(selectedObjects);
    toggleSelectMode();
    Get.toNamed(Routes.DIRECTORY, arguments: {
      'srcDir': currentPath.value,
      'srcObjects': selected,
      'root': true,
      'isCopy': isCopy,
      'source': PageSource.HOMEPAGE,
      'tag': '',
      'fromRoute': Get.currentRoute,
    });
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
      // 全局搜索：轻量 PROPFIND + 同层目录并发递归，只收集匹配项
      final allFiles = await _searchRecursive('/', 0, query, (count) {
        searchedCount.value = count;
      }).timeout(const Duration(seconds: 45), onTimeout: () {
        _cancelSearch = true;
        return <ObjectModel>[];
      });
      if (_cancelSearch) return;
      objects.value = allFiles;
      if (allFiles.isEmpty) {
        SmartDialog.showToast('未找到匹配“$query”的文件');
      }
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

  // 搜索深度上限（防止深层目录栈溢出/超时）
  static const int _maxSearchDepth = 8;
  // 搜索结果数量上限（防止海量结果拖垮内存）
  static const int _maxSearchResults = 500;
  // 同层目录分批并发：每批最多 10 个 PROPFIND，防止海量并发闪退
  static const int _batchSize = 10;

  // 递归搜索所有子目录（轻量 PROPFIND，同层目录并发，只收集匹配项）
  Future<List<ObjectModel>> _searchRecursive(
    String path,
    int depth,
    String query,
    void Function(int count) onProgress,
  ) async {
    final results = <ObjectModel>[];

    // 已取消、超深、超量则停止
    if (_cancelSearch || depth > _maxSearchDepth) return results;

    List<ObjectModel>? files;
    try {
      // 直接走轻量 PROPFIND 列表接口（单请求/目录，不做 HEAD/重试/降级诊断）
      final response = await ObjectRepository.getList(path: path);
      files = response != null && response['code'] == 200
          ? (response['data']['content'] as List)
              .map((json) => ObjectModel.fromJson(json))
              .toList()
          : null;
    } catch (_) {
      // 跳过无法访问的目录
    }
    if (files == null) return results;
    onProgress(depth);

    // 先收集当前层匹配项
    for (final file in files) {
      if (_cancelSearch || results.length >= _maxSearchResults) break;
      if (file.name?.toLowerCase().contains(query.toLowerCase()) ?? false) {
        results.add(file);
      }
    }

    // 同层子目录分批并发递归（每批 10 个，大幅提速同时防止海量并发闪退）
    final subDirs = files.where((f) => f.isDir == true).toList();
    if (subDirs.isNotEmpty && results.length < _maxSearchResults) {
      for (var i = 0; i < subDirs.length; i += _batchSize) {
        if (_cancelSearch || results.length >= _maxSearchResults) break;
        final batch = subDirs.skip(i).take(_batchSize).toList();
        final futures = batch.map((dir) async {
          if (_cancelSearch) return <ObjectModel>[];
          final subPath =
              path == '/' ? '/${dir.name}' : '$path/${dir.name}';
          return _searchRecursive(subPath, depth + 1, query, onProgress);
        });
        final subResults = await Future.wait(futures);
        for (final sub in subResults) {
          if (_cancelSearch || results.length >= _maxSearchResults) break;
          results.addAll(sub);
        }
      }
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

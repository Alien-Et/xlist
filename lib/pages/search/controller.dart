import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:xlist/models/index.dart';
import 'package:xlist/services/core_service.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/repositorys/index.dart';
class SearchController extends GetxController {
  static const pageSize = 100;
  final userInfo = UserModel().obs; // 用户信息
  final searchList = <FsSearchModel>[].obs; // 搜索结果

  // 显示预览图
  late final isShowPreview = false.obs;

  // 搜索状态
  final isSearching = false.obs;
  bool _cancelSearch = false;
  Timer? _debounce;

  TextEditingController searchController = TextEditingController();
  ScrollController scrollController = ScrollController();

  // 获取参数
  final String path = Get.arguments['path'] ?? '/';
  String password = ''; // 目录密码

  late CoreService coreService;

  // 搜索深度上限（防止深层目录栈溢出/超时）
  static const int _maxSearchDepth = 10;
  // 搜索结果数量上限（防止海量结果拖垮内存）
  static const int _maxSearchResults = 500;
  // 同层目录分批并发：每批最多 10 个 PROPFIND，防止根目录数百子目录
  // 同时发起请求 → 内存/连接爆 → 闪退
  static const int _batchSize = 10;
  // 全盘网络递归请求总数上限（索引为空时防止无节制递归拉崩 App）
  static const int _maxRequests = 250;
  // 请求计数（每次递归 getList +1，超限即取消整个搜索）
  int _requestCount = 0;

  @override
  void onInit() async {
    super.onInit();
    coreService = CoreService.to;

    // 显示预览图设置
    isShowPreview.value = coreService.preferencesStorage.isShowPreview.val;

    // 获取目录密码
    final serverId = coreService.userStorage.serverId.value;
    final passwordManager = await coreService.passwordManagerDao
        .findPasswordManagerByPath(serverId, path);
    if (passwordManager != null && passwordManager.isNotEmpty) {
      password = passwordManager.last.password;
    }

    // 获取用户信息
    userInfo.value = coreService.currentUser.value ?? UserModel();
  }

  /// 搜索输入（防抖 400ms，避免每次击键触发请求）
  void onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      getSearchObjectList(value);
    });
  }

  /// 获取搜索数据
  Future<void> getSearchObjectList(String keywords) async {
    final query = keywords.trim();
    if (query.isEmpty) {
      searchList.clear();
      searchList.refresh();
      return;
    }

    _cancelSearch = false;
    _requestCount = 0;
    isSearching.value = true;
    try {
      // 先查本地索引（毫秒级，浏览时自动写入；避免网络递归崩溃并加快搜索）
      final serverId = Get.find<UserStorage>().serverId.value;
      final indexed = await FileIndexService.search(
        serverId: serverId,
        keyword: query,
      );
      if (indexed.isNotEmpty) {
        if (_cancelSearch) return;
        searchList.assignAll(indexed.map((e) => FsSearchModel(
              name: e.name,
              parent: e.parentPath,
              isDir: e.type == 1,
              type: e.type,
              size: e.size,
            )));
        searchList.refresh();
        isSearching.value = false;
        return;
      }

      // 索引无结果：轻量 PROPFIND + 同层目录并发递归，只收集匹配项
      final results = await _searchRecursive(path, 0, query)
          .timeout(const Duration(seconds: 45), onTimeout: () {
        _cancelSearch = true;
        return <FsSearchModel>[];
      });
      if (_cancelSearch) return;
      searchList.clear();
      searchList.addAll(results);
      searchList.refresh();
    } catch (e) {
      searchList.clear();
      searchList.refresh();
    } finally {
      isSearching.value = false;
    }
  }

  // 递归搜索所有子目录（轻量 PROPFIND，同层目录并发，只收集匹配项）
  Future<List<FsSearchModel>> _searchRecursive(
    String dirPath,
    int depth,
    String query,
  ) async {
    final results = <FsSearchModel>[];

    // 已取消、超深、超量则停止
    if (_cancelSearch || depth > _maxSearchDepth) return results;
    // 请求总数超限：直接取消整个搜索（防递归风暴闪退）
    if (++_requestCount > _maxRequests) {
      _cancelSearch = true;
      return results;
    }

    List<ObjectModel>? files;
    try {
      // 直接走轻量 PROPFIND 列表接口（单请求/目录，不做 HEAD/重试/降级诊断）
      final response = await ObjectRepository.getList(path: dirPath);
      files = response != null && response['code'] == 200
          ? (response['data']['content'] as List)
              .map((json) => ObjectModel.fromJson(json))
              .toList()
          : null;
    } catch (_) {
      // 跳过无法访问的目录
    }
    if (files == null) return results;

    // 先收集当前层匹配项
    for (final file in files) {
      if (_cancelSearch || results.length >= _maxSearchResults) break;
      if (file.name?.toLowerCase().contains(query.toLowerCase()) ?? false) {
        results.add(FsSearchModel(
          name: file.name,
          parent: dirPath,
          isDir: file.isDir ?? false,
          type: file.type ?? 0,
          size: file.size,
          thumb: file.thumb,
        ));
      }
    }

    // 同层子目录分批并发递归（每批 10 个，大幅提速同时防止海量并发闪退）
    final subDirs = files.where((f) => f.isDir == true).toList();
    if (subDirs.isNotEmpty && results.length < _maxSearchResults) {
      for (var i = 0; i < subDirs.length; i += _batchSize) {
        if (_cancelSearch || results.length >= _maxSearchResults) break;
        final batch =
            subDirs.skip(i).take(_batchSize).toList();
        final futures = batch.map((dir) async {
          if (_cancelSearch) return <FsSearchModel>[];
          final subPath =
              dirPath == '/' ? '/${dir.name}' : '$dirPath/${dir.name}';
          return _searchRecursive(subPath, depth + 1, query);
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

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}

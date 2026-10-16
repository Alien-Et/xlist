import 'package:get/get.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/pages/setting/index.dart';
import 'package:xlist/pages/homepage/index.dart';
import 'package:xlist/database/entity/index.dart';
import 'package:xlist/services/database_service.dart';
import 'package:xlist/services/core_service.dart';

class ServerController extends GetxController {
  final serverList = <ServerEntity>[].obs;
  final isFirstLoading = true.obs; // 是否是第一次加载
  final serverId = Rxn<int>();
  final errorMessage = "".obs;
  
  // 延迟初始化依赖项
  HomepageController? _homepageController;
  SettingController? _settingController;
  UserStorage? _userStorage;

  @override
  void onInit() async {
    super.onInit();
    print('=== Initializing ServerController ===');

    // 初始化依赖项
    _initDependencies();

    try {
      // 获取服务器信息
      await getServerList();
    } catch (e) {
      print('✗ Error in ServerController onInit: $e');
      errorMessage.value = 'Failed to initialize server controller';
    } finally {
      // 加载完成
      isFirstLoading.value = false;
      print('=== ServerController initialization completed ===');
    }
  }

  // 初始化依赖项
  void _initDependencies() {
    try {
      _userStorage = Get.find<UserStorage>();
      serverId.value = _userStorage?.serverId.value ?? 0;
      print('✓ UserStorage initialized');
    } catch (e) {
      print('⚠ Error getting UserStorage: $e');
      _userStorage = null;
      serverId.value = 0;
    }

    try {
      _homepageController = Get.find<HomepageController>();
      print('✓ HomepageController initialized');
    } catch (e) {
      print('⚠ Error getting HomepageController: $e');
      _homepageController = null;
    }

    try {
      _settingController = Get.find<SettingController>();
      print('✓ SettingController initialized');
    } catch (e) {
      print('⚠ Error getting SettingController: $e');
      _settingController = null;
    }
  }

  /// 获取服务器列表
  Future<void> getServerList() async {
    isFirstLoading.value = true;
    errorMessage.value = '';

    try {
      print('Getting server list...');
      
      if (DatabaseService.to.isDatabaseInitialized) {
        try {
          final servers = await DatabaseService.to.database.serverDao.findAllServer();
          serverList.value = servers;
          print('✓ Got ${servers.length} servers from database');
        } catch (e) {
          print('⚠ Error getting servers from database: $e');
          serverList.value = [];
        }
      } else {
        print('⚠ Database not initialized, returning empty server list');
        serverList.value = [];
      }
    } catch (e) {
      print('✗ Error getting server list: $e');
      serverList.value = [];
      errorMessage.value = 'Failed to get server list';
    } finally {
      isFirstLoading.value = false;
    }
  }

  /// 切换服务器
  Future<void> switchServer(ServerEntity server) async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_switch_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    // 检查必要的依赖项
    if (_userStorage == null) {
      SmartDialog.showToast('User storage not initialized');
      return;
    }

    // 本地用户信息
    final userStorage = _userStorage!;

    // 获取当前服务器信息
    final token = userStorage.token.value;
    final currentServerId = userStorage.serverId.value;
    final currentServerUrl = userStorage.serverUrl.value;

    try {
      SmartDialog.showLoading();
      print('Switching to server: ${server.url}');

      // 更新本地用户信息
      userStorage.token.value = '';
      userStorage.serverId.value = server.id!;
      userStorage.serverUrl.value = server.url;
      userStorage.username.value = server.username ?? '';
      userStorage.password.value = server.password ?? '';
      serverId.value = server.id!;

      // 持久化当前服务器（重启后自动恢复，而非默认第一个）
      try {
        final pref = Get.find<PreferencesStorage>();
        pref.id.val = server.id?.toString() ?? '';
        pref.token.val = '';
        pref.serverId.val = server.id ?? 0;
        pref.serverUrl.val = server.url;
        pref.username.val = server.username ?? '';
        pref.password.val = server.password ?? '';
      } catch (e) {
        print('⚠ Error persisting server: $e');
      }

      // 更新 CoreService 的当前服务器
      try {
        final coreService = Get.find<CoreService>();
        coreService.currentServer.value = server;
        // 刷新用户数据
        await coreService.loadUserData();
        print('✓ Updated CoreService current server: ${server.url}');
      } catch (e) {
        print('⚠ Error updating CoreService: $e');
      }

      // 重置首页信息
      if (_homepageController != null) {
        _homepageController!.serverId.value = server.id!;

        // 用户信息
        try {
          final userInfo = await _homepageController!.resetUserToken(server, force: true);
          // 检查返回的用户信息是否有效
          if (userInfo == null || (userInfo is Map && userInfo['id'] == null)) {
            // 即使获取用户信息失败，也继续执行，因为服务器可能是匿名的
            print('Warning: Failed to get user info, continuing with server switch');
          }

          // 刷新首页数据
          await _homepageController!.getObjectList();
        } catch (e) {
          print('⚠ Error updating homepage controller: $e');
        }
      }

      // 重置设置页面信息
      if (_settingController != null) {
        _settingController!.serverId.value = server.id!;
        _settingController!.serverInfo.value = server;
      }

      // 导航回首页
      Get.until((route) => Get.currentRoute == Routes.HOMEPAGE);

      SmartDialog.dismiss();
      SmartDialog.showToast('toast_switch_success'.tr);
      print('✓ Server switched successfully');
    } catch (e) {
      print('✗ Error switching server: $e');
      // 恢复之前的服务器信息
      userStorage.token.value = token;
      userStorage.serverId.value = currentServerId;
      userStorage.serverUrl.value = currentServerUrl;
      serverId.value = currentServerId;

      // 同步写回持久化（避免与内存不一致）
      try {
        final pref = Get.find<PreferencesStorage>();
        pref.serverId.val = currentServerId;
        pref.serverUrl.val = currentServerUrl;
      } catch (_) {}
      
      // 恢复 CoreService 的当前服务器
      try {
        final coreService = Get.find<CoreService>();
        // 尝试找到之前的服务器
        if (currentServerId > 0) {
          final servers = await DatabaseService.to.database.serverDao.findAllServer();
          final previousServer = servers.firstWhereOrNull((s) => s.id == currentServerId);
          if (previousServer != null) {
            coreService.currentServer.value = previousServer;
            await coreService.loadUserData();
            print('✓ Restored CoreService current server: ${previousServer.url}');
          }
        }
      } catch (e) {
        print('⚠ Error restoring CoreService: $e');
      }
      
      if (_homepageController != null) {
        _homepageController!.serverId.value = currentServerId;
      }
      
      SmartDialog.dismiss();
      SmartDialog.showToast('Failed to switch server: ${e.toString()}');
    }
  }

  /// 删除服务器
  Future<void> deleteServer(int id) async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    try {
      print('Deleting server with id: $id');

      // 删除数据
      if (DatabaseService.to.isDatabaseInitialized) {
        try {
          await DatabaseService.to.database.serverDao.deleteServerById(id);
          print('✓ Server deleted from database');

          // 删除关联数据
          try {
            await DatabaseService.to.database.recentDao.deleteRecentByServerId(id);
            await DatabaseService.to.database.progressDao.deleteProgressByServerId(id);
            await DatabaseService.to.database.passwordManagerDao
                .deletePasswordManagerByServerId(id);
            print('✓ Associated data deleted');
          } catch (e) {
            print('⚠ Error deleting associated data: $e');
          }
        } catch (e) {
          print('⚠ Error deleting server from database: $e');
        }
      } else {
        print('⚠ Database not initialized, cannot delete server');
      }

      // 删除本地数据
      if (_userStorage != null && serverId.value == id) {
        _userStorage!.id.value = '';
        _userStorage!.token.value = '';
        _userStorage!.serverId.value = 0;
        _userStorage!.serverUrl.value = '';
        serverId.value = 0;
        print('✓ Local user data reset');
      }

      // 如果删除的是当前服务器
      if (_homepageController != null && _homepageController!.serverId.value == id) {
        _homepageController!.serverId.value = 0;
        _homepageController!.userInfo.value = UserModel();
        _homepageController!.objects.value.clear();
        print('✓ Homepage controller reset');
      }

      // 设置页面
      if (_settingController != null && _settingController!.serverId.value == id) {
        _settingController!.serverId.value = 0;
        _settingController!.serverInfo.value =
            ServerEntity(url: '', type: 0, username: '', password: '');
        print('✓ Setting controller reset');
      }

      // 刷新服务器列表
      await getServerList();
      print('✓ Server list refreshed');
    } catch (e) {
      print('✗ Error deleting server: $e');
      SmartDialog.showToast('Failed to delete server: ${e.toString()}');
    }
  }

  /// 添加服务器
  Future<void> addServer(ServerEntity server) async {
    try {
      print('Adding new server: ${server.url}');
      
      // 刷新服务器列表
      await getServerList();
      
      // 无论serverList是否为空，都更新全局状态
      if (_userStorage != null) {
        // 更新本地存储
        _userStorage!.serverId.value = server.id!;
        _userStorage!.serverUrl.value = server.url;
        serverId.value = server.id!;
        print('✓ Updated local storage with new server');

        // 更新 CoreService 的当前服务器
        try {
          final coreService = Get.find<CoreService>();
          coreService.currentServer.value = server;
          await coreService.loadUserData();
          print('✓ Updated CoreService current server: ${server.url}');
        } catch (e) {
          print('⚠ Error updating CoreService: $e');
        }

        // 重置首页信息
        if (_homepageController != null) {
          _homepageController!.serverId.value = server.id!;
          try {
            await _homepageController!.resetUserToken(server);
            await _homepageController!.getObjectList();
          } catch (e) {
            print('⚠ Error updating homepage controller: $e');
          }
        }

        // 重置设置页面信息
        if (_settingController != null) {
          _settingController!.serverId.value = server.id!;
          _settingController!.serverInfo.value = server;
        }
      }
      
      // 导航回首页
      Get.until((route) => Get.currentRoute == Routes.HOMEPAGE);
      
      SmartDialog.showToast('Server added successfully');
      print('✓ Server added successfully');
    } catch (e) {
      print('✗ Error adding server: $e');
      SmartDialog.showToast('Failed to add server: ${e.toString()}');
    }
  }

  // 检查是否有活动服务器
  bool get hasActiveServer => serverId.value != null && serverId.value! > 0;

  // 获取当前活动服务器
  ServerEntity? get activeServer {
    if (!hasActiveServer) return null;
    return serverList.firstWhereOrNull((server) => server.id == serverId.value);
  }
}

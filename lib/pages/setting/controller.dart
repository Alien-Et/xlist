import 'package:get/get.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:xlist/constants/index.dart';
import 'package:xlist/database/entity/index.dart';
import 'package:xlist/services/core_service.dart';

class SettingController extends GetxController {
  final version = ''.obs; // 版本号
  final serverId = 0.obs;
  final serverInfo =
      ServerEntity(url: '', type: 0, username: '', password: '').obs;

  // 自动播放
  late final isAutoPlay = false.obs;

  // 后台播放
  late final isBackgroundPlay = false.obs;

  // 硬件解码
  late final isHardwareDecode = false.obs;

  // 显示预览图
  late final isShowPreview = false.obs;

  // 忽略 SSL 证书校验（自签/内网证书服务器）
  late final ignoreSslVerify = false.obs;

  // 主题
  final themeModeText = ''.obs;
  
  late CoreService coreService;

  @override
  void onInit() async {
    super.onInit();
    coreService = CoreService.to;

    // 获取当前版本号
    final packageInfo = await PackageInfo.fromPlatform();
    version.value = packageInfo.version;

    // 获取服务器信息
    serverId.value = coreService.userStorage.serverId.value;
    serverInfo.value = (await coreService.serverDao
            .findServerById(serverId.value)) ??
        ServerEntity(url: '', type: 0, username: '无', password: '');

    // 获取设置
    isAutoPlay.value = coreService.preferencesStorage.isAutoPlay.val ?? false;
    isBackgroundPlay.value = coreService.preferencesStorage.isBackgroundPlay.val ?? false;
    isHardwareDecode.value = coreService.preferencesStorage.isHardwareDecode.val ?? false;
    isShowPreview.value = coreService.preferencesStorage.isShowPreview.val ?? true;
    ignoreSslVerify.value = coreService.preferencesStorage.ignoreSslVerify.val ?? true;

    // 获取当前主题模式
    themeModeText.value =
        ThemeModeTextMap[coreService.commonStorage.themeMode.val]!;
  }

  /// 更换主题
  void changeTheme() async {
    final value = await showModalActionSheet(
      context: Get.overlayContext!,
      actions: [
        SheetAction(label: '跟随系统', key: 'system'),
        SheetAction(label: '明亮', key: 'light'),
        SheetAction(label: '深邃', key: 'dark'),
      ],
      cancelLabel: '取消',
    );

    if (value != null) {
      Get.changeThemeMode(ThemeModeMap[value]!);
      themeModeText.value = ThemeModeTextMap[value]!;
      coreService.commonStorage.themeMode.val = value;
      Future.delayed(Duration(milliseconds: 200), () {
        Get.forceAppUpdate();
      });
    }
  }

  /// 更新设置
  void updateSetting(String key, bool value) async {
    switch (key) {
      case 'isAutoPlay':
        isAutoPlay.value = value;
        coreService.preferencesStorage.isAutoPlay.val = value;
        break;
      case 'isBackgroundPlay':
        isBackgroundPlay.value = value;
        coreService.preferencesStorage.isBackgroundPlay.val = value;
        break;
      case 'isHardwareDecode':
        isHardwareDecode.value = value;
        coreService.preferencesStorage.isHardwareDecode.val = value;
        break;
      case 'isShowPreview':
        isShowPreview.value = value;
        coreService.preferencesStorage.isShowPreview.val = value;
        break;
      case 'ignoreSslVerify':
        ignoreSslVerify.value = value;
        coreService.preferencesStorage.ignoreSslVerify.val = value;
        break;
    }
  }
}

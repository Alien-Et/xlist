import 'dart:ui';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'package:xlist/global.dart';
import 'package:xlist/themes.dart';
import 'package:xlist/constants/common.dart';
import 'package:xlist/components/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/langs/translation_service.dart';
import 'package:xlist/storages/common_storage.dart';

/// flutter_downloader 后台 isolate 回调入口（必须为顶层函数）
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final sendPort = IsolateNameServer.lookupPortByName('downloader_port');
  sendPort?.send([id, status, progress]);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化下载引擎（未初始化时 enqueue 会抛 MissingPluginException）
  await FlutterDownloader.initialize(debug: false);
  FlutterDownloader.registerCallback(downloadCallback);
  Global.init().then((e) => runApp(Phoenix(child: XlistApp())));
}

class XlistApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(1080, 1920),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => GetMaterialApp(
        title: 'CloudX',
        theme: Themes.light,
        darkTheme: Themes.dark,
        // 从全局存储恢复主题（设置页切换后重启仍生效）
        themeMode: ThemeModeMap[CommonStorage().themeMode.val] ??
            ThemeMode.system,
        initialRoute: AppPages.INITIAL,
        defaultTransition: Transition.cupertino,
        debugShowCheckedModeBanner: false,
        getPages: AppPages.routes,
        unknownRoute: AppPages.unknownRoute,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: FlutterSmartDialog.init(
              toastBuilder: (String msg) => ToastComponent(message: msg),
            )(context, child),
          );
        },
        translations: TranslationService(),
        locale: TranslationService.locale,
        fallbackLocale: TranslationService.fallbackLocale,
      ),
    );
  }
}

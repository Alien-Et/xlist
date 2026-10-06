import 'dart:io';
import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import 'package:xlist/common/logger.dart';
import 'package:xlist/services/dio_service.dart';
import 'package:xlist/services/database_service.dart';
import 'package:xlist/services/core_service.dart';
import 'package:xlist/storages/common_storage.dart';
import 'package:xlist/storages/preferences_storage.dart';
import 'package:xlist/storages/user_storage.dart';

// 全局配置
class Global {
  static bool get isRelease => kReleaseMode;
  static bool get isProfile => kProfileMode;
  static bool get isDebug => kDebugMode;

  // 服务初始化状态
  static final Map<String, bool> _serviceStatus = {};

  // 检查服务是否初始化
  static bool isServiceInitialized(String serviceName) {
    return _serviceStatus[serviceName] ?? false;
  }

  // 运行初始化
  static Future<void> init() async {
    print('=== Starting Global initialization ===');
    
    try {
      // 1. 初始化 FlutterBinding
      WidgetsFlutterBinding.ensureInitialized();
      print('✓ Flutter binding initialized');

      // 2. 初始化 GetStorage
      try {
        await GetStorage.init();
        _serviceStatus['GetStorage'] = true;
        print('✓ GetStorage initialized');
      } catch (e) {
        print('⚠ Error initializing GetStorage: $e');
        _serviceStatus['GetStorage'] = false;
      }

      // 3. 初始化存储服务（按依赖顺序）
      await _initStorageServices();

      // 4. 初始化核心服务（按依赖顺序）
      await _initCoreServices();

      // 5. 配置平台特定设置
      _configurePlatformSettings();

      // 6. 配置日志开发模式
      _configureLogging();

      // 7. 打印初始化状态
      _printInitializationStatus();

      print('=== Global initialization completed ===');
    } catch (e) {
      print('✗ Critical error in Global.init: $e');
      // 即使初始化失败，也允许应用继续运行
    }
  }

  // 初始化存储服务
  static Future<void> _initStorageServices() async {
    print('\n--- Initializing storage services ---');

    // 初始化 CommonStorage
    try {
      await Get.putAsync(() async {
        final storage = CommonStorage();
        _serviceStatus['CommonStorage'] = true;
        print('✓ CommonStorage initialized');
        return storage;
      });
    } catch (e) {
      print('⚠ Error initializing CommonStorage: $e');
      _serviceStatus['CommonStorage'] = false;
    }

    // 初始化 PreferencesStorage
    try {
      await Get.putAsync(() async {
        final storage = await PreferencesStorage().init();
        _serviceStatus['PreferencesStorage'] = true;
        print('✓ PreferencesStorage initialized');
        return storage;
      });
    } catch (e) {
      print('⚠ Error initializing PreferencesStorage: $e');
      _serviceStatus['PreferencesStorage'] = false;
    }

    // 初始化 UserStorage
    try {
      await Get.putAsync(() async {
        final storage = UserStorage();
        _serviceStatus['UserStorage'] = true;
        print('✓ UserStorage initialized');
        return storage;
      });
    } catch (e) {
      print('⚠ Error initializing UserStorage: $e');
      _serviceStatus['UserStorage'] = false;
    }
  }

  // 初始化核心服务
  static Future<void> _initCoreServices() async {
    print('\n--- Initializing core services ---');

    // 初始化 DioService
    try {
      await Get.putAsync(() async {
        final service = await DioService().init();
        _serviceStatus['DioService'] = true;
        print('✓ DioService initialized');
        return service;
      });
    } catch (e) {
      print('⚠ Error initializing DioService: $e');
      _serviceStatus['DioService'] = false;
    }

    // 初始化 DatabaseService
    try {
      await Get.putAsync(() async {
        final service = await DatabaseService().init();
        _serviceStatus['DatabaseService'] = true;
        print('✓ DatabaseService initialized');
        return service;
      });
    } catch (e) {
      print('⚠ Error initializing DatabaseService: $e');
      _serviceStatus['DatabaseService'] = false;
    }

    // 初始化 CoreService
    try {
      await Get.putAsync(() async {
        final service = await CoreService().init();
        _serviceStatus['CoreService'] = true;
        print('✓ CoreService initialized');
        return service;
      });
    } catch (e) {
      print('⚠ Error initializing CoreService: $e');
      _serviceStatus['CoreService'] = false;
    }
  }

  // 配置平台特定设置
  static void _configurePlatformSettings() {
    print('\n--- Configuring platform settings ---');

    // Android 状态栏配置
    if (GetPlatform.isAndroid) {
      try {
        SystemUiOverlayStyle systemUiOverlayStyle =
            const SystemUiOverlayStyle(statusBarColor: Colors.transparent);
        SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
        print('✓ Android status bar configured');
      } catch (e) {
        print('⚠ Error configuring Android status bar: $e');
      }
    }

    // iOS 状态栏配置
    if (GetPlatform.isIOS) {
      try {
        // 设置 iOS 状态栏样式
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.light,
          ),
        );
        print('✓ iOS status bar configured');
      } catch (e) {
        print('⚠ Error configuring iOS status bar: $e');
      }
    }
  }

  // 配置日志开发模式
  static void _configureLogging() {
    print('\n--- Configuring logging ---');
    
    try {
      // 仅开发模式启用调试日志和文件日志，Release 模式保持关闭，避免敏感信息落盘
      if (kDebugMode) {
        Logger.setDebugEnabled(true);
        Logger.setFileLoggingEnabled(true);
      }
      
      print('✓ Logging development mode enabled');
      print('✓ Debug logs will be shown');
      print('✓ File logging enabled');
      print('✓ Log file path: ${Logger.getLogFilePath() ?? 'Not initialized'}');
      
      // 测试日志输出
      StepLogger.start('日志系统测试');
      StepLogger.step('输出调试日志');
      Logger.d('Testing debug log output');
      StepLogger.step('输出信息日志');
      Logger.i('Testing info log output');
      StepLogger.step('输出警告日志');
      Logger.w('Testing warning log output');
      StepLogger.step('输出错误日志');
      Logger.e('Testing error log output');
      StepLogger.step('输出详细日志');
      Logger.v('Testing verbose log output');
      StepLogger.end('日志系统测试', success: true);
      
      print('✓ Logging system initialized successfully');
    } catch (e) {
      print('⚠ Error configuring logging: $e');
    }
  }

  // 打印初始化状态
  static void _printInitializationStatus() {
    print('\n--- Initialization Status ---');
    
    final allServices = [
      'FlutterBinding',
      'GetStorage',
      'CommonStorage',
      'PreferencesStorage',
      'UserStorage',
      'DioService',
      'DatabaseService',
      'CoreService',
    ];

    int successCount = 0;
    int failureCount = 0;

    for (final service in allServices) {
      final status = _serviceStatus[service] ?? (service == 'FlutterBinding' ? true : false);
      print('${status ? '✓' : '✗'} $service: ${status ? 'Initialized' : 'Failed'}');
      if (status) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    print('\nSummary: $successCount services initialized, $failureCount services failed');
    
    if (failureCount > 0) {
      print('⚠ Some services failed to initialize, but app will continue running');
    } else {
      print('✓ All services initialized successfully');
    }
  }
}

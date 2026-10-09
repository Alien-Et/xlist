import 'dart:convert';
import 'dart:async';
import 'package:get/get.dart' hide Response;
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import 'package:xlist/common/logger.dart';
import 'package:xlist/services/dio_service.dart';
import 'package:xlist/services/database_service.dart';
import 'package:xlist/storages/common_storage.dart';
import 'package:xlist/storages/preferences_storage.dart';
import 'package:xlist/storages/user_storage.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/database/dao/index.dart';
import 'package:xlist/database/entity/index.dart';

// WebDAV 错误类型
enum WebDAVErrorType {
  NETWORK_ERROR,      // 网络错误
  AUTH_ERROR,         // 认证错误
  SERVER_ERROR,       // 服务器错误
  PARSE_ERROR,        // 解析错误
  UNKNOWN_ERROR,      // 未知错误
}

// WebDAV 错误类
class WebDAVError {
  final WebDAVErrorType type;
  final String message;
  final dynamic originalError;

  WebDAVError(this.type, this.message, {this.originalError});

  @override
  String toString() {
    return 'WebDAVError{type: $type, message: $message}';
  }
}

class CoreService extends GetxService {
  static CoreService get to => Get.find();

  // 服务
  late DioService dioService;
  late DatabaseService databaseService;
  
  // 为了兼容其他控制器，添加必要的属性
  late dynamic downloadService;

  // 存储
  late CommonStorage commonStorage;
  late PreferencesStorage preferencesStorage;
  late UserStorage userStorage;

  // DAO
  late DownloadDao downloadDao;
  late FavoriteDao favoriteDao;
  late RecentDao recentDao;
  late ServerDao serverDao;
  
  // 为了兼容其他控制器，添加必要的DAO
  late dynamic passwordManagerDao;
  late dynamic progressDao;

  // 状态
  final currentUser = Rxn<UserModel>();
  final currentServer = Rxn<ServerEntity>();
  final currentPath = "".obs;
  final currentObjects = <ObjectModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = "".obs;

  // 服务初始化状态
  final Map<String, bool> _serviceStatus = {};

  Future<CoreService> init() async {
    Logger.d('Initializing CoreService');
    
    // 初始化服务
    await _initServices();

    // 初始化存储
    await _initStorages();

    // 初始化 DAO
    await _initDAOs();

    // 初始化其他服务
    await _initOtherServices();

    // 加载用户数据
    await loadUserData();
    // 加载最近服务器
    await loadRecentServer();

    // 打印初始化状态
    _printInitializationStatus();

    Logger.d('CoreService initialized');
    return this;
  }

  // 初始化服务
  Future<void> _initServices() async {
    Logger.d('Initializing services');

    // 初始化 DioService
    try {
      dioService = Get.find<DioService>();
      _serviceStatus['DioService'] = true;
      Logger.d('DioService initialized');
    } catch (e) {
      Logger.w('Error finding DioService: $e');
      _serviceStatus['DioService'] = false;
    }

    // 初始化 DatabaseService
    try {
      databaseService = Get.find<DatabaseService>();
      _serviceStatus['DatabaseService'] = true;
      Logger.d('DatabaseService initialized');
    } catch (e) {
      Logger.w('Error finding DatabaseService: $e');
      _serviceStatus['DatabaseService'] = false;
    }
  }

  // 初始化存储
  Future<void> _initStorages() async {
    Logger.d('Initializing storages');

    // 初始化 CommonStorage
    try {
      commonStorage = Get.find<CommonStorage>();
      _serviceStatus['CommonStorage'] = true;
      Logger.d('CommonStorage initialized');
    } catch (e) {
      Logger.w('Error finding CommonStorage: $e');
      _serviceStatus['CommonStorage'] = false;
    }

    // 初始化 PreferencesStorage
    try {
      preferencesStorage = Get.find<PreferencesStorage>();
      _serviceStatus['PreferencesStorage'] = true;
      Logger.d('PreferencesStorage initialized');
    } catch (e) {
      Logger.w('Error finding PreferencesStorage: $e');
      _serviceStatus['PreferencesStorage'] = false;
    }

    // 初始化 UserStorage
    try {
      userStorage = Get.find<UserStorage>();
      _serviceStatus['UserStorage'] = true;
      Logger.d('UserStorage initialized');
    } catch (e) {
      Logger.w('Error finding UserStorage: $e');
      _serviceStatus['UserStorage'] = false;
    }
  }

  // 初始化 DAO
  Future<void> _initDAOs() async {
    Logger.d('Initializing DAOs');

    try {
      // 尝试获取数据库实例
      if (databaseService.isDatabaseInitialized) {
        final db = databaseService.database;
        downloadDao = db.downloadDao;
        favoriteDao = db.favoriteDao;
        recentDao = db.recentDao;
        serverDao = db.serverDao;
        
        // 尝试初始化其他DAO
        try {
          passwordManagerDao = db.passwordManagerDao;
          progressDao = db.progressDao;
        } catch (e) {
          Logger.w('Error initializing optional DAOs: $e');
          // 如果初始化失败，设置为null
          passwordManagerDao = null;
          progressDao = null;
        }
        
        _serviceStatus['DAOs'] = true;
        Logger.d('DAOs initialized');
      } else {
        Logger.w('Database not initialized, skipping DAO initialization');
        _serviceStatus['DAOs'] = false;
      }
    } catch (e) {
      Logger.w('Error initializing DAOs: $e');
      _serviceStatus['DAOs'] = false;
      // 如果初始化失败，设置为null
      passwordManagerDao = null;
      progressDao = null;
    }
  }

  // 初始化其他服务
  Future<void> _initOtherServices() async {
    Logger.d('Initializing other services');

    // 初始化downloadService
    try {
      // 尝试获取downloadService
      // 暂时设置为null，因为我们没有初始化它
      downloadService = null;
      _serviceStatus['DownloadService'] = true;
      Logger.d('DownloadService initialized (placeholder)');
    } catch (e) {
      Logger.w('Error initializing downloadService: $e');
      downloadService = null;
      _serviceStatus['DownloadService'] = false;
    }
  }

  // 打印初始化状态
  void _printInitializationStatus() {
    Logger.d('CoreService Initialization Status');
    _serviceStatus.forEach((key, value) {
      Logger.d('${value ? '✓' : '✗'} $key: ${value ? 'Initialized' : 'Failed'}');
    });
  }

  Future<void> loadUserData() async {
    try {
      // 加载用户数据
      if (userStorage != null) {
        final userId = userStorage.id.value;
        final token = userStorage.token.value;
        if (userId.isNotEmpty || token.isNotEmpty) {
          // 创建用户模型
          currentUser.value = UserModel();
          Logger.d('User data loaded from storage');
        } else {
          // 即使没有用户信息，也创建一个空的UserModel
          currentUser.value = UserModel();
          Logger.d('Created empty UserModel');
        }
      } else {
        // 如果userStorage不可用，创建空的UserModel
        currentUser.value = UserModel();
        Logger.w('UserStorage not available, created empty UserModel');
      }
      Logger.d('User data loaded successfully');
    } catch (e) {
      Logger.w('Error loading user data: $e');
      // 出错时也确保有一个UserModel
      currentUser.value = UserModel();
    }
  }

  Future<void> loadRecentServer() async {
    try {
      Logger.d('=== Starting loadRecentServer() ===');
      
      // 首先检查userStorage是否可用
      if (userStorage == null) {
        Logger.w('UserStorage is null');
        return;
      }
      
      // 打印UserStorage中的服务器信息
      Logger.d('UserStorage serverId: ${userStorage.serverId.value}');
      Logger.d('UserStorage serverUrl: ${userStorage.serverUrl.value}');
      Logger.d('UserStorage username: ${userStorage.username.value}');
      Logger.d('UserStorage password length: ${userStorage.password.value}');
      
      // 1. 直接尝试获取服务器列表，不依赖于_serviceStatus标志
      try {
        if (serverDao != null) {
          final servers = await serverDao.findAllServer();
          Logger.d('Found ${servers.length} servers in database via serverDao');
          
          if (servers.isNotEmpty) {
            // 打印服务器详细信息
            for (final server in servers) {
              Logger.d('Server: ${server.url}, Username: ${server.username}, Password length: ${server.password.length}');
            }
            await _processServerList(servers);
            Logger.d('✓ Server loaded successfully via serverDao');
            return;
          } else {
            Logger.w('No servers found in database');
          }
        } else {
          Logger.w('ServerDao is null');
        }
      } catch (e) {
        Logger.w('Error loading servers via serverDao: $e');
      }
      
      // 2. 如果直接调用serverDao失败，尝试通过DatabaseService获取
      try {
        if (databaseService != null) {
          // 即使databaseService标记为未初始化，也尝试获取服务器列表
          // 因为DatabaseService可能已经创建了数据库连接
          try {
            final servers = await databaseService.database.serverDao.findAllServer();
            Logger.d('Found ${servers.length} servers through DatabaseService');
            if (servers.isNotEmpty) {
              // 打印服务器详细信息
              for (final server in servers) {
                Logger.d('Server: ${server.url}, Username: ${server.username}, Password length: ${server.password.length}');
              }
              await _processServerList(servers);
              Logger.d('✓ Server loaded successfully via DatabaseService');
              return;
            } else {
              Logger.w('No servers found through DatabaseService');
            }
          } catch (dbError) {
            Logger.w('Error accessing DatabaseService database: $dbError');
          }
        } else {
          Logger.w('DatabaseService not available');
        }
      } catch (e2) {
        Logger.w('Error loading server through DatabaseService: $e2');
      }
      
      // 3. 尝试从UserStorage中获取服务器ID，即使数据库不可用
      try {
        final savedServerId = userStorage.serverId.value;
        final savedServerUrl = userStorage.serverUrl.value;
        final savedUsername = userStorage.username.value;
        final savedPassword = userStorage.password.value;
        Logger.d('Saved server ID in UserStorage: $savedServerId');
        Logger.d('Saved server URL in UserStorage: $savedServerUrl');
        Logger.d('Saved username in UserStorage: $savedUsername');
        Logger.d('Saved password length in UserStorage: ${savedPassword.length}');
        if (savedServerId > 0 && savedServerUrl.isNotEmpty) {
          Logger.d('Found saved server information, but no database to load from');
          // 尝试从UserStorage创建一个临时的ServerEntity
          if (savedServerUrl.isNotEmpty) {
            final tempServer = ServerEntity(
              id: savedServerId,
              url: savedServerUrl,
              type: 1, // WebDAV类型
              username: savedUsername,
              password: savedPassword,
            );
            currentServer.value = tempServer;
            Logger.d('✓ Created temporary server from UserStorage: ${tempServer.url}');
          }
        }
      } catch (e3) {
        Logger.w('Error accessing UserStorage: $e3');
      }
      
      Logger.w('No server configuration found');
    } catch (e) {
      Logger.e('Critical error in loadRecentServer: $e');
    } finally {
      Logger.d('=== Server loading completed. Current server: ${currentServer.value?.url ?? 'null'} ===');
    }
  }
  
  // 处理服务器列表
  Future<void> _processServerList(List<ServerEntity> servers) async {
    if (servers.isEmpty) {
      Logger.w('Empty server list provided');
      return;
    }
    
    // 优先加载用户上次使用的服务器
    final currentServerId = userStorage.serverId.value;
    Logger.d('Current server ID from storage: $currentServerId');
    
    if (currentServerId > 0) {
      final userServer = servers.firstWhereOrNull((server) => server.id == currentServerId);
      if (userServer != null) {
        currentServer.value = userServer;
        Logger.d('✓ Loaded user\'s recent server: ${userServer.url}');
      } else {
        // 如果找不到用户上次使用的服务器，加载第一个服务器
        currentServer.value = servers.first;
        Logger.d('✓ Loaded first server (user\'s server not found): ${servers.first.url}');
        // 更新存储中的服务器ID
        userStorage.serverId.value = servers.first.id!;
        Logger.d('✓ Updated stored server ID to: ${servers.first.id}');
      }
    } else {
      // 如果用户没有上次使用的服务器，加载第一个服务器
      currentServer.value = servers.first;
      Logger.d('✓ Loaded first server (no saved server ID): ${servers.first.url}');
      // 更新存储中的服务器ID
      userStorage.serverId.value = servers.first.id!;
      Logger.d('✓ Updated stored server ID to: ${servers.first.id}');
    }
  }

  // WebDAV 相关功能
  Future<List<ObjectModel>> getWebDAVFiles(String path, {Function(WebDAVError)? onError}) async {
    StepLogger.start('获取WebDAV文件列表', context: 'WebDAV');
    Logger.d('=== Starting getWebDAVFiles() for path: $path ===');
    isLoading.value = true;
    errorMessage.value = '';
    
    try {
      StepLogger.step('设置当前路径', context: 'WebDAV', data: path);
      currentPath.value = path;
      
      StepLogger.step('检查服务器配置', context: 'WebDAV');
      // 检查当前服务器是否配置
      if (currentServer.value == null) {
        Logger.w('No server configured for WebDAV request');
        final error = WebDAVError(
          WebDAVErrorType.UNKNOWN_ERROR,
          'No server configured',
        );
        onError?.call(error);
        errorMessage.value = error.message;
        currentObjects.value = [];
        StepLogger.end('获取WebDAV文件列表', context: 'WebDAV', success: false);
        return [];
      }
      
      StepLogger.step('获取服务器配置信息', context: 'WebDAV');
      // 从真实的WebDAV服务器获取文件列表
      final serverUrl = currentServer.value!.url;
      final username = currentServer.value!.username;
      final password = currentServer.value!.password;
      
      StepLogger.step('验证服务器配置', context: 'WebDAV');
      // 验证服务器配置
      if (serverUrl.isEmpty) {
        Logger.w('Server URL is empty');
        final error = WebDAVError(
          WebDAVErrorType.UNKNOWN_ERROR,
          'Server URL is empty',
        );
        onError?.call(error);
        errorMessage.value = error.message;
        currentObjects.value = [];
        StepLogger.end('获取WebDAV文件列表', context: 'WebDAV', success: false);
        return [];
      }
      
      StepLogger.step('使用WebDAV协议', context: 'WebDAV');
      // 使用主流的WebDAV协议实现
      Logger.d('=== Using mainstream WebDAV protocol ===');
      
      // 构建完整的WebDAV URL - 采用主流的URL构建方式
      String webDavUrl = serverUrl;
      // 确保URL格式正确
      if (!webDavUrl.startsWith('http://') && !webDavUrl.startsWith('https://')) {
        webDavUrl = 'http://$webDavUrl';
      }
      // 确保URL以/结尾
      if (!webDavUrl.endsWith('/')) {
        webDavUrl += '/';
      }
      // 添加路径
      if (path != '/' && path.isNotEmpty) {
        // 移除路径开头的/
        String cleanPath = path.startsWith('/') ? path.substring(1) : path;
        // 移除路径结尾的/
        cleanPath = cleanPath.endsWith('/') ? cleanPath.substring(0, cleanPath.length - 1) : cleanPath;
        
        // 检查是否存在路径重复
        String serverPath = Uri.parse(webDavUrl).path;
        if (serverPath.isNotEmpty && serverPath != '/' && cleanPath.startsWith(serverPath.substring(1))) {
          // 如果serverUrl已经包含了path的部分，只添加剩余部分
          cleanPath = cleanPath.substring(serverPath.length - 1);
        }
        
        // 只有当cleanPath不为空时才添加
        if (cleanPath.isNotEmpty) {
          // 对路径每一段进行 URL 编码，避免中文/空格等非 ASCII 字符导致请求失败
          final encodedPath = cleanPath
              .split('/')
              .map((seg) => Uri.encodeComponent(seg))
              .join('/');
          webDavUrl += encodedPath;
          // 确保路径URL以/结尾
          if (!webDavUrl.endsWith('/')) {
            webDavUrl += '/';
          }
        }
      }
      
      // 构建认证头
      Logger.d('Username: $username');
      Logger.d('Password length: ${password.length}');
      
      final credentials = '$username:$password';
      final encodedCredentials = base64Encode(utf8.encode(credentials));
      final authHeader = 'Basic $encodedCredentials';
      
      Logger.d('WebDAV Server: $serverUrl');
      Logger.d('WebDAV Path: $path');
      Logger.d('Final WebDAV URL: $webDavUrl');
      
      // 检查dioService是否可用
      if (dioService == null || dioService.dio == null) {
        Logger.w('DioService or Dio instance is null');
        final error = WebDAVError(
          WebDAVErrorType.NETWORK_ERROR,
          'Network service not available',
        );
        onError?.call(error);
        errorMessage.value = error.message;
        currentObjects.value = [];
        return [];
      }
      
      // 测试服务器连接 - 添加额外的诊断步骤
      try {
        Logger.d('=== Testing server connectivity ===');
        // 首先发送一个简单的HEAD请求测试连接
        final headResponse = await dioService.dio.head(
          webDavUrl,
          options: Options(
            headers: {
              'Authorization': authHeader,
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
            validateStatus: (status) {
              return status! < 500;
            },
            connectTimeout: Duration(seconds: 15),
            receiveTimeout: Duration(seconds: 15),
          ),
        );
        Logger.d('HEAD request status: ${headResponse.statusCode}');
        Logger.d('HEAD response headers: ${headResponse.headers}');
      } catch (headError) {
        Logger.w('HEAD request failed: $headError');
      }
      
      // 尝试使用标准的WebDAV PROPFIND请求（网络异常自动重试一次）
      Response<dynamic>? propfindResponse;
      try {
        propfindResponse = await _sendPropfind(webDavUrl, authHeader, 1);
      } catch (e) {
        Logger.w('PROPFIND request failed: $e');
      }
      if (propfindResponse == null) {
        // 首次网络级失败：短暂等待后重试一次（部分服务器握手慢 / 偶发丢包）
        try {
          await Future.delayed(const Duration(milliseconds: 400));
          propfindResponse = await _sendPropfind(webDavUrl, authHeader, 1);
        } catch (e) {
          Logger.w('PROPFIND retry failed: $e');
        }
      }

      if (propfindResponse != null) {
        final response = propfindResponse!;
        Logger.d('=== Got WebDAV response ===');
        Logger.d('Status code: ${response.statusCode}');
        Logger.d('Status message: ${response.statusMessage}');
        Logger.d('Response length: ${response.data?.length ?? 0}');

        // 检查响应状态
        if (response.statusCode == 207) {
          // 成功，解析WebDAV响应
          final responseData = response.data?.toString() ?? '';
          Logger.d('=== WebDAV request successful ===');
          Logger.d('Response data length: ${responseData.length}');

          final objects = _parseWebDAVResponse(responseData, path, serverUrl);
          if (objects.isNotEmpty) {
            currentObjects.value = objects;
            Logger.d('Found ${objects.length} files/folders');
            for (final obj in objects) {
              Logger.d('  - ${obj.isDir ?? false ? 'DIR' : 'FILE'}: ${obj.name} (${obj.size ?? 0} bytes)');
            }
            StepLogger.end('获取WebDAV文件列表', context: 'WebDAV', success: true);
            return objects;
          }
          // 207 但解析为空：可能是目录确实为空，也可能是服务器返回了非标准 XML。
          // 先尝试备选方法（HTML 目录列表等），仍为空则视为空目录，不误报"连接失败"。
          Logger.d('207 with empty parse result, trying alternative methods');
          final altObjects =
              await _tryAlternativeMethods(webDavUrl, authHeader, path, serverUrl, onError);
          if (altObjects.isNotEmpty) {
            currentObjects.value = altObjects;
            return altObjects;
          }
          currentObjects.value = [];
          return [];
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          // 认证错误
          final error = WebDAVError(
            WebDAVErrorType.AUTH_ERROR,
            'Authentication failed: Invalid username or password',
            originalError: response,
          );
          Logger.e('Authentication error: ${error.message}');
          onError?.call(error);
          errorMessage.value = error.message;
          currentObjects.value = [];
          return [];
        } else if (response.statusCode == 405) {
          // 405 Method Not Allowed - 尝试使用备选方法
          Logger.d('Server returned 405 Method Not Allowed, trying alternative methods');
          return await _tryAlternativeMethods(webDavUrl, authHeader, path, serverUrl, onError);
        } else if (response.statusCode == 200) {
          // 200 OK - 可能是HTML目录列表
          Logger.d('Server returned 200 OK, trying to parse as HTML directory listing');
          final objects = _parseGetResponse(response.data?.toString() ?? '', path, serverUrl);
          if (objects.isNotEmpty) {
            currentObjects.value = objects;
            Logger.d('Parsed ${objects.length} files from HTML response');
            return objects;
          } else {
            // 解析失败，尝试备选方法
            return await _tryAlternativeMethods(webDavUrl, authHeader, path, serverUrl, onError);
          }
        } else {
          // 其他错误
          final error = WebDAVError(
            WebDAVErrorType.SERVER_ERROR,
            'Server error: ${response.statusCode} ${response.statusMessage}',
            originalError: response,
          );
          Logger.e('Server error: ${error.message}');
          onError?.call(error);
          errorMessage.value = error.message;
          currentObjects.value = [];
          return [];
        }
      }

      // PROPFIND 网络级失败：尝试使用OPTIONS方法检测服务器支持的方法
      try {
        Logger.d('=== Trying OPTIONS method to detect server capabilities ===');
        final optionsResponse = await dioService.dio.request(
          webDavUrl,
          options: Options(
            method: 'OPTIONS',
            headers: {
              'Authorization': authHeader,
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            },
            validateStatus: (status) {
              return status! < 500;
            },
          ),
        );

        Logger.d('OPTIONS response status: ${optionsResponse.statusCode}');
        Logger.d('Allow headers: ${optionsResponse.headers['allow']}');
        Logger.d('DAV headers: ${optionsResponse.headers['dav']}');
      } catch (optionsError) {
        Logger.w('Error sending OPTIONS request: $optionsError');
      }

      // 尝试使用GET方法作为最后的备选
      return await _tryAlternativeMethods(webDavUrl, authHeader, path, serverUrl, onError);
    } on DioError catch (e) {
      Logger.e('Network error in WebDAV request: $e');
      Logger.e('Dio error type: ${e.type}');
      Logger.e('Dio error message: ${e.message}');
      if (e.response != null) {
        Logger.e('Dio error response status: ${e.response?.statusCode}');
        Logger.e('Dio error response data: ${e.response?.data}');
        Logger.e('Dio error response headers: ${e.response?.headers}');
      }
      
      String errorMsg;
      if (e.type == DioErrorType.connectionTimeout) {
        errorMsg = 'Connection timeout: Server is not responding';
      } else if (e.type == DioErrorType.receiveTimeout) {
        errorMsg = 'Receive timeout: Server took too long to respond';
      } else if (e.type == DioErrorType.sendTimeout) {
        errorMsg = 'Send timeout: Failed to send request';
      } else if (e.type == DioErrorType.badResponse) {
        errorMsg = 'Server error: ${e.response?.statusCode} ${e.response?.statusMessage}';
      } else if (e.type == DioErrorType.cancel) {
        errorMsg = 'Request cancelled';
      } else {
        errorMsg = 'Network error: ${e.message}';
      }
      
      final error = WebDAVError(
        WebDAVErrorType.NETWORK_ERROR,
        errorMsg,
        originalError: e,
      );
      onError?.call(error);
      errorMessage.value = errorMsg;
      currentObjects.value = [];
      return [];
    } catch (e) {
      Logger.e('Unexpected error in WebDAV request: $e');
      final error = WebDAVError(
        WebDAVErrorType.UNKNOWN_ERROR,
        'Unknown error: ${e.toString()}',
        originalError: e,
      );
      onError?.call(error);
      errorMessage.value = error.message;
      currentObjects.value = [];
      StepLogger.end('获取WebDAV文件列表', context: 'WebDAV', success: false);
      return [];
    } finally {
      isLoading.value = false;
      Logger.d('=== getWebDAVFiles() completed ===');
    }
  }

  // 测试方法：获取模拟文件列表
  Future<List<ObjectModel>> getMockWebDAVFiles(String path) async {
    isLoading.value = true;
    
    try {
      // 模拟网络延迟
      await Future.delayed(Duration(seconds: 1));
      
      // 创建模拟文件列表
      final mockFiles = <ObjectModel>[
        ObjectModel()
          ..name = 'Documents'
          ..type = 1
          ..size = 0
          ..isDir = true
          ..rawUrl = '$path/Documents/'
          ..modified = DateTime.now(),
        ObjectModel()
          ..name = 'Pictures'
          ..type = 1
          ..size = 0
          ..isDir = true
          ..rawUrl = '$path/Pictures/'
          ..modified = DateTime.now(),
        ObjectModel()
          ..name = 'Music'
          ..type = 1
          ..size = 0
          ..isDir = true
          ..rawUrl = '$path/Music/'
          ..modified = DateTime.now(),
        ObjectModel()
          ..name = 'file1.txt'
          ..type = 2
          ..size = 1024
          ..isDir = false
          ..rawUrl = '$path/file1.txt'
          ..modified = DateTime.now(),
        ObjectModel()
          ..name = 'file2.pdf'
          ..type = 2
          ..size = 2048
          ..isDir = false
          ..rawUrl = '$path/file2.pdf'
          ..modified = DateTime.now(),
      ];
      
      currentObjects.value = mockFiles;
      Logger.d('Returned ${mockFiles.length} mock files');
      
      return mockFiles;
    } catch (e) {
      Logger.e('Error getting mock WebDAV files: $e');
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  // 辅助方法：查找元素
  List<XmlElement> _findElements(XmlElement parent, String localName, String? namespaceUri) {
    final elements = <XmlElement>[];
    
    void traverse(XmlNode node) {
      if (node is XmlElement) {
        if (node.name.local == localName && (namespaceUri == null || node.namespaceUri == namespaceUri)) {
          elements.add(node);
        }
        for (final child in node.children) {
          traverse(child);
        }
      }
    }
    
    traverse(parent);
    return elements;
  }

  // 解析WebDAV响应
  // 发送标准 WebDAV PROPFIND 请求（统一封装，失败返回 null 由调用方决定重试/备选）
  Future<Response<dynamic>?> _sendPropfind(String url, String authHeader, int depth) async {
    try {
      return await dioService.dio.request(
        url,
        options: Options(
          method: 'PROPFIND',
          headers: {
            'Depth': '$depth',
            'Authorization': authHeader,
            'Content-Type': 'application/xml',
            'Accept': 'application/xml, text/xml;q=0.9, */*;q=0.8',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) {
            return status! < 500;
          },
          // 标准的超时设置
          connectTimeout: Duration(seconds: 30),
          receiveTimeout: Duration(seconds: 60),
        ),
        // 标准的PROPFIND请求体，包含更多属性
        data: '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <resourcetype/>
    <getcontentlength/>
    <getlastmodified/>
    <getcontenttype/>
  </prop>
</propfind>''',
      );
    } catch (e) {
      Logger.w('_sendPropfind error: $e');
      return null;
    }
  }

  List<ObjectModel> _parseWebDAVResponse(String response, String path, String serverUrl) {
    final objects = <ObjectModel>[];
    
    try {
      Logger.d('Parsing WebDAV response');
      
      // 简单的XML解析逻辑
      final document = XmlDocument.parse(response);
      
      // 定义DAV命名空间
      final String davNamespace = 'DAV:';
      
      // 使用手动元素查找
      var responseElements = <XmlElement>[];
      
      // 首先尝试使用命名空间查找所有response元素
      responseElements = _findElements(document.rootElement, 'response', davNamespace);
      Logger.d('Found ${responseElements.length} response elements with DAV: namespace');
      
      // 如果没有找到，尝试不使用命名空间
      if (responseElements.isEmpty) {
        responseElements = _findElements(document.rootElement, 'response', null);
        Logger.d('Found ${responseElements.length} response elements without namespace');
      }
      
      // 处理所有response元素
      for (final element in responseElements) {
        try {
          _parseResponseElement(element, objects, path, serverUrl, responseElements.isEmpty ? null : davNamespace, response);
        } catch (e) {
          Logger.w('Error parsing response element: $e');
          continue;
        }
      }
      
      // 如果仍然没有找到元素，尝试使用备选方法
      if (objects.isEmpty) {
        Logger.d('Trying alternative element finding method');
        try {
          // 遍历所有子元素
          final allElements = document.rootElement.children;
          Logger.d('Root element children count: ${allElements.length}');
          
          for (final child in allElements) {
            if (child is XmlElement) {
              Logger.d('Child element: ${child.name.local}');
              if (child.name.local == 'response' || child.name.local.contains('response')) {
                try {
                  _parseResponseElement(child, objects, path, serverUrl, null, response);
                } catch (e) {
                  Logger.w('Error parsing child element: $e');
                }
              }
            }
          }
        } catch (e) {
          Logger.w('Error using alternative method: $e');
        }
      }
    } catch (e) {
      Logger.e('Error parsing WebDAV response: $e');
      // 如果解析失败，返回一个空列表
    }
    
    Logger.d('Parsed ${objects.length} objects from WebDAV response');
    return objects;
  }
  
  // 解析单个WebDAV响应元素
  void _parseResponseElement(XmlElement element, List<ObjectModel> objects, String path, String serverUrl, String? namespace, String responseData) {
    // 获取资源路径
    var hrefElements = _findElements(element, 'href', namespace);
    var hrefElement = hrefElements.isNotEmpty ? hrefElements.first : null;
    
    if (hrefElement == null) {
      Logger.w('No href element found, skipping');
      return;
    }
    
    var href = hrefElement.text;
    // 清理href
    href = href.trim();
    
    Logger.d('Processing resource: $href');
    
    // 跳过当前目录
    final currentPathClean = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final hrefClean = href.endsWith('/') ? href.substring(0, href.length - 1) : href;
    
    // 检查是否是当前目录
    if (hrefClean == currentPathClean) {
      Logger.d('Skipping current directory: $href');
      return;
    }
    
    // 检查是否是与父目录或祖先目录同名的子目录
     // 例如：当在 /dav/115 目录中时，服务器返回 /dav/115/115/
     
     // 清理路径，移除服务器URL部分，只保留相对路径
     String relativeHref = href;
     if (relativeHref.startsWith(serverUrl)) {
       relativeHref = relativeHref.substring(serverUrl.length);
     }
     
     // href 可能是相对服务器根的路径（含 serverUrl 的路径前缀，如 /dav/115/）
     // 需要去掉该前缀，否则会把"当前目录自身"误判为同名子目录
     if (!relativeHref.startsWith('http://') && !relativeHref.startsWith('https://')) {
       try {
         final serverPath = Uri.parse(serverUrl).path;
         if (serverPath.isNotEmpty &&
             serverPath != '/' &&
             (relativeHref == serverPath ||
                 relativeHref.startsWith('$serverPath/'))) {
           relativeHref = relativeHref.substring(serverPath.length);
         }
       } catch (_) {}
     }
     
     // 确保路径以/开头
     if (!relativeHref.startsWith('/')) {
       relativeHref = '/$relativeHref';
     }
     
     // 统一 URL 解码后再比较（href 通常为 URL 编码，path 为已解码，
     // 中文目录名不解码会导致目录自身被误判为同名子目录）
     String cleanRelativeHref = relativeHref;
     try {
       cleanRelativeHref = Uri.decodeComponent(cleanRelativeHref);
     } catch (_) {}
     cleanRelativeHref = cleanRelativeHref.endsWith('/')
         ? cleanRelativeHref.substring(0, cleanRelativeHref.length - 1)
         : cleanRelativeHref;

     // 当前访问路径（已解码）
     final cleanPath = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
     
     // 分割路径为部分
     final pathParts = cleanPath.split('/').where((part) => part.isNotEmpty).toList();
     final hrefParts = cleanRelativeHref.split('/').where((part) => part.isNotEmpty).toList();
     
     // 检查是否是当前目录
     if (cleanRelativeHref == cleanPath) {
       Logger.d('Skipping current directory: $href');
       return;
     }
     
     // 检查是否是与父目录或祖先目录同名的子目录
     if (hrefParts.length > pathParts.length) {
       // 检查href是否是当前路径的子目录
       bool isChildPath = true;
       for (int i = 0; i < pathParts.length; i++) {
         if (i >= hrefParts.length || hrefParts[i] != pathParts[i]) {
           isChildPath = false;
           break;
         }
       }
       
       if (isChildPath) {
         // 检查href路径中从当前路径长度开始的所有部分
         // 确保没有与当前目录或任何祖先目录同名的目录
         for (int i = pathParts.length; i < hrefParts.length; i++) {
           final currentHrefPart = hrefParts[i];
           
           // 检查当前href部分是否与任何祖先目录同名
           for (int j = 0; j < pathParts.length; j++) {
             if (currentHrefPart == pathParts[j]) {
               Logger.d('Skipping directory with same name as ancestor directory: $href');
               return;
             }
           }
         }
       }
     }
    
    // 尝试获取资源属性
    var propstatElements = _findElements(element, 'propstat', namespace);
    var propstatElement = propstatElements.isNotEmpty ? propstatElements.first : null;
    
    // 尝试直接获取prop元素（如果没有propstat）
    var propElement;
    if (propstatElement != null) {
      var propElements = _findElements(propstatElement, 'prop', namespace);
      propElement = propElements.isNotEmpty ? propElements.first : null;
    } else {
      // 直接在element下查找prop元素
      var propElements = _findElements(element, 'prop', namespace);
      propElement = propElements.isNotEmpty ? propElements.first : null;
    }
    
    // 获取文件名称
    String fileName = 'unknown';
    final parts = href.split('/');
    // 找到最后一个非空部分
    for (int i = parts.length - 1; i >= 0; i--) {
      if (parts[i].isNotEmpty) {
        fileName = parts[i];
        break;
      }
    }
    // 清理文件名
    fileName = fileName.trim();
    
    // 如果文件名以/结尾，移除它
    if (fileName.endsWith('/')) {
      fileName = fileName.substring(0, fileName.length - 1);
    }
    
    // 解码URL编码的文件名（处理中文乱码）
    try {
      fileName = Uri.decodeComponent(fileName);
    } catch (e) {
      Logger.w('Error decoding fileName: $e');
    }
    
    // 获取文件类型
    final isDir = href.endsWith('/');
    
    // 获取文件大小
    int size = 0;
    if (propElement != null && !isDir) {
      var contentLengthElements = _findElements(propElement, 'getcontentlength', namespace);
      var contentLengthElement = contentLengthElements.isNotEmpty ? contentLengthElements.first : null;
      
      if (contentLengthElement != null) {
        size = int.tryParse(contentLengthElement.text.trim()) ?? 0;
      }
    }
    
    // 获取修改时间
    DateTime? modified;
    if (propElement != null) {
      var lastModifiedElements = _findElements(propElement, 'getlastmodified', namespace);
      var lastModifiedElement = lastModifiedElements.isNotEmpty ? lastModifiedElements.first : null;
      
      if (lastModifiedElement != null) {
        modified = DateTime.tryParse(lastModifiedElement.text.trim());
      }
    }
    
    // 检查是否为目录（通过resourcetype）
    bool isDirectory = isDir;
    if (propElement != null) {
      var resourceTypeElements = _findElements(propElement, 'resourcetype', namespace);
      var resourceTypeElement = resourceTypeElements.isNotEmpty ? resourceTypeElements.first : null;
      
      if (resourceTypeElement != null) {
        var collectionElements = _findElements(resourceTypeElement, 'collection', namespace);
        var collectionElement = collectionElements.isNotEmpty ? collectionElements.first : null;
        
        if (collectionElement != null) {
          isDirectory = true;
        }
      }
    }
    
    // 创建ObjectModel
    final object = ObjectModel();
    object.name = fileName;
    object.type = isDirectory ? 1 : 2; // 1 for directory, 2 for file
    object.size = size;
    object.isDir = isDirectory;
    
    // 设置rawUrl，确保使用完整的真实链接
    String rawUrl = href;
    
    // 检查是否是完整的互联网地址
    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
      // 检查WebDAV响应中是否包含真实的文件URL
      // 有些WebDAV服务器会在响应中包含真实的文件URL
      // 这里可以添加逻辑来解析响应中的真实URL
      
      // 如果没有找到真实的URL，使用WebDAV服务器地址构建URL
      String fullUrl = serverUrl;
      if (!fullUrl.endsWith('/')) {
        fullUrl += '/';
      }
      
      // 移除rawUrl开头的/（如果有）
      String cleanHref = rawUrl;
      if (cleanHref.startsWith('/')) {
        cleanHref = cleanHref.substring(1);
      }
      
      // 检查是否存在路径重复
      String serverPath = Uri.parse(fullUrl).path;
      if (serverPath.isNotEmpty && serverPath != '/' && cleanHref.startsWith(serverPath.substring(1))) {
        // 如果serverUrl已经包含了href的部分，只添加剩余部分
        cleanHref = cleanHref.substring(serverPath.length - 1);
      }
      
      // 构建最终URL
      rawUrl = fullUrl + cleanHref;
    }
    
    // 解码URL，确保是自然可读的格式
    try {
      final uri = Uri.parse(rawUrl);
      // 解码路径部分
      final decodedPath = Uri.decodeComponent(uri.path);
      // 重新构建URL
      final decodedUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: decodedPath,
        query: uri.query,
        fragment: uri.fragment
      );
      rawUrl = decodedUri.toString();
    } catch (e) {
      Logger.w('Error decoding raw URL: $e');
    }
    
    // 尝试从WebDAV响应中提取真实的互联网地址
    // 有些WebDAV服务器会在响应中包含真实的文件URL
    String? realInternetUrl = _extractRealInternetUrl(responseData, href);
    if (realInternetUrl != null && (realInternetUrl.startsWith('http://') || realInternetUrl.startsWith('https://'))) {
      // 如果找到真实的互联网地址，使用它作为rawUrl
      rawUrl = realInternetUrl;
      Logger.d('Using real internet URL: $rawUrl');
    }
    
    object.rawUrl = rawUrl;
    object.modified = modified;
    
    // 设置缩略图URL（如果是图片或视频）
    if (!isDirectory) {
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg') || 
          lowerName.endsWith('.png') || lowerName.endsWith('.gif') ||
          lowerName.endsWith('.mp4') || lowerName.endsWith('.avi') ||
          lowerName.endsWith('.mov') || lowerName.endsWith('.wmv')) {
        // 确保使用完整的URL作为缩略图URL
        String thumbUrl = href;
        // 如果href不是完整的URL，构建完整URL
        if (!thumbUrl.startsWith('http://') && !thumbUrl.startsWith('https://')) {
          // 构建完整的WebDAV URL
          String fullUrl = serverUrl;
          if (!fullUrl.endsWith('/')) {
            fullUrl += '/';
          }
          
          // 移除thumbUrl开头的/（如果有）
          String cleanThumbUrl = thumbUrl;
          if (cleanThumbUrl.startsWith('/')) {
            cleanThumbUrl = cleanThumbUrl.substring(1);
          }
          
          // 检查是否存在路径重复
          String serverPath = Uri.parse(fullUrl).path;
          if (serverPath.isNotEmpty && serverPath != '/' && cleanThumbUrl.startsWith(serverPath.substring(1))) {
            // 如果serverUrl已经包含了thumbUrl的部分，只添加剩余部分
            cleanThumbUrl = cleanThumbUrl.substring(serverPath.length - 1);
          }
          
          // 构建最终URL
          thumbUrl = fullUrl + cleanThumbUrl;
        }
        // 解码URL，确保是自然可读的格式
        try {
          final uri = Uri.parse(thumbUrl);
          // 解码路径部分
          final decodedPath = Uri.decodeComponent(uri.path);
          // 重新构建URL
          final decodedUri = Uri(
            scheme: uri.scheme,
            host: uri.host,
            port: uri.port,
            path: decodedPath,
            query: uri.query,
            fragment: uri.fragment
          );
          thumbUrl = decodedUri.toString();
        } catch (e) {
          Logger.w('Error decoding thumbnail URL: $e');
        }
        object.thumb = thumbUrl;
      }
    }
    
    // 只添加有效的对象
    if (fileName.isNotEmpty && !fileName.contains('..')) {
      objects.add(object);
      Logger.d('Added object: $fileName (${isDirectory ? 'directory' : 'file'}, $size bytes)');
    }
  }
  
  // 尝试使用备选方法获取文件列表
  Future<List<ObjectModel>> _tryAlternativeMethods(String url, String authHeader, String path, String serverUrl, Function(WebDAVError)? onError) async {
    Logger.d('=== Trying alternative methods for WebDAV ===');
    
    // 1. 尝试使用GET方法
    try {
      Logger.d('1. Trying GET method...');
      final getObjects = await _tryGetMethod(url, authHeader, path, serverUrl, onError);
      if (getObjects.isNotEmpty) {
        Logger.d('GET method successful, found ${getObjects.length} items');
        return getObjects;
      }
    } catch (e) {
      Logger.w('GET method failed: $e');
    }
    
    // 2. 尝试使用带目录后缀的URL
    try {
      Logger.d('2. Trying URL with directory suffix...');
      final dirUrl = url.endsWith('/') ? url : '$url/';
      final dirObjects = await _tryGetMethod(dirUrl, authHeader, path, serverUrl, onError);
      if (dirObjects.isNotEmpty) {
        Logger.d('Directory suffix method successful, found ${dirObjects.length} items');
        return dirObjects;
      }
    } catch (e) {
      Logger.w('Directory suffix method failed: $e');
    }
    
    // 3. 尝试使用简化的HEAD请求获取服务器信息
    try {
      Logger.d('3. Trying HEAD method to check server...');
      final headResponse = await dioService.dio.head(
        url,
        options: Options(
          headers: {
            'Authorization': authHeader,
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );
      
      Logger.d('HEAD response status: ${headResponse.statusCode}');
      Logger.d('HEAD response headers: ${headResponse.headers}');
    } catch (e) {
      Logger.w('HEAD method failed: $e');
    }
    
    // 所有方法都失败，返回空列表
    Logger.e('All alternative methods failed');
    final error = WebDAVError(
      WebDAVErrorType.NETWORK_ERROR,
      '无法连接 WebDAV 服务器：PROPFIND/GET 均失败。请检查网络连接、服务器地址（含协议头 https://）与登录账号，必要时在设置中重新测试连接。',
    );
    onError?.call(error);
    errorMessage.value = error.message;
    currentObjects.value = [];
    return [];
  }
  
  // 尝试使用GET方法获取文件列表
  Future<List<ObjectModel>> _tryGetMethod(String url, String authHeader, String path, String serverUrl, Function(WebDAVError)? onError) async {
    try {
      Logger.d('Trying GET method for: $url');
      
      // 构建GET请求选项
      final getOptions = Options(
        method: 'GET',
        headers: {
          'Authorization': authHeader,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
        },
        responseType: ResponseType.plain,
        validateStatus: (status) {
          return status! < 500;
        },
        // 添加具体的超时设置
        connectTimeout: Duration(seconds: 10),
        receiveTimeout: Duration(seconds: 30),
      );
      
      Logger.d('Sending GET request with headers: ${getOptions.headers}');
      
      // 发送GET请求
      final response = await dioService.dio.get(
        url,
        options: getOptions,
      );
      
      Logger.d('Got GET response from server');
      Logger.d('Response status: ${response.statusCode}');
      Logger.d('Response data length: ${response.data?.length ?? 0}');
      
      // 检查响应状态
      if (response.statusCode == 200) {
        // 解析GET响应
        final objects = _parseGetResponse(response.data?.toString() ?? '', path, serverUrl);
        if (objects.isNotEmpty) {
          currentObjects.value = objects;
          Logger.d('Parsed ${objects.length} files from GET response');
          for (final obj in objects) {
            Logger.d('  - ${obj.isDir ?? false ? 'DIR' : 'FILE'}: ${obj.name}');
          }
          return objects;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        final error = WebDAVError(
          WebDAVErrorType.AUTH_ERROR,
          'Authentication failed: Invalid username or password',
          originalError: response,
        );
        Logger.e('Authentication error: ${error.message}');
        onError?.call(error);
        errorMessage.value = error.message;
        currentObjects.value = [];
        return [];
      }
      
      // GET方法失败
      return [];
    } catch (e) {
      Logger.e('Error sending GET request: $e');
      return [];
    }
  }
  
  // 解析GET响应
  List<ObjectModel> _parseGetResponse(String response, String path, String serverUrl) {
    final objects = <ObjectModel>[];
    
    try {
      Logger.d('Parsing GET response (length: ${response.length})');
      
      // 检查是否为HTML响应
      if (response.toLowerCase().contains('<html')) {
        Logger.d('Parsing HTML response');
        objects.addAll(_parseHtmlResponse(response, path, serverUrl));
      }
      // 检查是否为XML响应
      else if (response.trim().startsWith('<?xml')) {
        Logger.d('Parsing XML response');
        objects.addAll(_parseWebDAVResponse(response, path, serverUrl));
      }
      // 其他响应类型
      else {
        Logger.d('Unknown response type, trying basic parsing');
        objects.addAll(_parseBasicResponse(response, path, serverUrl));
      }
    } catch (e) {
      Logger.e('Error parsing GET response: $e');
    }
    
    Logger.d('Parsed ${objects.length} objects from GET response');
    return objects;
  }
  
  // 解析HTML响应
  List<ObjectModel> _parseHtmlResponse(String html, String path, String serverUrl) {
    final objects = <ObjectModel>[];
    
    try {
      Logger.d('=== Parsing HTML response ===');
      
      // 记录HTML响应的前500个字符，以便调试
      Logger.d('HTML preview: ${html.substring(0, html.length > 500 ? 500 : html.length)}...');
      
      // 尝试多种正则表达式来匹配链接
      List<RegExp> linkRegexes = [
        // 标准链接格式
        RegExp(r'<a\s+[^>]*href="([^"]+)"[^>]*>([^<]+)</a>', caseSensitive: false, dotAll: true),
        // 单引号链接格式
        RegExp(r"<a\s+[^>]*href='([^']+)'[^>]*>([^<]+)</a>", caseSensitive: false, dotAll: true),
        // 无引号链接格式
        RegExp(r'<a\s+[^>]*href=([^\s>]+)[^>]*>([^<]+)</a>', caseSensitive: false, dotAll: true),
      ];
      
      int totalMatches = 0;
      for (final regex in linkRegexes) {
        final matches = regex.allMatches(html);
        totalMatches += matches.length;
        
        for (final match in matches) {
          try {
            final href = match.group(1)?.trim() ?? '';
            final text = match.group(2)?.trim() ?? '';
            
            // 跳过无效链接
            if (href.isEmpty) {
              continue;
            }
            
            // 跳过绝对URL（保留相对路径）
            if (href.startsWith('http://') || href.startsWith('https://') || href.startsWith('mailto:')) {
              continue;
            }
            
            // 跳过网页元素链接
            if (href.startsWith('#') || href.startsWith('?')) {
              continue;
            }
            
            // 跳过脚本和样式链接
            if (href.endsWith('.js') || href.endsWith('.css') || href.endsWith('.ico') || href.endsWith('.png') || href.endsWith('.jpg') || href.endsWith('.jpeg')) {
              continue;
            }
            
            // 跳过常见的前端页面导航链接
            if (text.toLowerCase().contains('home') || text.toLowerCase().contains('back') || text.toLowerCase().contains('refresh') || text.toLowerCase().contains('upload') || text.toLowerCase().contains('login') || text.toLowerCase().contains('logout')) {
              continue;
            }
            
            // 提取文件名
            String fileName = text.isEmpty ? href : text;
            
            // 清理文件名
            fileName = fileName.trim();
            // 移除HTML标签
            fileName = fileName.replaceAll(RegExp(r'<[^>]+>'), '');
            // 移除末尾的(...)和[...]信息
            fileName = fileName.replaceAll(RegExp(r'\s*\([^)]+\)\s*$'), '');
            fileName = fileName.replaceAll(RegExp(r'\s*\[[^\]]+\]\s*$'), '');
            // 清理空白字符
            fileName = fileName.trim();
            
            // 如果文件名仍然为空，使用href作为文件名
            if (fileName.isEmpty) {
              fileName = href;
            }
            
            // 处理路径部分
            if (fileName.contains('/')) {
              fileName = fileName.split('/').last;
            }
            
            // 判断是否为目录
            final isDir = href.endsWith('/') || text.endsWith('/') || fileName.endsWith('/');
            
            // 构建完整路径
            String fullPath;
            if (path == '/') {
              fullPath = '$path${href.replaceAll('../', '')}';
            } else {
              fullPath = '$path/${href.replaceAll('../', '')}';
            }
            // 清理路径
            fullPath = fullPath.replaceAll('//', '/');
            
            // 只添加有效的文件/目录名
            if (fileName.isNotEmpty && !fileName.contains('<') && !fileName.contains('>')) {
              // 创建ObjectModel
              final object = ObjectModel();
              object.name = fileName;
              object.type = isDir ? 1 : 2;
              object.size = 0;
              object.isDir = isDir;
              object.rawUrl = fullPath;
              object.modified = DateTime.now();
              
              objects.add(object);
              Logger.d('Added object from HTML: ${object.name} (${isDir ? 'dir' : 'file'})');
            }
          } catch (e) {
            Logger.w('Error parsing individual HTML link: $e');
            continue;
          }
        }
      }
      
      Logger.d('Found $totalMatches total links in HTML');
      Logger.d('=== HTML parsing completed, found ${objects.length} objects ===');
      
      // 如果HTML解析失败，尝试基本解析
      if (objects.isEmpty) {
        Logger.d('No objects found with HTML parsing, trying basic parsing');
        return _parseBasicResponse(html, path, serverUrl);
      }
    } catch (e) {
      Logger.e('Error parsing HTML response: $e');
      // 解析失败时尝试基本解析
      return _parseBasicResponse(html, path, serverUrl);
    }
    
    return objects;
  }

  // 尝试使用Alist的REST API获取文件列表
  Future<List<ObjectModel>> _tryAlistApi(String serverUrl, String username, String password, String path) async {
    final objects = <ObjectModel>[];
    
    try {
      Logger.d('=== Trying Alist REST API ===');
      
      String baseUrl = serverUrl;
      if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
        baseUrl = 'http://$baseUrl';
      }
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      
      Logger.d('Alist Base URL: $baseUrl');
      
      final loginUrl = '$baseUrl/api/auth/login';
      Logger.d('Login URL: $loginUrl');
      
      final loginBody = {
        'username': username,
        'password': password,
      };
      
      Logger.d('Sending login request...');
      
      final loginResponse = await dioService.dio.post(
        loginUrl,
        data: loginBody,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) {
            return status! < 500;
          },
          connectTimeout: Duration(seconds: 10),
          receiveTimeout: Duration(seconds: 30),
        ),
      );
      
      Logger.d('Login response status: ${loginResponse.statusCode}');
      
      String token = '';
      if (loginResponse.statusCode == 200) {
        final loginData = loginResponse.data?.toString() ?? '';
        Logger.d('Login response data: $loginData');
        
        try {
          final loginJson = jsonDecode(loginData);
          if (loginJson['code'] == 200 && loginJson['data'] != null) {
            token = loginJson['data']['token']?.toString() ?? '';
            Logger.d('Successfully obtained token, length: ${token.length}');
          } else {
            Logger.w('Login failed: ${loginJson['message'] ?? 'Unknown error'}');
            throw Exception('Login failed: ${loginJson['message'] ?? 'Unknown error'}');
          }
        } catch (e) {
          Logger.e('Error parsing login response: $e');
          throw Exception('Invalid login response');
        }
      } else {
        Logger.e('Login request failed with status: ${loginResponse.statusCode}');
        throw Exception('Login request failed');
      }
      
      final listUrl = '$baseUrl/api/fs/list';
      Logger.d('File list URL: $listUrl');
      
      final listBody = {
        'path': path == '/' ? '/' : path,
        'password': '',
        'page': 1,
        'per_page': 0,
        'refresh': false,
      };
      
      Logger.d('Sending file list request with JWT auth...');
      
      final listResponse = await dioService.dio.post(
        listUrl,
        data: listBody,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Authorization': token,
          },
          responseType: ResponseType.plain,
          validateStatus: (status) {
            return status! < 500;
          },
          connectTimeout: Duration(seconds: 10),
          receiveTimeout: Duration(seconds: 30),
        ),
      );
      
      Logger.d('File list response status: ${listResponse.statusCode}');
      
      if (listResponse.statusCode == 200) {
        final listData = listResponse.data?.toString() ?? '';
        Logger.d('File list response data: $listData');
        
        final listJson = jsonDecode(listData);
        if (listJson['code'] == 200 && listJson['data'] != null) {
          final content = listJson['data']['content'];
          if (content is List) {
            for (final item in content) {
              try {
                final object = ObjectModel();
                object.name = item['name']?.toString() ?? '';
                object.type = item['is_dir'] == true ? 1 : 2;
                object.size = item['size'] ?? 0;
                object.isDir = item['is_dir'] == true;
                object.rawUrl = item['raw_url']?.toString() ?? '';
                
                if (item['modified'] != null) {
                  object.modified = DateTime.tryParse(item['modified'].toString());
                }
                
                objects.add(object);
                Logger.d('Added object from Alist API: ${object.name} (${object.isDir ?? false ? 'dir' : 'file'})');
              } catch (e) {
                Logger.w('Error parsing individual item: $e');
                continue;
              }
            }
          }
          
          Logger.d('=== Alist API parsing completed, found ${objects.length} objects ===');
          return objects;
        } else {
          Logger.w('File list API returned error: ${listJson['message'] ?? 'Unknown error'}');
          throw Exception('API error: ${listJson['message'] ?? 'Unknown error'}');
        }
      } else if (listResponse.statusCode == 401 || listResponse.statusCode == 403) {
        Logger.e('Authentication error with file list API');
        throw Exception('Authentication failed');
      } else {
        Logger.e('File list API returned status: ${listResponse.statusCode}');
        throw Exception('API error: ${listResponse.statusCode}');
      }
    } catch (e) {
      Logger.e('Error calling Alist API: $e');
      throw e;
    }
  }


  // 解析基本响应
  List<ObjectModel> _parseBasicResponse(String response, String path, String serverUrl) {
    final objects = <ObjectModel>[];
    
    try {
      Logger.d('Parsing basic response');
      
      // 尝试按行分割
      final lines = response.split('\n');
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        
        // 简单的文件名提取
        final fileName = trimmedLine;
        final isDir = fileName.endsWith('/');
        
        final object = ObjectModel();
        object.name = isDir ? fileName.substring(0, fileName.length - 1) : fileName;
        object.type = isDir ? 1 : 2;
        object.size = 0;
        object.isDir = isDir;
        object.rawUrl = '$path/$fileName';
        object.modified = DateTime.now();
        
        objects.add(object);
        Logger.d('Added object from basic response: ${object.name}');
      }
    } catch (e) {
      Logger.e('Error parsing basic response: $e');
    }
    
    return objects;
  }

  Future<void> downloadFile(ObjectModel file) async {
    try {
      if (_serviceStatus['DAOs'] ?? false) {
        final download = DownloadEntity(
          serverId: userStorage.serverId.value,
          taskId: DateTime.now().millisecondsSinceEpoch.toString(),
          type: file.type ?? 0,
          path: file.rawUrl ?? '',
          name: file.name ?? '',
          size: file.size ?? 0,
        );
        await downloadDao.insertDownload(download);
        Logger.d('File added to download queue: ${file.name}');
      } else {
        Logger.w('DAOs not initialized, cannot add file to download queue');
      }
    } catch (e) {
      Logger.w('Error downloading file: $e');
    }
  }

  Future<void> addToFavorites(ObjectModel object) async {
    try {
      if (_serviceStatus['DAOs'] ?? false) {
        final favorite = FavoriteEntity(
          serverId: userStorage.serverId.value,
          path: object.rawUrl ?? '',
          name: object.name ?? '',
          type: object.type ?? 0,
          size: object.size ?? 0,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await favoriteDao.insertFavorite(favorite);
        Logger.d('Added to favorites: ${object.name}');
      } else {
        Logger.w('DAOs not initialized, cannot add to favorites');
      }
    } catch (e) {
      Logger.w('Error adding to favorites: $e');
    }
  }

  Future<void> addToRecent(ObjectModel object) async {
    try {
      if (_serviceStatus['DAOs'] ?? false) {
        final recent = RecentEntity(
          serverId: userStorage.serverId.value,
          path: object.rawUrl ?? '',
          name: object.name ?? '',
          type: object.type ?? 0,
          size: object.size ?? 0,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await recentDao.insertRecent(recent);
        Logger.d('Added to recent: ${object.name}');
      } else {
        Logger.w('DAOs not initialized, cannot add to recent');
      }
    } catch (e) {
      Logger.w('Error adding to recent: $e');
    }
  }

  Future<void> refreshAllData() async {
    Logger.d('Refreshing all data...');
    await loadUserData();
    await loadRecentServer();
    Logger.d('All data refreshed');
  }

  // WebDAV 登录方法
  Future<bool> loginToWebDAV(String url, String username, String password) async {
    Logger.d('=== Starting WebDAV login ===');
    Logger.d('URL: $url');
    Logger.d('Username: $username');
    
    try {
      // 构建完整的WebDAV URL
      String webDavUrl = url;
      if (!webDavUrl.startsWith('http://') && !webDavUrl.startsWith('https://')) {
        webDavUrl = 'http://$webDavUrl';
      }
      if (!webDavUrl.endsWith('/')) {
        webDavUrl += '/';
      }
      
      // 构建认证头
      final credentials = '$username:$password';
      final encodedCredentials = base64Encode(utf8.encode(credentials));
      final authHeader = 'Basic $encodedCredentials';
      
      // 发送HEAD请求测试连接
      final response = await dioService.dio.head(
        webDavUrl,
        options: Options(
          headers: {
            'Authorization': authHeader,
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );
      
      Logger.d('Login test response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 401) {
        // 200表示成功，401可能需要认证但服务器存在
        Logger.d('WebDAV server is reachable');
        return true;
      } else {
        Logger.e('WebDAV server login failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      Logger.e('Error testing WebDAV connection: $e');
      return false;
    }
  }

  // 为了兼容其他控制器，添加必要的方法
  Future<void> downloadObject(ObjectModel object) async {
    try {
      await downloadFile(object);
    } catch (e) {
      Logger.w('Error downloading object: $e');
    }
  }

  Future<void> navigateToPath(String path) async {
    isLoading.value = true;
    errorMessage.value = '';
    
    try {
      currentPath.value = path;
      Logger.d('Navigated to path: $path');
      // 加载路径内容
      await getWebDAVFiles(path);
    } catch (e) {
      Logger.w('Error navigating to path: $e');
      errorMessage.value = 'Error navigating to path: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<ObjectModel>> searchObjects(String query) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      Logger.d('Searching objects for: $query');
      // 这里可以添加搜索逻辑
      return [];
    } catch (e) {
      Logger.w('Error searching objects: $e');
      errorMessage.value = 'Error searching objects: $e';
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  // 检查服务是否可用
  bool isServiceAvailable(String serviceName) {
    return _serviceStatus[serviceName] ?? false;
  }

  // 获取所有服务状态
  Map<String, bool> getServiceStatus() {
    return Map.unmodifiable(_serviceStatus);
  }
  
  // 从WebDAV响应中提取真实的互联网地址
  String? _extractRealInternetUrl(String responseData, String href) {
    try {
      Logger.d('Extracting real internet URL from response data');
      
      // 1. 检查href是否已经是完整的互联网地址
      if (href.startsWith('http://') || href.startsWith('https://')) {
        Logger.d('href is already a complete internet URL: $href');
        return href;
      }
      
      // 2. 尝试从WebDAV响应中提取真实的文件URL
      // 有些WebDAV服务器会在响应中包含真实的文件URL
      
      // 3. 检查响应数据中是否包含完整的URL
      // 查找格式为 http:// 或 https:// 开头的URL
      final urlRegex = RegExp(r'https?:\/\/[^\s"<>]+');
      final matches = urlRegex.allMatches(responseData);
      
      for (final match in matches) {
        final url = match.group(0);
        if (url != null) {
          // 检查URL是否与当前资源相关
          // 可以通过检查URL是否包含当前资源的文件名来判断
          final fileName = href.split('/').last;
          if (fileName.isNotEmpty && url.contains(fileName)) {
            Logger.d('Found real internet URL in response: $url');
            return url;
          }
        }
      }
      
      // 4. 检查响应中是否包含特定的XML元素，这些元素可能包含真实的URL
      // 例如，有些服务器会在prop元素中包含real-url或类似的元素
      
      // 5. 尝试解析XML响应，查找可能包含真实URL的元素
      try {
        final document = XmlDocument.parse(responseData);
        
        // 查找可能包含真实URL的元素
        final potentialUrlElements = [
          'real-url', 'realurl', 'external-url', 'externalurl',
          'public-url', 'publicurl', 'download-url', 'downloadurl'
        ];
        
        for (final elementName in potentialUrlElements) {
          final elements = _findElements(document.rootElement, elementName, null);
          for (final element in elements) {
            final url = element.text.trim();
            if (url.startsWith('http://') || url.startsWith('https://')) {
              Logger.d('Found real internet URL in XML element $elementName: $url');
              return url;
            }
          }
        }
      } catch (e) {
        Logger.w('Error parsing XML for real URL extraction: $e');
      }
      
      // 6. 检查是否是Alist服务器的响应格式
      // Alist服务器会在响应中包含raw_url字段
      if (responseData.contains('raw_url')) {
        try {
          // 尝试从JSON中提取raw_url
          // 注意：这只是一个简单的尝试，可能需要根据实际响应格式进行调整
          final rawUrlRegex = RegExp(r'"raw_url"\s*:\s*"([^"]+)"');
          final match = rawUrlRegex.firstMatch(responseData);
          if (match != null) {
            final rawUrl = match.group(1);
            if (rawUrl != null && (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))) {
              Logger.d('Found real internet URL in raw_url field: $rawUrl');
              return rawUrl;
            }
          }
        } catch (e) {
          Logger.w('Error extracting raw_url from response: $e');
        }
      }
      
      // 7. 如果没有找到真实的互联网地址，返回null
      Logger.d('No real internet URL found in response');
      return null;
    } catch (e) {
      Logger.w('Error extracting real internet URL: $e');
      return null;
    }
  }
}

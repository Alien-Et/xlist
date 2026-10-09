import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart' hide Response;
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/storages/user_storage.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/database/entity/index.dart';

class AddServerBottomSheet extends StatefulWidget {
  const AddServerBottomSheet({super.key});

  @override
  _AddServerBottomSheetState createState() => _AddServerBottomSheetState();
}

class _AddServerBottomSheetState extends State<AddServerBottomSheet> {
  TextEditingController _urlController = TextEditingController();
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  bool _isUrlValid = false;
  ServerEntity? _server;
  List<ServerEntity> _serverList = [];

  @override
  void initState() {
    super.initState();
    _getServerList();
  }

  /// 构建带证书放行配置的 Dio（自签/内网证书的 WebDAV 服务器）
  Dio _buildDio() {
    final dio = Dio();
    dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () {
      final client = HttpClient();
      if (Get.find<PreferencesStorage>().ignoreSslVerify.val) {
        client.badCertificateCallback = (cert, host, port) => true;
      }
      return client;
    });
    return dio;
  }

  void _getServerList() async {
    _serverList = await DatabaseService.to.database.serverDao.findAllServer();
    setState(() {});
  }

  Future<bool> _testGuestUser({bool showToast = true}) async {
    String url = _urlController.text.trim();

    if (url.endsWith('/')) url = url.substring(0, url.length - 1);

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      try {
        await _buildDio().get('https://$url/');
        url = 'https://$url';
      } catch (e) {
        url = 'http://$url';
      }
      _urlController.text = url;
    }

    try {
      final response = await _buildDio().get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 301 || response.statusCode == 302) {
        _isUrlValid = true;
        _server = ServerEntity(
            url: url, type: ServerType.WEBDAV, username: '', password: '');
      } else {
        _isUrlValid = false;
      }
    } catch (e) {
      _isUrlValid = false;
    }

    setState(() {});
    if (showToast)
      _isUrlValid
          ? SmartDialog.showToast('add_server_toast_pass'.tr)
          : SmartDialog.showToast('add_server_toast_anonymous_fail'.tr);

    return _isUrlValid;
  }

  Future<bool> _testUrlAndUser({bool showToast = true}) async {
    try {
      String url = _urlController.text.trim();
      String username = _usernameController.text.trim();
      String password = _passwordController.text.trim();

      if (url.isEmpty) {
        if (showToast) SmartDialog.showToast('add_server_toast_url_empty'.tr);
        return false;
      }

      if (username.isEmpty && password.isEmpty) {
        return _testGuestUser(showToast: showToast);
      }

      if (url.endsWith('/')) url = url.substring(0, url.length - 1);

      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        try {
          await _buildDio().post('https://$url/api/auth/login', data: {'username': username, 'password': password});
          url = 'https://$url';
        } catch (e) {
          url = 'http://$url';
        }
        _urlController.text = url;
      }

      // 直接使用WebDAV协议测试连接
      try {
        String webDavUrl = url;
        if (!webDavUrl.endsWith('/')) {
          webDavUrl += '/';
        }

        final authHeader = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

        final response = await _buildDio().request(
          webDavUrl,
          options: Options(
            method: 'PROPFIND',
            headers: {
              'Authorization': authHeader,
              'Depth': '0',
              'Content-Type': 'application/xml',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
            validateStatus: (status) {
              return status! < 500;
            },
            connectTimeout: Duration(seconds: 10),
            receiveTimeout: Duration(seconds: 30),
          ),
          data: '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <getcontentlength/>
    <getlastmodified/>
    <resourcetype/>
  </prop>
</propfind>''',
        );

        if (response.statusCode == 207 || response.statusCode == 200) {
          _isUrlValid = true;
          _server = ServerEntity(
            url: url,
            type: ServerType.WEBDAV,
            username: username,
            password: password,
          );

          if (_serverList.isEmpty && !showToast) {
            Get.find<UserStorage>().serverUrl.value = url;
            Get.find<UserStorage>().username.value = username;
            Get.find<UserStorage>().password.value = password;

            Get.find<DioService>().setBaseUrl(url);
          }
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          throw Exception('认证失败，请检查用户名和密码');
        } else {
          throw Exception('连接失败，请检查服务器地址是否正确');
        }
      } catch (webdavError) {
        throw Exception('连接失败，请检查服务器信息: $webdavError');
      }
    } catch (e) {
      String errorMessage;
      if (e.toString().contains('401') || e.toString().contains('403')) {
        errorMessage = '认证失败，请检查用户名和密码';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        errorMessage = '连接失败，请检查服务器地址是否正确';
      } else {
        errorMessage = '测试失败，请检查服务器信息';
      }
      SmartDialog.showToast(errorMessage);
      _isUrlValid = false;
    }

    setState(() {});
    SmartDialog.dismiss();
    if (showToast)
      _isUrlValid
          ? SmartDialog.showToast('add_server_toast_pass'.tr)
          : SmartDialog.showToast('add_server_toast_url_user_invalid'.tr);

    return _isUrlValid;
  }

  void _saveServer() async {
    SmartDialog.showLoading();
    if (!await _testUrlAndUser(showToast: false)) {
      SmartDialog.showToast('add_server_toast_url_user_invalid'.tr);
      SmartDialog.dismiss();
      return;
    }

    final serverId =
        await DatabaseService.to.database.serverDao.insertServer(_server!);

    // 同步服务器信息到PreferencesStorage，确保CoreService能正确加载
    try {
      final userStorage = Get.find<UserStorage>();
      userStorage.serverId.value = serverId;
      userStorage.serverUrl.value = _server!.url;
      userStorage.username.value = _server!.username;
      userStorage.password.value = _server!.password;
      print('✓ Server info synced to UserStorage: ${_server!.url}');
    } catch (e) {
      print('⚠ Error syncing server info to UserStorage: $e');
    }

    SmartDialog.dismiss();
    SmartDialog.showToast('toast_save_success'.tr);
    Get.back(
      result: ServerEntity(
        id: serverId,
        url: _server!.url,
        type: _server!.type,
        username: _server!.username,
        password: _server!.password,
      ),
    );
  }

  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      backgroundColor: CommonUtils.backgroundColor,
      transitionBetweenRoutes: false,
      border: Border.all(width: 0, color: Colors.transparent),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        child: Text('close'.tr),
        onPressed: () => Get.back(),
      ),
      middle: Text('add_server_title'.tr, style: Get.textTheme.titleMedium),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerRight,
        child: Text('test'.tr),
        onPressed: _testUrlAndUser,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      backgroundColor: CommonUtils.backgroundColor,
      child: SingleChildScrollView(
        child: Column(
          children: [
            CupertinoListSection.insetGrouped(
              backgroundColor: CommonUtils.backgroundColor,
              dividerMargin: 0.r,
              additionalDividerMargin: CommonUtils.isPad ? 15 : 20.r,
              hasLeading: false,
              header: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  'add_server_section_header'.tr,
                  style: Get.textTheme.bodySmall,
                ),
              ),
              footer: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  'add_server_section_footer'.tr,
                  style: Get.textTheme.bodySmall,
                ),
              ),
              children: [
                TextFieldHelper.createCupertino(
                  controller: _urlController,
                  title: 'add_server_textfield_url'.tr,
                  placeholder: 'add_server_textfield_url_hint'.tr,
                  isRequired: true,
                  keyboardType: TextInputType.url,
                ),
                TextFieldHelper.createCupertino(
                  controller: _usernameController,
                  title: 'add_server_textfield_username'.tr,
                  placeholder: 'add_server_textfield_username_hint'.tr,
                ),
                TextFieldHelper.createCupertino(
                  controller: _passwordController,
                  title: 'add_server_textfield_password'.tr,
                  placeholder: 'add_server_textfield_password_hint'.tr,
                  padding: EdgeInsets.only(
                    left: CommonUtils.isPad ? 15 : 30.r,
                    right: CommonUtils.isPad ? 15 : 30.r,
                    top: CommonUtils.isPad ? 10 : 30.r,
                    bottom: CommonUtils.isPad ? 5 : 20.r,
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 100.r, vertical: 30.r),
              child: ButtonHelper.createElevatedButton(
                'save'.tr,
                onPressed: _saveServer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

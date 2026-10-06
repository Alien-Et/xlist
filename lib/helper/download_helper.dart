import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/helper/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/common.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/database/entity/index.dart';

class DownloadHelper {
  /// 保存文件
  /// [path] 文件路径
  /// [name] 文件名
  /// [type] 文件类型
  static file(String path, String name, int type, int size) async {
    bool isStorage = await checkPermissionStorage();
    if (!isStorage) {
      SmartDialog.showToast('toast_no_storage_permission'.tr);
      return;
    }

    // 当前服务器 id
    final serverId = Get.find<UserStorage>().serverId.value;

    // 检查是否已经在下载列表中
    final download = await DatabaseService.to.database.downloadDao
        .findDownloadByServerIdAndPath(serverId, path, name);
    if (download != null) {
      SmartDialog.showToast('toast_download_exist'.tr);
      return;
    }

    // 获取下载地址
    try {
      SmartDialog.showLoading();
      final object = await getDownloadUrl(path, name);

      // 校验下载地址
      if (object.rawUrl == null || object.rawUrl!.isEmpty) {
        SmartDialog.dismiss();
        SmartDialog.showToast('toast_get_download_url_fail'.tr);
        return;
      }

      // 图片类型单独处理
      if (type == FileType.IMAGE) {
        final response = await DioService.to.dio.get(
          object.rawUrl!,
          options: Options(
            responseType: ResponseType.bytes,
            headers: DriverHelper.getWebDAVHeaders(),
          ),
        );

        final result = await ImageGallerySaverPlus.saveImage(
          Uint8List.fromList(response.data),
          quality: 100,
          name: "xlist_${DateTime.now().millisecondsSinceEpoch}.jpg",
        );

        SmartDialog.dismiss();
        if (result['isSuccess'] == false) throw 'toast_save_image_fail'.tr;
        SmartDialog.showToast('toast_save_success'.tr);
        return;
      }

      // 添加到下载列表
      final taskId = await FlutterDownloader.enqueue(
        url: object.rawUrl ?? '',
        headers: DriverHelper.getHeaders(object.provider, object.rawUrl),
        savedDir: await getDownloadPath(path),
        showNotification: false,
      );

      // 添加到数据库
      await DatabaseService.to.database.downloadDao.insertDownload(
        DownloadEntity(
          serverId: serverId,
          path: path,
          name: name,
          taskId: taskId!,
          type: type,
          size: size,
        ),
      );

      SmartDialog.showToast('toast_download_add_success'.tr);
      SmartDialog.dismiss();
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('toast_download_fail'.tr);
      return;
    }
  }

  /// 递归下载文件夹
  /// [path] 文件夹父路径
  /// [name] 文件夹名
  static Future<void> directory(String path, String name) async {
    bool isStorage = await checkPermissionStorage();
    if (!isStorage) {
      SmartDialog.showToast('toast_no_storage_permission'.tr);
      return;
    }

    final serverId = Get.find<UserStorage>().serverId.value;
    final folderPath = '$path/$name';

    try {
      SmartDialog.showLoading();
      final response = await ObjectRepository.getList(path: folderPath);
      SmartDialog.dismiss();
      if (response == null || response['code'] != 200) {
        SmartDialog.showToast('toast_download_fail'.tr);
        return;
      }

      final content = (response['data']['content'] as List)
          .map((json) => ObjectModel.fromJson(json))
          .toList();

      var count = 0;
      await _downloadFolderRecursive(
        folderPath,
        content,
        serverId,
        () => count++,
      );
      SmartDialog.showToast(count == 0 ? '文件夹为空' : '已添加 $count 个文件到下载列表');
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('toast_download_fail'.tr);
    }
  }

  /// 递归遍历文件夹并添加下载
  static Future<void> _downloadFolderRecursive(
    String folderPath,
    List<ObjectModel> objects,
    int serverId,
    void Function() onFile,
  ) async {
    for (final object in objects) {
      final subPath = '$folderPath/${object.name}';
      if (object.isDir == true) {
        // 递归子文件夹
        final response = await ObjectRepository.getList(path: subPath);
        if (response != null && response['code'] == 200) {
          final children = (response['data']['content'] as List)
              .map((json) => ObjectModel.fromJson(json))
              .toList();
          await _downloadFolderRecursive(subPath, children, serverId, onFile);
        }
      } else {
        // 单个文件
        onFile();
        await _enqueueDownload(
          subPath,
          object.name ?? '',
          object.type ?? 0,
          object.size ?? 0,
          serverId,
        );
      }
    }
  }

  /// 添加单个文件到下载列表（不重复弹窗）
  static Future<void> _enqueueDownload(
    String fullPath,
    String name,
    int type,
    int size,
    int serverId,
  ) async {
    // 检查是否已在下载列表中
    final parentDir = fullPath.substring(0, fullPath.lastIndexOf('/'));
    final download = await DatabaseService.to.database.downloadDao
        .findDownloadByServerIdAndPath(serverId, parentDir, name);
    if (download != null) return;

    // 获取下载地址
    final object = await getDownloadUrl(parentDir, name);
    if (object.rawUrl == null || object.rawUrl!.isEmpty) return;

    // 添加到下载列表
    final taskId = await FlutterDownloader.enqueue(
      url: object.rawUrl ?? '',
      headers: DriverHelper.getHeaders(object.provider, object.rawUrl),
      savedDir: await getDownloadPath(fullPath),
      showNotification: false,
    );

    // 添加到数据库
    await DatabaseService.to.database.downloadDao.insertDownload(
      DownloadEntity(
        serverId: serverId,
        path: parentDir,
        name: name,
        taskId: taskId!,
        type: type,
        size: size,
      ),
    );
  }

  /// 获取下载地址
  static Future<ObjectModel> getDownloadUrl(String path, String name) async {
    // 目录密码
    String password = '';
    final serverId = Get.find<UserStorage>().serverId.value;

    // 获取目录密码
    final passwordManager = await DatabaseService.to.database.passwordManagerDao
        .findPasswordManagerByPath(serverId, path);
    if (passwordManager != null && passwordManager.isNotEmpty) {
      password = passwordManager.last.password;
    }

    // 请求服务器获取下载地址
    final object = await ObjectRepository.get(
      path: '${path}${name}',
      password: password,
    );

    return object;
  }

  /// 检查存储权限
  static Future<bool> checkPermissionStorage() async {
    // Android 12 以上不需要申请存储权限
    if (GetPlatform.isAndroid &&
        DeviceInfoService.to.androidInfo.version.sdkInt >= 33) {
      return true;
    }

    // 检查存储权限
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  /// 获取下载目录
  static Future<String> getDownloadPath(String path) async {
    final directory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    String p = directory!.path + '/Downloads' + path;

    // 如果目录不存在则创建
    final savedDir = Directory(p);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) await savedDir.create(recursive: true);
    return p;
  }
}

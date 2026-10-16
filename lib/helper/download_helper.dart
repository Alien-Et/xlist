import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
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
      final saveDir = await getDownloadPath(path);
      final taskId = await FlutterDownloader.enqueue(
        url: object.rawUrl ?? '',
        headers: DriverHelper.getHeaders(object.provider, object.rawUrl),
        savedDir: saveDir,
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

      SmartDialog.dismiss();
      // 弹窗告知下载位置与下一步建议（直接下载到公共下载目录，非私有空间）
      Get.dialog(CupertinoAlertDialog(
        title: const Text('开始下载'),
        content: Text(
          '文件将直接保存到：\n$saveDir\n\n'
          '完成后到「下载管理」点击该文件：\n'
          '· 视频 / 音乐 → 直接播放\n'
          '· 其它文件 → 调用系统应用打开\n'
          '也可以到系统「文件管理」→ Download/CloudX 查看。',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          CupertinoButton(
            child: const Text('知道了'),
            onPressed: () => Get.back(),
          ),
        ],
      ));
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

    // 请求服务器获取下载地址（path 可能不带结尾斜杠，拼接时补齐）
    final fullPath = path.endsWith('/') ? '$path$name' : '$path/$name';
    final object = await ObjectRepository.get(
      path: fullPath,
      password: password,
    );

    return object;
  }

  /// 检查存储权限
  static Future<bool> checkPermissionStorage() async {
    // Android 12 以上不需要申请存储权限（DeviceInfoService 可能未初始化，容错处理）
    if (GetPlatform.isAndroid) {
      try {
        if (DeviceInfoService.to.androidInfo.version.sdkInt >= 33) {
          return true;
        }
      } catch (_) {
        // 拿不到 SDK 版本时继续走权限请求流程
      }
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

  /// 按扩展名归类：图片/视频/音乐/文档/压缩，其它归"文件"
  static String _categoryOf(String path) {
    final base = path.split('/').last;
    final ext = base.contains('.')
        ? base.substring(base.lastIndexOf('.') + 1).toLowerCase()
        : '';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp', 'svg', 'ico']
        .contains(ext)) {
      return '图片';
    }
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'ts', '3gp']
        .contains(ext)) {
      return '视频';
    }
    if (['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'wma', 'ape']
        .contains(ext)) {
      return '音乐';
    }
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md',
            'csv', 'epub']
        .contains(ext)) {
      return '文档';
    }
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'].contains(ext)) {
      return '压缩';
    }
    return '文件';
  }

  /// 获取下载目录
  /// Android：系统下载目录 Download/CloudX/图片|视频|音乐|文档|压缩|文件（按类型分目录，系统 APP 可直接打开）
  static Future<String> getDownloadPath(String path) async {
    final directory = Platform.isAndroid
        ? (await getDownloadsDirectory() ?? await getExternalStorageDirectory())
        : await getApplicationDocumentsDirectory();
    // 按类型分目录：CloudX/图片、CloudX/视频、CloudX/文档、CloudX/压缩等
    String p = '${directory!.path}/CloudX/${_categoryOf(path)}';

    // 如果目录不存在则创建
    final savedDir = Directory(p);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) await savedDir.create(recursive: true);
    return p;
  }
}

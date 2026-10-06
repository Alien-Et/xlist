import 'dart:io';

import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:file_picker/file_picker.dart' hide FileType;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/models/user.dart'; // 导入 UserModel
import 'package:xlist/common/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/pages/detail/index.dart';
import 'package:xlist/pages/homepage/index.dart';
import 'package:xlist/pages/directory/index.dart';
import 'package:xlist/helper/preview_helper.dart';
import 'package:xlist/helper/download_helper.dart';

/// 剪贴板操作类型
enum ClipboardOperation {
  none,
  cut,
  copy,
}

class ObjectHelper {
  /// 存储剪切或复制的文件信息
  static Map<String, dynamic>? _clipboardData;
  static ClipboardOperation _clipboardOperation = ClipboardOperation.none;
  
  /// 对外暴露剪贴板数据
  static Map<String, dynamic>? get clipboardData => _clipboardData;
  
  /// 对外暴露剪贴板操作类型
  static ClipboardOperation get clipboardOperation => _clipboardOperation;

  /// 文件点击事件
  /// [path] 文件路径
  /// [type] 文件类型
  /// [name] 文件名称
  static void click({
    required String path,
    required int type,
    required String name,
    List<ObjectModel>? objects,
  }) {
    // 文件夹
    if (type == FileType.FOLDER) {
      // 使用 homepage controller 进行导航
      final homepageController = Get.find<HomepageController>();
      final newPath = path == '/' ? '/${name}' : '${path}/${name}';
      homepageController.navigateToPath(newPath);
      return;
    }

    // 预览图片
    if (PreviewHelper.isImage(name)) {
      Get.toNamed(Routes.IMAGE_PREVIEW,
          arguments: {'path': path, 'name': name, 'objects': objects});
      return;
    }

    // 预览视频
    if (PreviewHelper.isVideo(name)) {
      Get.toNamed(Routes.VIDEO_PLAYER,
          arguments: {'path': path, 'name': name, 'objects': objects});
      return;
    }

    // 预览音频
    if (PreviewHelper.isAudio(name)) {
      Get.toNamed(Routes.AUDIO_PLAYER,
          arguments: {'path': path, 'name': name, 'objects': objects});
      return;
    }

    // 预览文档
    if (PreviewHelper.isDocument(name)) {
      Get.toNamed(Routes.DOCUMENT, arguments: {'path': path, 'name': name});
      return;
    }

    // 其他文件
    Get.toNamed(Routes.FILE, arguments: {'path': path, 'name': name});
  }

  /// 刷新列表
  /// [source] 来源
  /// [pageTag] 页面标签
  static void refreshObjectList({
    required String source,
    required String pageTag,
    bool refresh = false,
  }) async {
    switch (source) {
      case PageSource.DETAIL:
        await Get.find<DetailController>(tag: pageTag)
            .getObjectList(refresh: refresh);
        Get.until((route) => Get.currentRoute.startsWith(Routes.DETAIL));
        break;
      case PageSource.HOMEPAGE:
        await Get.find<HomepageController>().getObjectList();
        Get.until((route) => Get.currentRoute.startsWith(Routes.HOMEPAGE));
        break;
      case PageSource.DIRECTORY:
        await Get.find<DirectoryController>(tag: pageTag).getDirectoryList();
        Get.until((route) => Get.currentRoute.startsWith(Routes.DIRECTORY));
        break;
      default:
        break;
    }
  }

  /// 复制链接
  /// [path] 文件路径
  /// [object] 文件对象
  static void copyLink(
    String path, {
    required ObjectModel object,
    required UserModel userInfo,
  }) {
    final serverUrl = Get.find<CoreService>().currentServer.value?.url ?? '';
    
    if (object.isDir == true) {
      // 为目录构建完整的URL并编码
      String fullPath = '${path}${object.name}';
      String encodedPath = '';
      fullPath.split('/').forEach((v) {
        if (v.isNotEmpty) encodedPath += '/${Uri.encodeComponent(v)}';
      });
      String fullUrl = '${serverUrl}${encodedPath}';
      Clipboard.setData(ClipboardData(text: fullUrl));
    } else {
      // 为文件使用 getDownloadLink 方法，确保返回完整的URL
      String downloadLink = CommonUtils.getDownloadLink(
        path,
        object: object,
        userInfo: userInfo,
      );
      Clipboard.setData(ClipboardData(text: downloadLink));
    }

    SmartDialog.showToast('toast_copy_success'.tr);
  }

  /// 新建文件夹
  /// [path] 文件路径
  static Future<void> mkdir({
    required String path,
    required String source,
    required String pageTag,
  }) async {
    final data = await showTextInputDialog(
      context: Get.context!,
      title: 'dialog_mkdir_title'.tr,
      message: 'dialog_mkdir_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
      textFields: [DialogTextField(hintText: 'dialog_mkdir_hint'.tr)],
    );
    if (data == null) return;
    if (data.isEmpty) return;

    // 新建文件夹
    try {
      SmartDialog.showLoading();
      final response =
          await ObjectRepository.mkdir(path: '${path}/${data.first}');
      if (response['code'] != HttpStatus.ok) {
        throw response['message'];
      }

      SmartDialog.dismiss();
      SmartDialog.showToast('toast_mkdir_success'.tr);

      // 刷新列表
      refreshObjectList(source: source, pageTag: pageTag);
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
    }
  }

  /// 新建文件
  /// [path] 文件路径
  static Future<void> createFile({
    required String path,
    required String source,
    required String pageTag,
    String password = '',
  }) async {
    final data = await showTextInputDialog(
      context: Get.context!,
      title: 'dialog_newfile_title'.tr,
      message: 'dialog_newfile_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
      textFields: [DialogTextField(hintText: 'dialog_newfile_hint'.tr)],
    );
    if (data == null) return;
    if (data.isEmpty) return;

    // 新建文件夹
    try {
      SmartDialog.showLoading();
      final response = await ObjectRepository.put(
        fileData: [],
        fileName: data.first,
        remotePath: path,
        password: password,
      );
      if (response['code'] != HttpStatus.ok) {
        throw response['message'];
      }

      SmartDialog.dismiss();
      SmartDialog.showToast('toast_newfile_success'.tr);

      // 刷新列表
      refreshObjectList(source: source, pageTag: pageTag, refresh: true);
    } catch (e) {
      SmartDialog.dismiss();
      print(e);
      SmartDialog.showToast(e.toString());
    }
  }

  /// 上传图片 & 视频
  /// [path] 文件路径
  static Future<void> upload({
    required String path,
    required int type,
    required String source,
    required String pageTag,
    String password = '',
  }) async {
    List<XFile>? pickedFiles;
    final ImagePicker picker = ImagePicker(); // 图片选择器

    if (type == FileType.IMAGE) pickedFiles = await picker.pickMultiImage();
    if (type == FileType.VIDEO) {
      // 视频选择器暂时不支持多选，保持单选
      XFile? pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile != null) pickedFiles = [pickedFile];
    }

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      try {
        SmartDialog.showLoading(msg: 'toast_upload_loading'.tr);

        int successCount = 0;
        int failCount = 0;
        List<String> failFiles = [];

        for (var pickedFile in pickedFiles) {
          try {
            // 文件名称（保留原文件名）
            final fileName = pickedFile.name;

            // 上传文件
            final response = await ObjectRepository.put(
              fileData: File(pickedFile.path).readAsBytesSync(),
              fileName: fileName,
              remotePath: path,
              password: password,
            );

            // 错误处理
            if (response['code'] != HttpStatus.ok) {
              throw response['message'];
            }
            successCount++;
          } catch (e) {
            failCount++;
            failFiles.add(pickedFile.name);
            print('上传文件 ${pickedFile.name} 失败: $e');
          }
        }

        SmartDialog.dismiss();
        if (failCount > 0) {
          String failMessage = 'toast_upload_partial_failure'.trParams({
            'success': successCount.toString(),
            'total': pickedFiles.length.toString(),
            'files': failFiles.join(', ')
          });
          SmartDialog.showToast(failMessage);
        } else {
          SmartDialog.showToast('toast_upload_success'.tr);
        }

        // 刷新列表
        refreshObjectList(source: source, pageTag: pageTag, refresh: true);
      } catch (e) {
        SmartDialog.dismiss();
        print(e);
        SmartDialog.showToast(e.toString());
      }
    } else {
      // User canceled the picker
    }
  }

  /// 上传文件
  /// [path] 文件路径
  static Future<void> uploadFile({
    required String path,
    required String source,
    required String pageTag,
    String password = '',
  }) async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      try {
        SmartDialog.showLoading(msg: 'toast_upload_loading'.tr);
        int successCount = 0;
        int failCount = 0;
        List<String> failFiles = [];

        // 上传多个文件
        for (var file in result.files) {
          try {
            final response = await ObjectRepository.put(
              fileData: File(file.path!).readAsBytesSync(),
              fileName: file.name,
              remotePath: path,
              password: password,
            );

            // 错误处理
            if (response['code'] != HttpStatus.ok) {
              throw response['message'];
            }
            successCount++;
          } catch (e) {
            failCount++;
            failFiles.add(file.name);
            print('上传文件 ${file.name} 失败: $e');
          }
        }

        SmartDialog.dismiss();
        if (failCount > 0) {
          String failMessage = 'toast_upload_partial_failure'.trParams({
            'success': successCount.toString(),
            'total': result.files.length.toString(),
            'files': failFiles.join(', ')
          });
          SmartDialog.showToast(failMessage);
        } else {
          SmartDialog.showToast('toast_upload_success'.tr);
        }

        // 刷新列表
        refreshObjectList(source: source, pageTag: pageTag, refresh: true);
      } catch (e) {
        SmartDialog.dismiss();
        print(e);
        SmartDialog.showToast(e.toString());
      }
    } else {
      // User canceled the picker
    }
  }

  /// 显示上下文菜单
  /// [path] 文件路径
  /// [object] 文件对象
  /// [objects] 文件列表
  /// [source] 来源
  /// [pageTag] 页面标签
  static Future<void> showContextMenu({
    required String path,
    required ObjectModel object,
    required List<ObjectModel> objects,
    required String source,
    required String pageTag,
  }) async {
    try {
      final actions = <SheetAction>[];

      // 添加属性选项
      actions.add(SheetAction(
        label: '文件属性',
        key: 'properties',
      ));

      // 添加下载选项
      actions.add(SheetAction(
        label: '下载',
        key: 'download',
      ));

      // 添加复制链接选项
      actions.add(SheetAction(
        label: '复制链接',
        key: 'copyLink',
      ));

      // 添加移动选项
      actions.add(SheetAction(
        label: '移动',
        key: 'move',
      ));

      // 添加复制选项
      actions.add(SheetAction(
        label: '复制',
        key: 'copy',
      ));

      // 添加剪切选项
      actions.add(SheetAction(
        label: '剪切',
        key: 'cut',
      ));

      // 添加删除选项
      actions.add(SheetAction(
        label: '删除',
        key: 'delete',
        isDestructiveAction: true,
      ));

      // 添加重命名选项
      actions.add(SheetAction(
        label: '重命名',
        key: 'rename',
      ));

      // 添加粘贴选项（如果剪贴板有数据）
      if (_clipboardData != null && _clipboardOperation != ClipboardOperation.none) {
        actions.add(SheetAction(
          label: '粘贴',
          key: 'paste',
        ));
      }

      final value = await showModalActionSheet(
        context: Get.context!,
        actions: actions,
        cancelLabel: '取消',
      );

      if (value == null) return;

      switch (value) {
        case 'properties':
          await showFileProperties(object);
          break;
        case 'download':
          // 下载文件 / 文件夹
          if (object.isDir == true) {
            await DownloadHelper.directory(path, object.name!);
          } else {
            await DownloadHelper.file(
              path,
              object.name!,
              object.type!,
              object.size ?? 0,
            );
          }
          break;
        case 'copyLink':
          // 复制链接
          final userInfo = UserModel();
          copyLink(
            path,
            object: object,
            userInfo: userInfo,
          );
          break;
        case 'move':
          // 实现目录选择
          final selectedPath = await _selectDirectory(path);
          if (selectedPath != null && selectedPath != path) {
            await move(
              srcDir: path,
              dstDir: selectedPath,
              name: object.name!,
              source: source,
              pageTag: pageTag,
            );
          }
          break;
        case 'copy':
          // 实现目录选择
          final selectedPath = await _selectDirectory(path);
          if (selectedPath != null && selectedPath != path) {
            await copy(
              srcDir: path,
              dstDir: selectedPath,
              name: object.name!,
              source: source,
              pageTag: pageTag,
            );
          }
          break;
        case 'cut':
          await cut(
            path: path,
            object: object,
          );
          break;
        case 'paste':
          await paste(
            path: path,
            source: source,
            pageTag: pageTag,
          );
          break;
        case 'delete':
          await remove(
            path: path,
            name: object.name!,
            source: source,
            pageTag: pageTag,
          );
          break;
        case 'rename':
          await rename(
            path: path,
            object: object,
            source: source,
            pageTag: pageTag,
          );
          break;
      }
    } catch (e) {
      print('Error showing context menu: $e');
      SmartDialog.showToast('菜单显示失败');
    }
  }

  /// 选择目录
  static Future<String?> _selectDirectory(String currentPath) async {
    final result = await Get.toNamed(
      Routes.DIRECTORY,
      arguments: {
        'path': currentPath,
        'selectMode': true,
      },
    );
    return result;
  }

  /// 显示文件属性
  /// [object] 文件对象
  static Future<void> showFileProperties(ObjectModel object) async {
    final sizeText = object.isDir! ? '文件夹' : CommonUtils.formatFileSize(object.size!);
    final typeText = object.isDir! ? '目录' : '文件';
    final modifiedText = object.modified != null 
        ? Jiffy.parseFromDateTime(object.modified!).format(pattern: 'yyyy/MM/dd HH:mm:ss') 
        : '未知';

    await showAlertDialog(
      context: Get.context!,
      title: '文件属性',
      message: '名称: ${object.name}\n类型: $typeText\n大小: $sizeText\n修改时间: $modifiedText',
      actions: [
        AlertDialogAction(label: '确定', key: 'ok'),
      ],
    );
  }

  /// 剪切文件
  /// [path] 文件路径
  /// [object] 文件对象
  static Future<void> cut({
    required String path,
    required ObjectModel object,
  }) async {
    _clipboardData = {
      'path': path,
      'name': object.name,
      'isDir': object.isDir,
    };
    _clipboardOperation = ClipboardOperation.cut;
    SmartDialog.showToast('剪切功能已准备就绪');
    print('剪切文件: ${object.name} 从路径: $path');
  }

  /// 粘贴文件
  /// [path] 目标路径
  /// [source] 来源
  /// [pageTag] 页面标签
  static Future<void> paste({
    required String path,
    required String source,
    required String pageTag,
  }) async {
    if (_clipboardData == null || _clipboardOperation == ClipboardOperation.none) {
      SmartDialog.showToast('剪贴板为空');
      return;
    }

    try {
      SmartDialog.showLoading();
      final srcPath = _clipboardData!['path'] as String;
      final fileName = _clipboardData!['name'] as String;

      dynamic response;
      if (_clipboardOperation == ClipboardOperation.cut) {
        // 移动操作
        response = await ObjectRepository.move(
          srcDir: srcPath,
          dstDir: path,
          name: fileName,
        );
        if (response != null && response['code'] == 200) {
          SmartDialog.showToast('移动成功');
          _clipboardData = null;
          _clipboardOperation = ClipboardOperation.none;
        } else {
          throw Exception('移动失败');
        }
      } else if (_clipboardOperation == ClipboardOperation.copy) {
        // 复制操作
        response = await ObjectRepository.copy(
          srcDir: srcPath,
          dstDir: path,
          name: fileName,
        );
        if (response != null && response['code'] == 200) {
          SmartDialog.showToast('复制成功');
        } else {
          throw Exception('复制失败');
        }
      }

      // 刷新列表
      refreshObjectList(source: source, pageTag: pageTag);
    } catch (e) {
      SmartDialog.showToast(e.toString());
    } finally {
      SmartDialog.dismiss();
    }
  }

  /// 复制文件
  /// [srcDir] 源目录
  /// [dstDir] 目标目录
  /// [name] 文件名
  /// [source] 来源
  /// [pageTag] 页面标签
  static Future<void> copy({
    required String srcDir,
    required String dstDir,
    required String name,
    required String source,
    required String pageTag,
  }) async {
    try {
      SmartDialog.showLoading();
      final response = await ObjectRepository.copy(
        srcDir: srcDir,
        dstDir: dstDir,
        name: name,
      );
      if (response != null && response['code'] == 200) {
        SmartDialog.showToast('复制成功');
        // 刷新列表
        refreshObjectList(source: source, pageTag: pageTag);
      } else {
        throw Exception('复制失败');
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
    }
  }

  /// 移动文件
  /// [srcDir] 源目录
  /// [dstDir] 目标目录
  /// [name] 文件名
  /// [source] 来源
  /// [pageTag] 页面标签
  static Future<void> move({
    required String srcDir,
    required String dstDir,
    required String name,
    required String source,
    required String pageTag,
  }) async {
    try {
      SmartDialog.showLoading();
      final response = await ObjectRepository.move(
        srcDir: srcDir,
        dstDir: dstDir,
        name: name,
      );
      if (response != null && response['code'] == 200) {
        SmartDialog.showToast('移动成功');
        // 刷新列表
        refreshObjectList(source: source, pageTag: pageTag);
      } else {
        throw Exception('移动失败');
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
    }
  }

  /// 删除文件
  /// [path] 文件路径
  /// [name] 文件名
  /// [source] 来源
  /// [pageTag] 页面标签
  static Future<void> remove({
    required String path,
    required String name,
    required String source,
    required String pageTag,
  }) async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    try {
      SmartDialog.showLoading();
      final response = await ObjectRepository.remove(
        path: path,
        name: name,
      );
      if (response != null && response['code'] == 200) {
        SmartDialog.showToast('删除成功');
        // 刷新列表
        refreshObjectList(source: source, pageTag: pageTag);
      } else {
        throw Exception('删除失败');
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
    }
  }

  /// 重命名文件
  /// [path] 文件路径
  /// [object] 文件对象
  /// [source] 来源
  /// [pageTag] 页面标签
  static Future<void> rename({
    required String path,
    required ObjectModel object,
    required String source,
    required String pageTag,
  }) async {
    final data = await showTextInputDialog(
      context: Get.context!,
      title: 'dialog_rename_title'.tr,
      message: 'dialog_rename_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
      textFields: [
        DialogTextField(
          hintText: 'dialog_rename_hint'.tr,
          initialText: object.name,
        ),
      ],
    );
    if (data == null) return;
    if (data.isEmpty) return;

    try {
      SmartDialog.showLoading();
      final response = await ObjectRepository.rename(
        path: '$path/${object.name}',
        name: data.first,
      );
      if (response != null && response['code'] == 200) {
        SmartDialog.showToast('重命名成功');
        // 刷新列表
        refreshObjectList(source: source, pageTag: pageTag);
      } else {
        throw Exception('重命名失败');
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
    }
  }

  /// 批量下载
  static Future<void> batchDownload(
    List<ObjectModel> objects,
    String path,
  ) async {
    if (objects.isEmpty) return;
    SmartDialog.showLoading();
    try {
      for (final object in objects) {
        await DownloadHelper.file(
          path,
          object.name!,
          object.type!,
          object.size ?? 0,
        );
      }
      SmartDialog.dismiss();
      SmartDialog.showToast('已开始下载 ${objects.length} 个项目');
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
    }
  }

  /// 批量移动 / 复制
  static Future<void> batchMoveOrCopy({
    required List<ObjectModel> objects,
    required String srcDir,
    required bool isCopy,
    required String source,
    required String pageTag,
  }) async {
    if (objects.isEmpty) return;

    // 选择目标目录
    final selectedPath = await _selectDirectory(srcDir);
    if (selectedPath == null || selectedPath == srcDir) return;

    SmartDialog.showLoading();
    try {
      for (final object in objects) {
        if (isCopy) {
          await ObjectRepository.copy(
            srcDir: srcDir,
            dstDir: selectedPath,
            name: object.name!,
          );
        } else {
          await ObjectRepository.move(
            srcDir: srcDir,
            dstDir: selectedPath,
            name: object.name!,
          );
        }
      }
      SmartDialog.dismiss();
      SmartDialog.showToast(isCopy ? '复制成功' : '移动成功');
      refreshObjectList(source: source, pageTag: pageTag);
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
    }
  }

  /// 批量删除
  static Future<void> batchDelete({
    required List<ObjectModel> objects,
    required String path,
    required String source,
    required String pageTag,
  }) async {
    if (objects.isEmpty) return;

    final result = await showOkCancelAlertDialog(
      context: Get.context!,
      title: '删除确认',
      message: '确定要删除选中的 ${objects.length} 个项目吗？此操作不可恢复。',
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
      isDestructiveAction: true,
    );
    if (result != OkCancelResult.ok) return;

    SmartDialog.showLoading();
    try {
      for (final object in objects) {
        await ObjectRepository.remove(path: path, name: object.name!);
      }
      SmartDialog.dismiss();
      SmartDialog.showToast('删除成功');
      refreshObjectList(source: source, pageTag: pageTag);
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
    }
  }

  /// 排序文件列表
  /// 文件夹始终排在文件前面，组内按 [sortType] 排序
  /// [objects] 文件列表
  /// [sortType] 排序类型（SortType）
  static List<ObjectModel> sortObjects(
    List<ObjectModel> objects,
    int sortType,
  ) {
    final sorted = List<ObjectModel>.from(objects);
    sorted.sort((a, b) {
      // 文件夹优先
      final aDir = a.isDir == true;
      final bDir = b.isDir == true;
      if (aDir != bDir) return aDir ? -1 : 1;

      switch (sortType) {
        case SortType.TIME_DESC:
          return (b.modified ?? DateTime(0)).compareTo(a.modified ?? DateTime(0));
        case SortType.TIME_ASC:
          return (a.modified ?? DateTime(0)).compareTo(b.modified ?? DateTime(0));
        case SortType.NAME_DESC:
          return (b.name ?? '').toLowerCase().compareTo((a.name ?? '').toLowerCase());
        case SortType.NAME_ASC:
          return (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
        case SortType.SIZE_DESC:
          return (b.size ?? 0).compareTo(a.size ?? 0);
        case SortType.SIZE_ASC:
          return (a.size ?? 0).compareTo(b.size ?? 0);
        default:
          return 0;
      }
    });
    return sorted;
  }

  /// 显示排序选择菜单
  /// [current] 当前排序类型
  /// 返回用户选择的 SortType，取消返回 null
  static Future<int?> showSortMenu(int current) async {
    final value = await showModalActionSheet(
      context: Get.context!,
      title: '排序方式',
      actions: [
        SheetAction(
          label: '${current == SortType.TIME_DESC ? '✓ ' : ''}时间 · 最新优先',
          key: 'time_desc',
          isDefaultAction: current == SortType.TIME_DESC,
        ),
        SheetAction(
          label: '${current == SortType.TIME_ASC ? '✓ ' : ''}时间 · 最旧优先',
          key: 'time_asc',
          isDefaultAction: current == SortType.TIME_ASC,
        ),
        SheetAction(
          label: '${current == SortType.NAME_ASC ? '✓ ' : ''}名称 · A→Z',
          key: 'name_asc',
          isDefaultAction: current == SortType.NAME_ASC,
        ),
        SheetAction(
          label: '${current == SortType.NAME_DESC ? '✓ ' : ''}名称 · Z→A',
          key: 'name_desc',
          isDefaultAction: current == SortType.NAME_DESC,
        ),
        SheetAction(
          label: '${current == SortType.SIZE_DESC ? '✓ ' : ''}大小 · 从大到小',
          key: 'size_desc',
          isDefaultAction: current == SortType.SIZE_DESC,
        ),
        SheetAction(
          label: '${current == SortType.SIZE_ASC ? '✓ ' : ''}大小 · 从小到大',
          key: 'size_asc',
          isDefaultAction: current == SortType.SIZE_ASC,
        ),
      ],
      cancelLabel: 'cancel'.tr,
    );
    if (value == null) return null;

    switch (value) {
      case 'time_desc':
        return SortType.TIME_DESC;
      case 'time_asc':
        return SortType.TIME_ASC;
      case 'name_asc':
        return SortType.NAME_ASC;
      case 'name_desc':
        return SortType.NAME_DESC;
      case 'size_desc':
        return SortType.SIZE_DESC;
      case 'size_asc':
        return SortType.SIZE_ASC;
      default:
        return null;
    }
  }
}

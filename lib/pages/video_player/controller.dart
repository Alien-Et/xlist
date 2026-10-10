import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:charset/charset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:audio_service/audio_service.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:subtitle_wrapper_package/subtitle_wrapper_package.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:xlist/gen/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/common/utils.dart';
import 'package:xlist/common/logger.dart';
import 'package:xlist/services/core_service.dart';
import 'package:xlist/services/dio_service.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/database/entity/index.dart';
import 'package:xlist/repositorys/index.dart';

class VideoPlayerController extends SuperController with WidgetsBindingObserver {
  final object = ObjectModel().obs;
  final userInfo = UserModel().obs;
  final httpHeaders = Map<String, String>().obs;
  final serverId = 0.obs;
  final isLoading = true.obs;
  final errorMessage = ''.obs; // 播放错误信息
  final isAutoPaused = false.obs;
  final subtitles = <Subtitle>[].obs;
  final subtitleNameList = <String>[].obs;
  final subtitleName = ''.obs;
  final audioTracks = <Map<String, String>>[].obs;
  final timedTextTracks = <Map<String, String>>[].obs;
  final showTimedText = true.obs;
  final currentName = ''.obs;
  final currentIndex = 0.obs;
  final showPlaylist = false.obs;
  final fijkViewKey = GlobalKey();
  final thumbnail = ''.obs;

  // 播放器状态
  final playerInitialized = false.obs;
  late vp.VideoPlayerController videoPlayerController;
  final currentPosition = Duration.zero.obs;
  final totalDuration = Duration.zero.obs;
  final isPlaying = false.obs;
  final isFullScreen = false.obs;

  late bool isAutoPlay;
  late bool isBackgroundPlay;
  late var playMode;

  final String path = Get.arguments['path'] ?? '';
  final String name = Get.arguments['name'] ?? '';
  List<ObjectModel> objects = Get.arguments['objects'] ?? [];

  final String file = Get.arguments['file'] ?? '';
  final int downloadId = Get.arguments['downloadId'] ?? 0;

  late vp.VideoPlayerController player;
  // 暂时注释掉音频服务，避免初始化错误
  // final audioHandler = PlayerNotificationService.to.audioHandler;

  Timer? _timer;
  int _progressId = 0;
  final currentPos = Duration.zero.obs;
  StreamSubscription? _currentPosSubs;
  MediaItem? _mediaItem;
  
  late CoreService coreService;

  @override
  void onInit() async {
    super.onInit();
    coreService = CoreService.to;

    // 获取设置
    isAutoPlay = coreService.preferencesStorage.isAutoPlay.val ?? false;
    isBackgroundPlay = coreService.preferencesStorage.isBackgroundPlay.val ?? false;
    playMode = coreService.preferencesStorage.playMode;

    // 获取服务器信息
    serverId.value = coreService.userStorage.serverId.value;

    // 过滤视频文件；列表为空（单独打开）时用当前文件构造单曲列表
    final videoObjects =
        objects.where((o) => PreviewHelper.isVideo(o.name!)).toList();
    if (videoObjects.isEmpty && objects.isNotEmpty) {
      objects = List<ObjectModel>.from(objects);
    } else {
      objects = videoObjects;
    }
    if (objects.isEmpty) {
      objects = [
        ObjectModel()
          ..name = name
          ..type = 2,
      ];
    }

    // 获取用户信息
    userInfo.value = coreService.currentUser.value ?? UserModel();

    currentName.value = name;
    currentIndex.value = objects.indexWhere((o) => o.name == name);
    if (currentIndex.value < 0) currentIndex.value = 0;
    showPlaylist.value = objects.length > 1;

    // 暂时注释掉音频服务初始化
    // audioHandler.initializeStreamController(player, showPlaylist.value, true);
    // audioHandler.playbackState.addStream(audioHandler.streamController.stream);
    // audioHandler.setVideoFunctions(player.play, player.pause, (position) => player.seekTo(Duration(milliseconds: position)), player.dispose);

    if (file.isEmpty) {
      // 优先复用列表已解析的 rawUrl（避免对单个文件重新 PROPFIND 导致 404）
      ObjectModel? listObject;
      for (final o in objects) {
        if (o.name == name && o.rawUrl != null && o.rawUrl!.isNotEmpty) {
          listObject = o;
          break;
        }
      }
      if (listObject != null) {
        object.value = listObject;
        httpHeaders.value = DriverHelper.getWebDAVHeaders();
      } else {
        try {
          // 获取视频文件信息
          final videoObject = await ObjectRepository.get(path: '${path}${name}');
          videoObject.name = name;
          videoObject.rawUrl = CommonUtils.getDownloadLink(
            path,
            object: videoObject,
            userInfo: userInfo.value,
          );
          // 设置WebDAV认证头
          httpHeaders.value = DriverHelper.getWebDAVHeaders();
          object.value = videoObject;
        } catch (e) {
          Logger.w('ObjectRepository.get failed, fallback to URL build: $e');
          // PROPFIND 失败时按服务器 URL 直接拼接播放地址，不阻断播放
          final fallback = ObjectModel()
            ..name = name
            ..type = 2
            ..rawUrl = CommonUtils.getDownloadLink(
              path,
              object: ObjectModel()..name = name,
              userInfo: userInfo.value,
            );
          httpHeaders.value = DriverHelper.getWebDAVHeaders();
          object.value = fallback;
        }
      }
    } else {
      final download = await coreService.downloadDao
          .findDownloadById(downloadId);
      object.value = ObjectModel.fromJson({
        'name': download?.name,
        'type': download?.type,
        'size': download?.size,
        'raw_url': 'file://${file}',
      });
    }

    updateSubtitleNameList(object.value.related ?? []);
    thumbnail.value = object.value.thumb ?? '';

    if (Get.arguments['serverId'] != null) {
      serverId.value = Get.arguments['serverId'] ?? 0;
    }

    await updateProgress();

    // 检查 rawUrl 是否为空
    if (object.value.rawUrl == null || object.value.rawUrl!.isEmpty) {
      errorMessage.value = '视频地址为空，无法播放';
      SmartDialog.showToast('toast_get_object_fail'.tr);
      isLoading.value = false;
      return;
    }

    // 初始化视频播放器，支持本地文件和网络文件
    await _initPlayer();
    if (errorMessage.value.isNotEmpty) return;

    // 加入最近浏览
    await coreService.addToRecent(object.value);

    // 绑定进度监听
    try {
      if (coreService.downloadService != null) {
        coreService.downloadService.bindBackgroundIsolate((id, status, progress) {});
      }
    } catch (e) {
      print('Error binding background isolate: $e');
    }

    // 添加 WidgetsBindingObserver 来监听屏幕方向变化
    WidgetsBinding.instance.addObserver(this);

    isLoading.value = false;
  }

  /// 初始化播放器（供首次打开与失败重试复用）
  Future<void> _initPlayer() async {
    errorMessage.value = '';
    String videoUrl = object.value.rawUrl!;
    try {
      if (videoUrl.startsWith('file://')) {
        // 本地视频文件
        player = vp.VideoPlayerController.file(
          File(videoUrl.replaceFirst('file://', '')),
        );
      } else {
        // 网络视频文件
        player = vp.VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          httpHeaders: httpHeaders.cast<String, String>(),
        );
      }
      videoPlayerController = player;
      player.addListener(_videoPlayerListener);
      await player.initialize();
      playerInitialized.value = true;
      totalDuration.value = player.value.duration ?? Duration.zero;
      await player.seekTo(currentPos.value);
      if (isAutoPlay) {
        await player.play();
        isPlaying.value = true;
      }
    } catch (e) {
      Logger.e('Video player initialize failed: $e');
      // 预检播放地址，给出具体失败原因（文件不存在/无权限/服务器不支持流式等）
      String? diagnose;
      try {
        diagnose = await _diagnoseVideoUrl(videoUrl);
      } catch (_) {}
      errorMessage.value = '视频初始化失败，请检查网络或文件是否可访问：$e'
          '${diagnose != null ? '\n$diagnose' : ''}';
      SmartDialog.showToast('视频初始化失败，请检查网络或文件是否可访问');
      playerInitialized.value = false;
      isLoading.value = false;
    }
  }

  /// 预检播放地址：GET Range 探测服务器对流式播放的支持情况
  Future<String?> _diagnoseVideoUrl(String url) async {
    if (url.startsWith('file://')) return null;
    try {
      final resp = await DioService.to.dio.get(
        url,
        options: Options(
          headers: {
            ...httpHeaders.value,
            'Range': 'bytes=0-1',
          },
          validateStatus: (status) => status != null && status < 600,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final status = resp.statusCode ?? 0;
      if (status == 404) return '播放地址不存在（404），文件可能已被删除或移动';
      if (status == 401 || status == 403) {
        return '播放地址无访问权限（$status），请检查账号权限';
      }
      final acceptRanges = resp.headers['accept-ranges']?.toString().toLowerCase();
      if (status == 200 && acceptRanges != 'bytes') {
        return '服务器不支持 Range 流式播放（Accept-Ranges: ${acceptRanges ?? '无'}），'
            '在线播放受限，建议先下载再播放';
      }
      return '播放地址响应正常（$status），播放器仍失败：可能是视频编码不支持或服务器流式响应异常';
    } catch (e2) {
      return '播放地址不可访问：$e2';
    }
  }

  /// 播放失败后重试
  Future<void> retry() async {
    isLoading.value = true;
    await _initPlayer();
    if (errorMessage.value.isEmpty) {
      await coreService.addToRecent(object.value);
    }
    isLoading.value = false;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    
    final orientation = MediaQuery.of(Get.context!).orientation;
    if (orientation == Orientation.landscape) {
      // 横屏模式，自动进入全屏
      if (!isFullScreen.value) {
        toggleFullScreen();
      }
    } else if (orientation == Orientation.portrait) {
      // 竖屏模式，自动退出全屏
      if (isFullScreen.value) {
        toggleFullScreen();
      }
    }
  }

  void _videoPlayerListener() async {
    final value = player.value;

    // 播放出错：显示错误信息，不崩溃
    if (value.hasError) {
      errorMessage.value = '播放出错：${value.errorDescription ?? "无法解码或网络中断"}';
      isPlaying.value = false;
    }

    if (_mediaItem != null && _mediaItem!.duration != value.duration) {
      _playerNotificationHandler();
    }

    if (value.isPlaying) WakelockPlus.enable();
    if (!value.isPlaying && value.isInitialized) WakelockPlus.disable();

    if (value.isInitialized && !value.hasError) {
      if (value.duration != null && value.duration!.inMilliseconds > 0) _playerNotificationHandler();
      final _audioTracks = <Map<String, String>>[];
      final _timedTextTracks = <Map<String, String>>[];
      audioTracks.value = _audioTracks;
      timedTextTracks.value = _timedTextTracks;
    }

    if (value.position == value.duration && value.isInitialized) {
      currentPos.value = Duration.zero;

      try {
        if (coreService.progressDao != null) {
          await coreService.progressDao.updateProgress(
            ProgressEntity(
              id: _progressId,
              serverId: serverId.value,
              path: path,
              name: currentName.value,
              currentPos: currentPos.value.inMilliseconds,
            ),
          );
        }
      } catch (e) {
        print('Error updating progress: $e');
      }

      if (playMode.val == PlayMode.LIST_LOOP && showPlaylist.isTrue) {
        await player.seekTo(Duration.zero);
        currentIndex.value == objects.length - 1
            ? changePlaylist(0)
            : changePlaylist(currentIndex.value + 1);
        return;
      }

      if (playMode.val == PlayMode.SINGLE_LOOP && showPlaylist.isTrue) {
        await player.seekTo(Duration.zero);
        await player.play();
        return;
      }
    }

    currentPos.value = value.position;
  }

  void _playerNotificationHandler() {
    _mediaItem = MediaItem(
      id: '${path}${currentName.value}',
      title: CommonUtils.formatFileNme(currentName.value),
      duration: player.value.duration,
      artUri: object.value.thumb != null && object.value.thumb!.isNotEmpty
          ? Uri.parse(object.value.thumb!)
          : Uri.parse('https://s2.loli.net/2023/07/05/viCwFoLceMtAB3m.jpg'),
      artHeaders: httpHeaders.cast<String, String>(),
    );

    // 暂时注释掉音频服务
    // audioHandler.mediaItem.add(_mediaItem);
  }

  void changePlaylist(int index) async {
    final _object = objects[index];
    if (_object.name == currentName.value) {
      SmartDialog.showToast('toast_current_play_file'.tr);
      return;
    }

    SmartDialog.showLoading();
    try {
      // 获取视频文件信息
      final videoObject = await ObjectRepository.get(path: '${path}${_object.name}');
      videoObject.name = _object.name;
      videoObject.rawUrl = CommonUtils.getDownloadLink(
        path,
        object: videoObject,
        userInfo: userInfo.value,
      );
      // 设置WebDAV认证头
      httpHeaders.value = DriverHelper.getWebDAVHeaders();
      object.value = videoObject;
    } catch (e) {
      print('Error getting video object: $e');
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
      return;
    }

    currentIndex.value = index;
    currentName.value = _object.name!;
    isAutoPaused.value = false;
    subtitles.clear();
    audioTracks.clear();
    timedTextTracks.clear();

    updateSubtitleNameList(object.value.related ?? []);

    SmartDialog.dismiss();
    try {
      await player.dispose();
    } catch (_) {}
    player = vp.VideoPlayerController.networkUrl(
      Uri.parse(object.value.rawUrl!),
      httpHeaders: httpHeaders.cast<String, String>(),
    );
    player.addListener(_videoPlayerListener);
    try {
      await player.initialize();
    } catch (e) {
      errorMessage.value = '视频初始化失败：$e';
      SmartDialog.showToast('视频初始化失败，请检查网络或文件是否可访问');
      return;
    }
    currentPos.value = Duration.zero;
    await updateProgress();

    await player.seekTo(currentPos.value);
    await player.play();

    // 加入最近浏览
    await coreService.addToRecent(object.value);
    SmartDialog.showToast('toast_switch_success'.tr);
  }

  void changeAudioTrack({String? value}) async {
    SmartDialog.showToast('video_switch_audio_not_supported'.tr);
    return;
  }

  void updateSubtitleNameList(List<ObjectModel> related) {
    subtitleNameList.clear();
    related.forEach((v) {
      final ext = p.extension(v.name!).toLowerCase();
      if (ext == '.vtt' || ext == '.srt' || ext == '.ass') {
        subtitleNameList.add(v.name!);
      }
    });
  }

  void changeSubtitle({String? value}) async {
    SmartDialog.showToast('video_switch_subtitle_not_supported'.tr);
    return;
  }

  Future<void> updateProgress() async {
    try {
      if (coreService.progressDao != null) {
        final progress = await coreService.progressDao
            .findProgressByServerIdAndPath(serverId.value, path, currentName.value);

        if (progress != null) {
          _progressId = progress.id!;
          currentPos.value = Duration(milliseconds: progress.currentPos);
        } else {
          _progressId =
              await coreService.progressDao.insertProgress(
            ProgressEntity(
              serverId: serverId.value,
              path: path,
              name: currentName.value,
              currentPos: 0,
            ),
          );
        }

        _timer?.cancel();
        _timer = Timer.periodic(Duration(seconds: 5), (timer) async {
          try {
            if (coreService.progressDao != null) {
              await coreService.progressDao.updateProgress(
                ProgressEntity(
                  id: _progressId,
                  serverId: serverId.value,
                  path: path,
                  name: currentName.value,
                  currentPos: currentPos.value.inMilliseconds,
                ),
              );
            }
          } catch (e) {
            print('Error updating progress in timer: $e');
          }
        });
      }
    } catch (e) {
      print('Error updating progress: $e');
    }
  }

  void favorite() async {
    await coreService.addToFavorites(object.value);
  }

  void copyLink() {
    Clipboard.setData(ClipboardData(
      text: CommonUtils.getDownloadLink(
        path,
        object: object.value,
        userInfo: userInfo.value,
      ),
    ));
    SmartDialog.showToast('toast_copy_success'.tr);
  }

  void download() async {
    await coreService.downloadObject(object.value);
  }

  // 播放器控制方法
  void seekTo(Duration position) async {
    await player.seekTo(position);
  }

  void seekBackward() async {
    final newPosition = currentPos.value - Duration(seconds: 10);
    await player.seekTo(newPosition.isNegative ? Duration.zero : newPosition);
  }

  void togglePlayPause() async {
    if (player.value.isPlaying) {
      await player.pause();
      isPlaying.value = false;
    } else {
      await player.play();
      isPlaying.value = true;
    }
  }

  void seekForward() async {
    final newPosition = currentPos.value + Duration(seconds: 10);
    final maxPosition = player.value.duration ?? Duration.zero;
    await player.seekTo(newPosition > maxPosition ? maxPosition : newPosition);
  }

  /// 显示播放列表
  void togglePlaylist() async {
    final value = await showModalActionSheet(
      context: Get.context!,
      title: '播放列表',
      actions: [
        for (var i = 0; i < objects.length; i++)
          SheetAction(
            label: CommonUtils.formatFileNme(objects[i].name ?? ''),
            key: i,
            isDefaultAction: i == currentIndex.value,
          ),
      ],
      cancelLabel: 'cancel'.tr,
    );
    if (value != null && value is int && value != currentIndex.value) {
      changePlaylist(value);
    }
  }

  void toggleFullScreen() async {    isFullScreen.value = !isFullScreen.value;
    if (isFullScreen.value) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  void onPaused() {
    if (player.value.isPlaying && !isBackgroundPlay) {
      isAutoPaused.value = true;
      player.pause();
    }
  }

  @override
  void onResumed() {
    // 判断大小超过 30g 的大文件
    final isLargeFile = object.value.size! > 30 * 1024 * 1024 * 1024;

    // if player is started and auto paused
    if (player.value.isPlaying && isLargeFile) {
      isAutoPaused.value = true;
      player.pause();
    }

    // fix player seekTo bug
    Future.delayed(Duration(milliseconds: 500), () async {
      if (isLargeFile) await player.seekTo(currentPos.value);

      if (!player.value.isPlaying && isAutoPaused.isTrue) {
        isAutoPaused.value = false;
        player.play();
      }
    });
  }

  @override
  void onInactive() {}

  @override
  void onDetached() {}

  @override
  void onHidden() {}

  @override
  void onClose() {
    super.onClose();

    _timer?.cancel();
    _currentPosSubs?.cancel();
    // 移除 WidgetsBindingObserver
    WidgetsBinding.instance.removeObserver(this);
    // 播放器释放（容错：初始化失败时 player 可能未创建）
    try {
      player.removeListener(_videoPlayerListener);
      player.dispose();
    } catch (_) {}

    try {
      if (coreService.downloadService != null) {
        coreService.downloadService.unbindBackgroundIsolate();
      }
    } catch (e) {
      print('Error unbinding background isolate: $e');
    }
    WakelockPlus.disable();
  }
}

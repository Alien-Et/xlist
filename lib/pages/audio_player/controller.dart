import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:audio_service/audio_service.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/common/logger.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/repositorys/user_repository.dart';
import 'package:xlist/database/entity/index.dart';

class AudioPlayerController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final isPlaylist = false.obs; // 是否显示为播放列表
  final object = ObjectModel().obs; // 文件信息
  final isLoading = true.obs; // 是否正在加载
  final playMode = 0.obs; // 播放模式
  final httpHeaders = Map<String, String>().obs;
  final serverId = Get.find<UserStorage>().serverId.value.obs;
  final userInfo = UserModel().obs; // 用户信息
  final errorMessage = ''.obs; // 播放错误信息

  // 获取参数
  String path = Get.arguments['path'] ?? '';
  String name = Get.arguments['name'] ?? '';
  List<ObjectModel> objects = Get.arguments['objects'] ?? [];

  // 下载页面点击
  final String file = Get.arguments['file'] ?? '';
  final int downloadId = Get.arguments['downloadId'] ?? 0;

  // 当前播放音频
  final currentName = ''.obs;
  final currentIndex = 0.obs;
  late VideoPlayerController player; // 替换 FijkPlayer

  /// 通知栏音频处理器（容错获取：PlayerNotificationService 未初始化时为 null，
  /// 仅降级通知栏功能，不影响正常播放）
  PlayerNotificationHandler? get audioHandler {
    try {
      if (Get.isRegistered<PlayerNotificationService>()) {
        return PlayerNotificationService.to.audioHandler;
      }
    } catch (_) {}
    return null;
  }

  late TabController tabController;

  double seekPos = -1.0.obs;
  final isPlaying = false.obs;
  final duration = Duration().obs;
  final currentPos = Duration().obs;
  final bufferPos = Duration.zero.obs; // video_player 没有直接的 bufferPos

  Timer? _timer;
  Timer? _timerProgress;
  int _progressId = 0; // 进度表 ID
  final timerDuration = Duration.zero.obs;
  StreamSubscription? _currentPosSubs; // 这个可能不需要了
  StreamSubscription? _bufferPosSubs; // 这个可能不需要了
  StreamSubscription? _bufferingSubs; // 这个可能不需要了
  MediaItem? _mediaItem;

  @override
  void onInit() async {
    super.onInit();

    // TabController
    tabController = TabController(vsync: this, length: 2, initialIndex: 0);
    tabController.addListener(() {
      isPlaylist.value = tabController.index == 1;
    });

    // 过滤非音频；若列表为空（从文件详情单独进入），用当前文件构造单曲列表
    final audioObjects =
        objects.where((o) => PreviewHelper.isAudio(o.name!)).toList();
    if (audioObjects.isEmpty && objects.isNotEmpty) {
      // 自定义扩展名未识别为音频时保留原列表，避免播放列表为空
      objects = List<ObjectModel>.from(objects);
    } else {
      objects = audioObjects;
    }
    if (objects.isEmpty) {
      objects = [
        ObjectModel()
          ..name = name
          ..type = 2,
      ];
    }
    userInfo.value = UserModel();

    // 当前播放文件名
    currentName.value = name;
    currentIndex.value = objects.indexWhere((o) => o.name == name);
    if (currentIndex.value < 0) currentIndex.value = 0;

    // PlayerNotificationService（容错：通知栏不可用时不影响播放）
    try {
      final handler = audioHandler;
      if (handler != null) {
        handler.initializeStreamController(player, objects.length > 1, false);
        handler.playbackState.addStream(handler.streamController.stream);
        handler.setVideoFunctions(player.play, player.pause,
            (position) => player.seekTo(Duration(milliseconds: position)), player.dispose);
      }
    } catch (e) {
      Logger.w('audio handler init failed: $e');
    }

    // 获取文件信息
    if (file.isEmpty) {
      try {
        object.value = await ObjectRepository.get(path: '${path}${name}');
        httpHeaders.value = DriverHelper.getWebDAVHeaders();
      } catch (e) {
        SmartDialog.showToast(e.toString());
        return;
      }
    } else {
      final download = await DatabaseService.to.database.downloadDao
          .findDownloadById(downloadId);
      object.value = ObjectModel.fromJson({
        'name': download?.name,
        'type': download?.type,
        'size': download?.size,
        'raw_url': 'file://${file}',
      });
    }

    // 更新播放进度
    await updateProgress();

    // 初始化播放器
    await _initPlayer();
    if (errorMessage.value.isNotEmpty) return;

    // 加入最近浏览
    await CommonUtils.addRecent(object.value, path, name);

    // 绑定进度监听
    DownloadService.to.bindBackgroundIsolate((id, status, progress) {});
    isLoading.value = false;
  }

  void _videoPlayerListener() async { // 替换 _fijkValueListener
    final value = player.value;
    isPlaying.value = value.isPlaying;

    // 播放出错：显示错误信息，不崩溃
    if (value.hasError) {
      errorMessage.value = '播放出错：${value.errorDescription ?? "无法解码或网络中断"}';
      isPlaying.value = false;
    }

    // 获取视频的总长度
    if (value.duration != duration.value) {
      duration.value = value.duration ?? Duration.zero;
    }

    // Android 有些情况下会拿不到播放时间, 特殊处理一下
    if (_mediaItem != null && _mediaItem!.duration != value.duration) {
      _playerNotificationHandler();
    }

    // 播放预加载完成
    if (value.isInitialized && !value.hasError) { // 替换 FijkState.prepared
      if (value.duration != null && value.duration!.inMilliseconds > 0) _playerNotificationHandler();
    }

    // 播放完成
    if (value.position == value.duration && value.isInitialized) { // 替换 FijkState.completed
      currentPos.value = Duration.zero;

      // 更新播放进度 - 重置
      await DatabaseService.to.database.progressDao.updateProgress(
        ProgressEntity(
          id: _progressId,
          serverId: serverId.value,
          path: path,
          name: currentName.value,
          currentPos: currentPos.value.inMilliseconds,
        ),
      );

      // 根据播放模式切换下一首
      switch (playMode.value) {
        case PlayMode.SINGLE_LOOP:
          await player.seekTo(Duration.zero);
          await player.play();
          break;
        case PlayMode.LIST_LOOP:
          if (objects.length == 1) {
            await player.seekTo(Duration.zero);
            await player.play();
          } else {
            currentIndex.value == objects.length - 1
                ? changePlaylist(0)
                : changePlaylist(currentIndex.value + 1);
          }
          break;
        case PlayMode.SHUFFLE:
          if (objects.length == 1) {
            await player.seekTo(Duration.zero);
            await player.play();
          } else {
            changePlaylist(CommonUtils.randomInt(0, objects.length - 1));
          }
          break;
        default:
          break;
      }
    }

    // 更新当前播放进度
    currentPos.value = value.position;
    bufferPos.value = value.buffered.isNotEmpty ? value.buffered.last.end : Duration.zero;
  }

  /// 通知栏控制器
  void _playerNotificationHandler() {
    _mediaItem = MediaItem(
      id: '${path}${currentName.value}',
      title: CommonUtils.formatFileNme(currentName.value),
      duration: player.value.duration,
      artUri: object.value.thumb != null && object.value.thumb!.isNotEmpty
          ? Uri.parse(object.value.thumb!)
          : Uri.parse('https://s2.loli.net/2023/07/05/viCwFoLceMtAB3m.jpg'),
      artHeaders: httpHeaders,
    );

    // Add media（容错：通知栏不可用时跳过）
    try {
      audioHandler?.mediaItem.add(_mediaItem);
    } catch (_) {}
  }

  /// 初始化播放器（供首次打开与失败重试复用）
  Future<void> _initPlayer() async {
    errorMessage.value = '';
    player = VideoPlayerController.networkUrl(
      Uri.parse(object.value.rawUrl ?? ''),
      httpHeaders: httpHeaders.cast<String, String>(),
    );
    // 先挂监听再初始化，避免错过播放状态
    player.addListener(_videoPlayerListener); // 替换 _fijkValueListener
    try {
      await player.initialize();
    } catch (e) {
      Logger.e('Audio player initialize failed: $e');
      errorMessage.value = '播放初始化失败，请检查文件是否可访问：$e';
      SmartDialog.showToast('播放初始化失败，请检查文件是否可访问');
      isLoading.value = false;
      return;
    }
    await player.seekTo(currentPos.value);
    await player.setVolume(1.0); // 默认音量
    await player.play(); // 替换 autoPlay: true
  }

  /// 播放失败后重试
  Future<void> retry() async {
    isLoading.value = true;
    await updateProgress();
    await _initPlayer();
    if (errorMessage.value.isEmpty) {
      await CommonUtils.addRecent(object.value, path, name);
    }
    isLoading.value = false;
  }

  /// 切换播放列表文件
  /// [index] 下标
  void changePlaylist(int index) async {
    final _object = objects[index];
    if (index == currentIndex.value) {
      SmartDialog.showToast('toast_current_play_file'.tr);
      return;
    }

    // 获取文件信息
    SmartDialog.showLoading();
    try {
      object.value = await ObjectRepository.get(path: '${path}${_object.name}');
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
      return;
    }

    currentIndex.value = index;
    currentName.value = _object.name!;

    // 重置播放器信息
    SmartDialog.dismiss();
    try {
      await player.dispose(); // 替换 player.reset()
    } catch (_) {}
    player = VideoPlayerController.networkUrl(
      Uri.parse(object.value.rawUrl ?? ''),
      httpHeaders: httpHeaders.cast<String, String>(),
    );
    player.addListener(_videoPlayerListener);
    try {
      await player.initialize();
    } catch (e) {
      errorMessage.value = '播放初始化失败，请检查文件是否可访问：$e';
      SmartDialog.showToast('播放初始化失败，请检查文件是否可访问');
      isLoading.value = false;
      return;
    }
    currentPos.value = Duration.zero;
    await updateProgress(); // 更新播放进度

    // 初始化播放器
    // await FijkHelper.setFijkOption(player, isAudioOnly: true, headers: httpHeaders); // 移除
    // await player.setOption(FijkOption.playerCategory, 'seek-at-start', // 移除
    //     currentPos.value.inMilliseconds);
    await player.seekTo(currentPos.value);
    await player.play();

    // 加入最近浏览
    await CommonUtils.addRecent(object.value, path, _object.name!);
  }

  /// 定时关闭
  void timedShutdown() async {
    final _hasTimer = timerDuration.value.inSeconds > 0;
    final value = await showModalActionSheet(
      context: Get.overlayContext!,
      title:
          '定时关闭${_hasTimer ? '(剩余${timerDuration.value.inMinutes + 1}分钟)' : ''}',
      actions: [
        SheetAction(label: '5分钟', key: 5),
        SheetAction(label: '10分钟', key: 10),
        SheetAction(label: '15分钟', key: 15),
        SheetAction(label: '30分钟', key: 30),
        SheetAction(label: '60分钟', key: 60),
        ...[
          if (_hasTimer)
            SheetAction(label: '关闭定时', key: 0, isDestructiveAction: true)
        ].whereType<SheetAction>().toList(),
      ],
      cancelLabel: 'cancel'.tr,
    );
    if (value == null) return;

    // 关闭定时
    if (value == 0) {
      _timer?.cancel();
      timerDuration.value = Duration.zero;
      SmartDialog.showToast('关闭定时');
      return;
    }

    _timer?.cancel();
    timerDuration.value = Duration(minutes: value);
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      timerDuration.value = timerDuration.value - Duration(seconds: 1);
      if (timerDuration.value.inSeconds == 0) {
        _timer?.cancel();
        Get.find<AudioPlayerController>().player.pause();
      }
    });

    SmartDialog.showToast('${value}分钟后关闭');
  }

  /// 切换播放速度
  void changeSpeed() async {
    final value = await showModalActionSheet(
      context: Get.overlayContext!,
      title: 'play_speed'.tr,
      materialConfiguration: MaterialModalActionSheetConfiguration(),
      actions: [
        SheetAction(label: '2.0X', key: 2.0),
        SheetAction(label: '1.8X', key: 1.8),
        SheetAction(label: '1.5X', key: 1.5),
        SheetAction(label: '1.2X', key: 1.2),
        SheetAction(label: '1.0X', key: 1.0),
        SheetAction(label: '0.5X', key: 0.5),
        SheetAction(label: '恢复默认', key: 1.0),
      ],
      cancelLabel: 'cancel'.tr,
    );
    if (value == null) return;
    player.setPlaybackSpeed(value); // 替换 setSpeed
    SmartDialog.showToast('toast_switch_success'.tr);
  }

  /// 更新本地播放进度
  Future<void> updateProgress() async {
    final progress = await DatabaseService.to.database.progressDao
        .findProgressByServerIdAndPath(serverId.value, path, currentName.value);

    if (progress != null) {
      _progressId = progress.id!;
      currentPos.value = Duration(milliseconds: progress.currentPos);
    } else {
      _progressId =
          await DatabaseService.to.database.progressDao.insertProgress(
        ProgressEntity(
          serverId: serverId.value,
          path: path,
          name: currentName.value,
          currentPos: 0,
        ),
      );
    }

    // 每五秒记录一下播放进度
    _timerProgress?.cancel();
    _timerProgress = Timer.periodic(Duration(seconds: 5), (timer) async {
      await DatabaseService.to.database.progressDao.updateProgress(
        ProgressEntity(
          id: _progressId,
          serverId: serverId.value,
          path: path,
          name: currentName.value,
          currentPos: currentPos.value.inMilliseconds,
        ),
      );
    });
  }

  /// 收藏
  void favorite() async {
    await CommonUtils.addFavorite(object.value, path, currentName.value);
  }

  /// 复制链接
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

  /// 下载文件
  void download() async {
    DownloadHelper.file(
        path, currentName.value, object.value.type!, object.value.size!);
  }

  @override
  void onClose() {
    super.onClose();

    _timer?.cancel();
    _timerProgress?.cancel();
    _currentPosSubs?.cancel(); // 这个可以移除
    _bufferPosSubs?.cancel(); // 这个可以移除
    _bufferingSubs?.cancel(); // 这个可以移除
    // 通知栏流关闭（容错）
    try {
      final handler = audioHandler;
      if (handler != null) {
        handler.streamController.add(PlaybackState());
        handler.streamController.close();
      }
    } catch (_) {}
    // 播放器释放（容错：初始化失败时 player 未完成创建）
    try {
      player.removeListener(_videoPlayerListener); // 替换 _fijkValueListener
      player.dispose(); // 替换 player.release()
    } catch (_) {}

    DownloadService.to.unbindBackgroundIsolate();
  }
}

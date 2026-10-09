import 'package:xlist/constants/index.dart';
import 'package:get_storage/get_storage.dart';

class PreferencesStorage {
  static final _prefBox = () => GetStorage('PreferencesStorage');

  Future<PreferencesStorage> init() async {
    await GetStorage.init('PreferencesStorage');
    return this;
  }

  final isFirstOpen = true.val('isFirstOpen', getBox: _prefBox);

  final isAutoPlay = true.val('isAutoPlay', getBox: _prefBox);

  final isBackgroundPlay = true.val('isBackgroundPlay', getBox: _prefBox);

  final isHardwareDecode = true.val('isHardwareDecode', getBox: _prefBox);

  final isShowPreview = true.val('isShowPreview', getBox: _prefBox);

  /// 是否忽略 WebDAV 服务器 SSL 证书校验（自签/内网证书场景默认为 true）
  final ignoreSslVerify = true.val('ignoreSslVerify', getBox: _prefBox);

  final imageSupportTypes =
      kSupportPreviewImageTypes.val('imageSupportTypes', getBox: _prefBox);

  final videoSupportTypes =
      kSupportPreviewVideoTypes.val('videoSupportTypes', getBox: _prefBox);

  final audioSupportTypes =
      kSupportPreviewAudioTypes.val('audioSupportTypes', getBox: _prefBox);

  final documentSupportTypes = kSupportPreviewDocumentTypes
      .val('documentSupportTypes', getBox: _prefBox);

  final sortType = 0.val('sortType', getBox: _prefBox);

  final layoutType = 1.val('layoutType', getBox: _prefBox);

  final playMode = 0.val('playMode', getBox: _prefBox);

  final id = ''.val('id', getBox: _prefBox);

  final token = ''.val('token', getBox: _prefBox);

  final serverId = 0.val('serverId', getBox: _prefBox);

  final serverUrl = ''.val('serverUrl', getBox: _prefBox);

  final username = ''.val('username', getBox: _prefBox);

  final password = ''.val('password', getBox: _prefBox);
}

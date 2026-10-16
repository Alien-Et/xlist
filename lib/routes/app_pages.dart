import 'package:get/get.dart';

import 'package:xlist/pages/file/index.dart';
import 'package:xlist/pages/detail/index.dart';
import 'package:xlist/pages/search/index.dart';
import 'package:xlist/pages/setting/index.dart';
import 'package:xlist/pages/notfound/index.dart';
import 'package:xlist/pages/homepage/index.dart';
import 'package:xlist/pages/document/index.dart';
import 'package:xlist/pages/directory/index.dart';
import 'package:xlist/pages/video_player/index.dart';
import 'package:xlist/pages/audio_player/index.dart';
import 'package:xlist/pages/image_preview/index.dart';
import 'package:xlist/pages/setting/recent/index.dart';
import 'package:xlist/pages/setting/server/index.dart';
import 'package:xlist/pages/setting/preview/index.dart';
import 'package:xlist/pages/setting/favorite/index.dart';
import 'package:xlist/pages/setting/download/index.dart';
import 'package:xlist/pages/image_gallery/image_gallery_page.dart';
import 'package:xlist/pages/image_gallery/image_gallery_binding.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = _Paths.HOMEPAGE;

  static final routes = [
    GetPage(
      name: _Paths.HOMEPAGE,
      page: () => Homepage(),
      binding: HomepageBinding(),
      transitionDuration: Duration.zero,
    ),
    GetPage(
      name: Routes.IMAGE_GALLERY,
      page: () => ImageGalleryPage(),
      binding: ImageGalleryBinding(),
    ),
    GetPage(
      name: _Paths.DETAIL,
      page: () => DetailPage(),
      binding: DetailBinding(),
    ),
    GetPage(
      name: _Paths.SEARCH,
      page: () => SearchPage(),
      binding: SearchBinding(),
    ),
    GetPage(
      name: _Paths.DIRECTORY,
      page: () => DirectoryPage(),
      binding: DirectoryBinding(),
    ),
    GetPage(
      name: _Paths.DOCUMENT,
      page: () => DocumentPage(),
      binding: DocumentBinding(),
    ),
    GetPage(
      name: _Paths.FILE,
      page: () => FilePage(),
      binding: FileBinding(),
    ),
    GetPage(
      name: _Paths.IMAGE_PREVIEW,
      page: () => ImagePreviewPage(),
      binding: ImagePreviewBinding(),
      opaque: false,
      showCupertinoParallax: false,
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: _Paths.VIDEO_PLAYER,
      page: () => VideoPlayerPage(),
      binding: VideoPlayerBinding(),
    ),
    GetPage(
      name: _Paths.AUDIO_PLAYER,
      page: () => AudioPlayerPage(),
      binding: AudioPlayerBinding(),
      showCupertinoParallax: false,
      transition: Transition.downToUp,
    ),
    GetPage(
      name: _Paths.SETTING,
      page: () => SettingPage(),
      binding: SettingBinding(),
      children: [
        GetPage(
          name: '/server',
          page: () => ServerPage(),
          binding: ServerBinding(),
        ),
        GetPage(
          name: '/download',
          page: () => DownloadPage(),
          binding: DownloadBinding(),
        ),
        GetPage(
          name: '/recent',
          page: () => RecentPage(),
          binding: RecentBinding(),
        ),
        GetPage(
          name: '/favorite',
          page: () => FavoritePage(),
          binding: FavoriteBinding(),
        ),
        GetPage(
          name: '/preview/image',
          page: () => SettingImagePage(),
          binding: SettingImageBinding(),
        ),
        GetPage(
          name: '/preview/audio',
          page: () => SettingAudioPage(),
          binding: SettingAudioBinding(),
        ),
        GetPage(
          name: '/preview/video',
          page: () => SettingVideoPage(),
          binding: SettingVideoBinding(),
        ),
        GetPage(
          name: '/preview/document',
          page: () => SettingDocumentPage(),
          binding: SettingDocumentBinding(),
        ),
      ],
    ),
  ];

  static final unknownRoute = GetPage(
    name: _Paths.NOTFOUND,
    page: () => NotfoundPage(),
  );
}

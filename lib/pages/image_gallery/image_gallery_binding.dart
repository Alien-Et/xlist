import 'package:get/get.dart';
import 'package:xlist/pages/image_gallery/image_gallery_page.dart';

class ImageGalleryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ImageGalleryPage>(() => ImageGalleryPage());
  }
}

import 'package:get/get.dart';
import 'package:xlist/pages/homepage/controller.dart';

class HomepageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomepageController>(() => HomepageController());
  }
}

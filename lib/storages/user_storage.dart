import 'package:get/get.dart';
import 'package:xlist/storages/preferences_storage.dart';

class UserStorage extends GetxService {
  final id = ''.obs;
  final token = ''.obs;
  final serverId = 0.obs;
  final serverUrl = ''.obs;
  final username = ''.obs;
  final password = ''.obs;

  @override
  void onInit() {
    super.onInit();
    id.value = Get.find<PreferencesStorage>().id.val ?? '';
    token.value = Get.find<PreferencesStorage>().token.val ?? '';
    serverId.value = Get.find<PreferencesStorage>().serverId.val ?? 0;
    serverUrl.value = Get.find<PreferencesStorage>().serverUrl.val ?? '';
    username.value = Get.find<PreferencesStorage>().username.val;
    password.value = Get.find<PreferencesStorage>().password.val;
  }

  @override
  void onClose() {
    id.close();
    token.close();
    serverId.close();
    serverUrl.close();
    username.close();
    password.close();
    super.onClose();
  }
}

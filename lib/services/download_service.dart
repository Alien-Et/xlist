import 'dart:ui';
import 'dart:isolate';

import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
const port = 'downloader_port';

typedef DownloadIsolateCallback = void Function(
  String id,
  int status,
  int progress,
);

class DownloadService extends GetxService {
  static DownloadService get to => Get.find();

  Future<DownloadService> init() async {
    return this;
  }

  bindBackgroundIsolate(DownloadIsolateCallback callback) {
    ReceivePort _port = ReceivePort();
    bool isSuccess =
        IsolateNameServer.registerPortWithName(_port.sendPort, port);

    if (!isSuccess) {
      unbindBackgroundIsolate();
      bindBackgroundIsolate(callback);
      return;
    }
    _port.listen((dynamic data) {
      callback(data[0], data[1], data[2]);
    });
  }

  unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping(port);
  }
}

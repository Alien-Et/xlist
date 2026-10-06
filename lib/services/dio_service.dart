import 'dart:io';

import 'package:dio/io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:get/get.dart' show Get, GetxService;
import 'package:get/get_instance/src/extension_instance.dart';

import 'package:xlist/helper/index.dart';
import 'package:xlist/storages/index.dart';

// Dio
class DioService extends GetxService {
  static DioService get to => Get.find();

  // Dio
  Dio _dio = Dio();
  Dio get dio => _dio;
  Map<String, String> defaultHeaders = {}; // 默认请求头
  
  // 设置baseUrl
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  // 连接超时时间
  static const Duration CONNECT_TIMEOUT = Duration(seconds: 10);

  // 响应超时时间 5 min
  static const Duration RECEIVE_TIMEOUT = Duration(seconds: 300);

  // Init
  Future<DioService> init() async {
    // 设置一些默认信息
    _dio.options
      ..connectTimeout = CONNECT_TIMEOUT
      ..receiveTimeout = RECEIVE_TIMEOUT;

    // Certificate
    (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
        (HttpClient dioClient) {
      final SecurityContext sc = SecurityContext();
      sc.allowLegacyUnsafeRenegotiation = true;

      // HttpClient
      HttpClient httpClient = HttpClient(context: sc);
      // 仅调试模式放宽证书校验，Release 模式使用系统严格校验，防止中间人攻击
      if (kDebugMode) {
        httpClient.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      }

      return httpClient;
    };

    // Interceptor
    _dio.interceptors.add(DioInterceptors());
    defaultHeaders = DriverHelper.getHeaders(null, null);
    return this;
  }
}

class DioInterceptors extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      // 只在没有设置Authorization头的情况下添加token
      if (!options.headers.containsKey(HttpHeaders.authorizationHeader)) {
        final token = Get.find<UserStorage>().token.value;
        if (token.isNotEmpty) {
          options.headers.addAll(
            Map.from(DioService.to.defaultHeaders)
              ..addAll({HttpHeaders.authorizationHeader: token}),
          );
        }
      }
      // 如果已经有Authorization头，保持不变（比如WebDAV的Basic认证）
    } catch (e) {
      print('Error adding headers: $e');
    }
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 只处理 JSON 响应，不处理 WebDAV 的 XML 响应
    if (response.data == null) {
      response.data = {'message': '您的网络不太好, 请刷新页面重试吧', 'code': -1};
    }

    // Next
    handler.next(response);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    return super.onError(err, handler);
  }
}

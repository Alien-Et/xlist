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
      // 放宽证书校验：调试模式、或用户在设置中开启"忽略 SSL 证书校验"
      // （自签证书/内网服务器常见，如群晖、路由、内网穿透）
      final ignoreSsl = Get.find<PreferencesStorage>().ignoreSslVerify.val;
      if (kDebugMode || ignoreSsl) {
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
    } catch (_) {
      // 忽略：读取 token 失败时按未登录处理
    }
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 注意：不在此处改写响应数据。
    // WebDAV 的 DELETE/MOVE/COPY/MKCOL 等返回 204 时 data 为 null，
    // 调用方均基于 statusCode 判断结果；改写 null 会误导下游逻辑。
    handler.next(response);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    return super.onError(err, handler);
  }
}

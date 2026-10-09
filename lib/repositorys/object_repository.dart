import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide MultipartFile;
import 'package:xml/xml.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/pages/homepage/index.dart';

class ObjectRepository extends Repository {
  ObjectRepository();

  static String _buildWebDAVUrl(String path) {
    final currentServer = Get.find<CoreService>().currentServer.value;
    final url = currentServer?.url ?? '';
    if (url.isEmpty) {
      throw Exception('Server URL is empty');
    }

    String webDavUrl = url;
    if (!webDavUrl.startsWith('http://') && !webDavUrl.startsWith('https://')) {
      webDavUrl = 'http://$webDavUrl';
    }
    if (!webDavUrl.endsWith('/')) {
      webDavUrl += '/';
    }
    if (path != '/' && path.isNotEmpty) {
      String cleanPath = path.startsWith('/') ? path.substring(1) : path;
      cleanPath = cleanPath.endsWith('/') ? cleanPath.substring(0, cleanPath.length - 1) : cleanPath;
      // 逐段 URL 编码（中文/空格目录名；已编码段先解码再编码，避免双重编码）
      final segments = cleanPath.split('/').map((seg) {
        try {
          final decoded = Uri.decodeComponent(seg);
          return Uri.encodeComponent(decoded);
        } catch (_) {
          return Uri.encodeComponent(seg);
        }
      }).join('/');
      webDavUrl += segments;
    }
    return webDavUrl;
  }

  static Options _getWebDAVOptions({String method = 'GET'}) {
    final currentServer = Get.find<CoreService>().currentServer.value;
    final username = currentServer?.username ?? '';
    final password = currentServer?.password ?? '';
    final authHeader = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    return Options(
      method: method,
      headers: {
        'Authorization': authHeader,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      validateStatus: (status) {
        return status! < 500;
      },
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 30),
    );
  }

  static Future<ObjectModel> get({
    required String path,
    String password = '',
    int retry = 0,
  }) async {
    try {
      final url = _buildWebDAVUrl(path);
      final options = _getWebDAVOptions(method: 'PROPFIND');
      options.headers!['Depth'] = '0';
      options.headers!['Content-Type'] = 'application/xml';

      final response = await DioService.to.dio.request(
        url,
        options: options,
        data: '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <getcontentlength/>
    <getlastmodified/>
    <resourcetype/>
  </prop>
</propfind>''',
      );

      if (response.statusCode == 207) {
        return _parseWebDAVPropfindResponse(response.data.toString(), url);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to get object: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting object: $e');
      throw e;
    }
  }

  static Future<dynamic> getList({
    required String path,
    int page = 1,
    int pageSize = 0,
    String password = '',
    bool refresh = false,
  }) async {
    try {
      final url = _buildWebDAVUrl(path);
      final options = _getWebDAVOptions(method: 'PROPFIND');
      options.headers!['Depth'] = '1';
      options.headers!['Content-Type'] = 'application/xml';

      final response = await DioService.to.dio.request(
        url,
        options: options,
        data: '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <getcontentlength/>
    <getlastmodified/>
    <resourcetype/>
  </prop>
</propfind>''',
      );

      if (response.statusCode == 207) {
        final objects = _parseWebDAVListResponse(response.data.toString(), path);
        return {
          'code': 200,
          'data': {
            'content': objects.map((obj) => obj.toJson()).toList(),
          },
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to get list: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in ObjectRepository.getList: $e');
      return null;
    }
  }

  static Future<dynamic> rename({
    required String path,
    required String name,
  }) async {
    try {
      final url = _buildWebDAVUrl(path);
      final options = _getWebDAVOptions(method: 'MOVE');
      
      // 正确构建目标路径
      String parentPath = '/';
      if (path != '/' && path.contains('/')) {
        parentPath = path.substring(0, path.lastIndexOf('/'));
      }
      final destinationUrl = '${_buildWebDAVUrl(parentPath).replaceAll(RegExp(r'/+$'), '')}/$name';
      options.headers!['Destination'] = destinationUrl;
      options.headers!['Overwrite'] = 'F';

      final response = await DioService.to.dio.request(url, options: options);

      if (response.statusCode == 201 || response.statusCode == 204) {
        return {'code': 200, 'message': 'Renamed successfully'};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to rename: ${response.statusCode}');
      }
    } catch (e) {
      print('Error renaming object: $e');
      return null;
    }
  }

  static Future<dynamic> move({
    required String srcDir,
    required String dstDir,
    required String name,
  }) async {
    try {
      final srcPath = '$srcDir/$name';
      final dstPath = '$dstDir/$name';
      final url = _buildWebDAVUrl(srcPath);
      final options = _getWebDAVOptions(method: 'MOVE');
      options.headers!['Destination'] = _buildWebDAVUrl(dstPath);
      options.headers!['Overwrite'] = 'T';

      final response = await DioService.to.dio.request(url, options: options);

      if (response.statusCode == 201 || response.statusCode == 204) {
        return {'code': 200, 'message': 'Moved successfully'};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to move: ${response.statusCode}');
      }
    } catch (e) {
      print('Error moving object: $e');
      return null;
    }
  }

  static Future<dynamic> copy({
    required String srcDir,
    required String dstDir,
    required String name,
  }) async {
    try {
      final srcPath = '$srcDir/$name';
      final dstPath = '$dstDir/$name';
      final url = _buildWebDAVUrl(srcPath);
      final options = _getWebDAVOptions(method: 'COPY');
      options.headers!['Destination'] = _buildWebDAVUrl(dstPath);
      options.headers!['Overwrite'] = 'F';

      final response = await DioService.to.dio.request(url, options: options);

      if (response.statusCode == 201 || response.statusCode == 204) {
        return {'code': 200, 'message': 'Copied successfully'};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to copy: ${response.statusCode}');
      }
    } catch (e) {
      print('Error copying object: $e');
      return null;
    }
  }

  static Future<dynamic> remove({
    required String path,
    required String name,
  }) async {
    try {
      final fullPath = '$path/$name';
      final url = _buildWebDAVUrl(fullPath);
      final options = _getWebDAVOptions(method: 'DELETE');

      final response = await DioService.to.dio.request(url, options: options);

      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'code': 200, 'message': 'Deleted successfully'};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to delete: ${response.statusCode}');
      }
    } catch (e) {
      print('Error removing object: $e');
      return null;
    }
  }

  static Future<dynamic> mkdir({
    required String path,
  }) async {
    try {
      final url = _buildWebDAVUrl(path);
      final options = _getWebDAVOptions(method: 'MKCOL');

      final response = await DioService.to.dio.request(url, options: options);

      if (response.statusCode == 201 || response.statusCode == 204) {
        return {'code': 200, 'message': 'Directory created successfully'};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed');
      } else if (response.statusCode == 405) {
        throw Exception('Directory already exists');
      } else {
        throw Exception('Failed to create directory: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating directory: $e');
      return null;
    }
  }

  static Future<dynamic> put({
    required List<int> fileData,
    required String fileName,
    required String remotePath,
    String password = '',
  }) async {
    try {
      final fullPath = '$remotePath/$fileName';
      final url = _buildWebDAVUrl(fullPath);
      final options = _getWebDAVOptions(method: 'PUT');
      options.headers!['Content-Type'] = 'application/octet-stream';
      options.headers!['Content-Length'] = fileData.length;

      final response = await DioService.to.dio.put(
        url,
        options: options,
        data: Stream.fromIterable([fileData]),
      );

      if (response.statusCode == 201 || response.statusCode == 204) {
        return {'code': 200, 'message': 'File uploaded successfully'};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to upload file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  static Future<dynamic> getDirs({
    required String path,
    String password = '',
    bool force_root = false,
  }) async {
    try {
      final result = await getList(path: path, password: password);
      if (result == null) return null;

      final content = result['data']['content'] as List;
      final dirs = content.where((item) => item['is_dir'] == true).toList();

      return {
        'code': 200,
        'data': {
          'content': dirs,
        },
      };
    } catch (e) {
      print('Error getting directories: $e');
      return null;
    }
  }

  static Future<List<FsSearchModel>> search({
    required String keywords,
    required int page,
    required int pageSize,
    required String parent,
    required String password,
  }) async {
    try {
      final result = await getList(path: parent, password: password);
      if (result == null) return [];

      final content = result['data']['content'] as List;
      final filtered = content.where((item) {
        final name = item['name']?.toString().toLowerCase() ?? '';
        return name.contains(keywords.toLowerCase());
      }).toList();

      final models = filtered.map((d) => FsSearchModel.fromJson(d)).toList();
      return models;
    } catch (e) {
      print('Error searching objects: $e');
      return [];
    }
  }

  static ObjectModel _parseWebDAVPropfindResponse(String xml, String path) {
    final document = XmlDocument.parse(xml);
    final davNamespace = 'DAV:';
    final responseElement = document.findAllElements('response', namespace: davNamespace).first;

    final object = ObjectModel();
    // 从路径或URL中提取文件名
    final pathParts = path.split('/');
    // 找到最后一个非空部分作为文件名
    String fileName = 'unknown';
    for (int i = pathParts.length - 1; i >= 0; i--) {
      if (pathParts[i].isNotEmpty) {
        fileName = pathParts[i];
        break;
      }
    }
    object.name = fileName;
    object.rawUrl = path;

    final propElement = responseElement.findAllElements('prop', namespace: davNamespace).firstOrNull;
    if (propElement != null) {
      final resourceTypeElement = propElement.findElements('resourcetype', namespace: davNamespace).firstOrNull;
      final isDir = resourceTypeElement?.findElements('collection', namespace: davNamespace).isNotEmpty ?? false;
      object.isDir = isDir;
      object.type = isDir ? 1 : 2;

      if (!isDir) {
        final contentLengthElement = propElement.findElements('getcontentlength', namespace: davNamespace).firstOrNull;
        object.size = int.tryParse(contentLengthElement?.text ?? '0') ?? 0;
      }

      final lastModifiedElement = propElement.findElements('getlastmodified', namespace: davNamespace).firstOrNull;
      if (lastModifiedElement != null) {
        object.modified = DateTime.tryParse(lastModifiedElement.text);
      }
    }

    return object;
  }

  static List<ObjectModel> _parseWebDAVListResponse(String xml, String path) {
    final objects = <ObjectModel>[];
    final document = XmlDocument.parse(xml);
    final davNamespace = 'DAV:';

    final responseElements = document.findAllElements('response', namespace: davNamespace);

    for (final responseElement in responseElements) {
      try {
        var hrefElement = responseElement.findElements('href', namespace: davNamespace).firstOrNull;
        if (hrefElement == null) {
          hrefElement = responseElement.findElements('href').firstOrNull;
        }
        if (hrefElement == null) continue;

        final href = hrefElement.text;

        if (href == path || href == '$path/') {
          continue;
        }

        // 确保href是完整的URL
        String fullHref = href;
        if (!fullHref.startsWith('http://') && !fullHref.startsWith('https://')) {
          // 构建完整的URL
          final currentServer = Get.find<CoreService>().currentServer.value;
          final serverUrl = currentServer?.url ?? '';
          String baseUrl = serverUrl;
          if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
            baseUrl = 'http://$baseUrl';
          }
          if (!baseUrl.endsWith('/')) {
            baseUrl += '/';
          }
          // 移除href开头的/（如果有）
          if (fullHref.startsWith('/')) {
            fullHref = fullHref.substring(1);
          }
          fullHref = baseUrl + fullHref;
        }

        final fileName = fullHref.split('/').last;
        final isDir = fullHref.endsWith('/');

        final object = ObjectModel();
        object.name = fileName;
        object.type = isDir ? 1 : 2;
        object.isDir = isDir;
        object.rawUrl = fullHref;

        var propstatElement = responseElement.findElements('propstat', namespace: davNamespace).firstOrNull;
        if (propstatElement == null) {
          propstatElement = responseElement.findElements('propstat').firstOrNull;
        }
        if (propstatElement != null) {
          var propElement = propstatElement.findElements('prop', namespace: davNamespace).firstOrNull;
          if (propElement == null) {
            propElement = propstatElement.findElements('prop').firstOrNull;
          }
          if (propElement != null) {
            if (!isDir) {
              var contentLengthElement = propElement.findElements('getcontentlength', namespace: davNamespace).firstOrNull;
              if (contentLengthElement == null) {
                contentLengthElement = propElement.findElements('getcontentlength').firstOrNull;
              }
              if (contentLengthElement != null) {
                object.size = int.tryParse(contentLengthElement.text) ?? 0;
              }
            }

            var lastModifiedElement = propElement.findElements('getlastmodified', namespace: davNamespace).firstOrNull;
            if (lastModifiedElement == null) {
              lastModifiedElement = propElement.findElements('getlastmodified').firstOrNull;
            }
            if (lastModifiedElement != null) {
              object.modified = DateTime.tryParse(lastModifiedElement.text);
            }
          }
        }

        objects.add(object);
      } catch (e) {
        print('Error parsing individual response element: $e');
        continue;
      }
    }

    return objects;
  }
}

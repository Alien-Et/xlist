import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/helper/index.dart';

class ThumbnailCache {
  static final ThumbnailCache _instance = ThumbnailCache._internal();
  factory ThumbnailCache() => _instance;
  ThumbnailCache._internal();

  final Dio _dio = Dio();
  final Map<String, String> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const int _maxMemoryCacheSize = 50;
  static const int _maxDiskCacheDays = 30;

  Directory? _cacheDir;

  Future<Directory?> get cacheDir async {
    try {
      // 使用更持久的存储位置
      _cacheDir ??= await getApplicationDocumentsDirectory();
      if (_cacheDir == null) {
        // 如果无法获取应用文档目录，回退到临时目录
        _cacheDir = await getTemporaryDirectory();
        if (_cacheDir == null) {
          return null;
        }
      }
      final thumbnailDir = Directory(p.join(_cacheDir!.path, 'thumbnails'));
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }
      return thumbnailDir;
    } catch (e) {
      print('Error getting cache directory: $e');
      return null;
    }
  }

  String _generateCacheKey(String url, Map<String, String>? headers) {
    final key = headers != null ? '$url-${headers.hashCode}' : url;
    final bytes = utf8.encode(key);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<File?> _getCacheFile(String cacheKey) async {
    final dir = await cacheDir;
    if (dir == null) {
      return null;
    }
    return File(p.join(dir.path, '$cacheKey.jpg'));
  }

  Future<bool> _isCacheValid(File? file) async {
    if (file == null || !await file.exists()) return false;
    
    try {
      final lastModified = await file.lastModified();
      final age = DateTime.now().difference(lastModified);
      return age.inDays < _maxDiskCacheDays;
    } catch (e) {
      print('Error checking cache validity: $e');
      return false;
    }
  }

  Future<void> _cleanupOldCache() async {
    try {
      final dir = await cacheDir;
      if (dir != null && await dir.exists()) {
        final files = dir.listSync();
        
        for (final file in files) {
          if (file is File) {
            try {
              final lastModified = await file.lastModified();
              final age = DateTime.now().difference(lastModified);
              if (age.inDays >= _maxDiskCacheDays) {
                await file.delete();
              }
            } catch (e) {
              print('Error processing file: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error cleaning up old cache: $e');
    }
  }

  Future<void> _cleanupMemoryCache() async {
    if (_memoryCache.length <= _maxMemoryCacheSize) return;

    final sortedKeys = _cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final toRemove = sortedKeys.take(_memoryCache.length - _maxMemoryCacheSize);
    for (final entry in toRemove) {
      _memoryCache.remove(entry.key);
      _cacheTimestamps.remove(entry.key);
    }
  }

  Future<String?> _downloadThumbnail(String url, Map<String, String>? headers) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final cacheKey = _generateCacheKey(url, headers);
        final cacheFile = await _getCacheFile(cacheKey);
        
        if (cacheFile != null) {
          await cacheFile.writeAsBytes(response.data);
          
          _memoryCache[cacheKey] = cacheFile.path;
          _cacheTimestamps[cacheKey] = DateTime.now();
          
          await _cleanupMemoryCache();
          
          return cacheFile.path;
        }
      }
    } catch (e) {
      print('Error downloading thumbnail: $e');
    }
    return null;
  }

  /// 视频缩略图：WebDAV 无缩略图接口，下载整个视频文件生成帧成本过高，
  /// 这里不下载视频文件，返回 null 由调用方回退到类型图标。
  Future<String?> _generateVideoThumbnail(String videoUrl, Map<String, String>? headers) async {
    return null;
  }

  Future<String?> getThumbnail({
    required String url,
    Map<String, String>? headers,
    bool isVideo = false,
  }) async {
    try {
      final cacheKey = _generateCacheKey(url, headers);
      
      if (_memoryCache.containsKey(cacheKey)) {
        _cacheTimestamps[cacheKey] = DateTime.now();
        return _memoryCache[cacheKey];
      }

      final cacheFile = await _getCacheFile(cacheKey);
      
      if (cacheFile != null && await _isCacheValid(cacheFile)) {
        _memoryCache[cacheKey] = cacheFile.path;
        try {
          _cacheTimestamps[cacheKey] = await cacheFile.lastModified();
        } catch (e) {
          _cacheTimestamps[cacheKey] = DateTime.now();
        }
        return cacheFile.path;
      }

      String? thumbnailPath;
      if (isVideo) {
        thumbnailPath = await _generateVideoThumbnail(url, headers);
      } else {
        thumbnailPath = await _downloadThumbnail(url, headers);
      }

      if (thumbnailPath != null) {
        _memoryCache[cacheKey] = thumbnailPath;
        _cacheTimestamps[cacheKey] = DateTime.now();
      }

      return thumbnailPath;
    } catch (e) {
      print('Error getting thumbnail: $e');
      return null;
    }
  }

  Future<String?> getThumbnailForObject(
    ObjectModel object, {
    Map<String, String>? headers,
  }) async {
    if (object.thumb != null && object.thumb!.isNotEmpty) {
      final isVideo = PreviewHelper.isVideo(object.name ?? '');
      // 视频不下载整个文件（成本过高），返回 null 回退到类型图标
      if (isVideo) return null;
      return getThumbnail(
        url: object.thumb!,
        headers: headers,
        isVideo: false,
      );
    }
    return null;
  }

  Future<void> clearCache() async {
    try {
      _memoryCache.clear();
      _cacheTimestamps.clear();
      
      final dir = await cacheDir;
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  Future<int> getCacheSize() async {
    try {
      final dir = await cacheDir;
      if (dir == null || !await dir.exists()) return 0;
      
      int totalSize = 0;
      final files = dir.listSync();
      
      for (final file in files) {
        if (file is File) {
          try {
            totalSize += await file.length();
          } catch (e) {
            print('Error getting file size: $e');
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Error getting cache size: $e');
      return 0;
    }
  }

  Future<void> init() async {
    try {
      await _cleanupOldCache();
    } catch (e) {
      print('Error initializing thumbnail cache: $e');
      // 即使初始化失败，也允许应用继续运行
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:xlist/services/thumbnail_cache.dart';
import 'package:xlist/models/index.dart';

void main() {
  group('ThumbnailCache Tests', () {
    late ThumbnailCache cache;

    setUp(() {
      cache = ThumbnailCache();
    });

    test('should be singleton', () {
      final cache1 = ThumbnailCache();
      final cache2 = ThumbnailCache();
      expect(identical(cache1, cache2), true);
    });

    test('should initialize cache', () async {
      await cache.init();
      expect(cache, isNotNull);
    });

    test('should get cache size', () async {
      final size = await cache.getCacheSize();
      expect(size, greaterThanOrEqualTo(0));
    });

    test('should clear cache', () async {
      await cache.clearCache();
      final size = await cache.getCacheSize();
      expect(size, equals(0));
    });

    test('should handle null thumbnail in object', () async {
      final object = ObjectModel()
        ..name = 'test.jpg'
        ..thumb = null;
      final result = await cache.getThumbnailForObject(object);
      expect(result, isNull);
    });

    test('should handle empty thumbnail in object', () async {
      final object = ObjectModel()
        ..name = 'test.jpg'
        ..thumb = '';
      final result = await cache.getThumbnailForObject(object);
      expect(result, isNull);
    });
  });
}

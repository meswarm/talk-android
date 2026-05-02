import 'package:flutter_test/flutter_test.dart';

import 'package:talk/composer/composer_image_compress.dart';

void main() {
  group('isCompressibleChatImageMime', () {
    test('allows common raster types', () {
      expect(isCompressibleChatImageMime('image/jpeg'), true);
      expect(isCompressibleChatImageMime('image/png'), true);
      expect(isCompressibleChatImageMime('image/webp'), true);
      expect(isCompressibleChatImageMime('image/heic'), true);
    });

    test('excludes gif and non-images', () {
      expect(isCompressibleChatImageMime('image/gif'), false);
      expect(isCompressibleChatImageMime('video/mp4'), false);
      expect(isCompressibleChatImageMime('application/pdf'), false);
    });
  });
}

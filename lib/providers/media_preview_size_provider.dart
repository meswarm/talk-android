import 'package:flutter/material.dart';

import '../media/media_preview_sizes.dart';
import '../services/local_storage.dart';

class MediaPreviewSizeProvider extends ChangeNotifier {
  MediaPreviewSizeProvider({
    required MediaPreviewSizes bubbleSizes,
    required MediaPreviewSizes tableSizes,
  }) : _bubbleSizes = bubbleSizes.clamp(),
       _tableSizes = tableSizes.clamp();

  MediaPreviewSizes _bubbleSizes;
  MediaPreviewSizes _tableSizes;

  MediaPreviewSizes get bubbleSizes => _bubbleSizes;
  MediaPreviewSizes get tableSizes => _tableSizes;

  MediaPreviewSizes sizesFor(MediaPreviewContext context) {
    return switch (context) {
      MediaPreviewContext.bubble => _bubbleSizes,
      MediaPreviewContext.table => _tableSizes,
    };
  }

  Future<void> setBubbleSizes(MediaPreviewSizes sizes) async {
    final next = sizes.clamp();
    if (next == _bubbleSizes) return;
    _bubbleSizes = next;
    notifyListeners();
    await LocalStorage().saveBubbleMediaPreviewSizes(next);
  }

  Future<void> setTableSizes(MediaPreviewSizes sizes) async {
    final next = sizes.clamp();
    if (next == _tableSizes) return;
    _tableSizes = next;
    notifyListeners();
    await LocalStorage().saveTableMediaPreviewSizes(next);
  }

  Future<void> resetBubbleSizes() =>
      setBubbleSizes(MediaPreviewSizes.bubbleDefaults);

  Future<void> resetTableSizes() =>
      setTableSizes(MediaPreviewSizes.tableDefaults);
}

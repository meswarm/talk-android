import 'package:flutter/material.dart';

import '../services/local_storage.dart';

/// 聊天气泡内 Markdown 收起时的最大高度，按屏幕高度百分比，与个人资料中滑条同步。
class BubbleMaxHeightProvider extends ChangeNotifier {
  BubbleMaxHeightProvider({required int initialPct})
      : _pct = initialPct.clamp(
          LocalStorage.minBubbleMaxHeightPct,
          LocalStorage.maxBubbleMaxHeightPct,
        );

  int _pct;

  int get pct => _pct;

  double maxHeightForViewport(double screenHeight) =>
      screenHeight * _pct / 100.0;

  Future<void> setPct(int pct) async {
    final n = pct.clamp(
      LocalStorage.minBubbleMaxHeightPct,
      LocalStorage.maxBubbleMaxHeightPct,
    );
    if (n == _pct) return;
    _pct = n;
    notifyListeners();
    await LocalStorage().saveBubbleMaxHeightPct(n);
  }
}

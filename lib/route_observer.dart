import 'package:flutter/material.dart';

/// 用于 [RouteAware]（例如从子页面返回时刷新聊天页偏好）。
final RouteObserver<ModalRoute<void>> talkRouteObserver =
    RouteObserver<ModalRoute<void>>();

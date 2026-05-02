import 'package:flutter/material.dart';
import '../services/matrix_service.dart';

enum AuthState { initial, loading, authenticated, error }

class AuthProvider extends ChangeNotifier {
  final MatrixService matrixService;

  AuthState _state = AuthState.initial;
  String _errorMessage = '';

  AuthState get state => _state;
  String get errorMessage => _errorMessage;
  bool get isLoggedIn => _state == AuthState.authenticated;

  AuthProvider({required this.matrixService});

  /// 初始化 — 检查是否已有保存的会话
  Future<void> init() async {
    try {
      await matrixService.init();
      if (matrixService.isLoggedIn) {
        _state = AuthState.authenticated;
      }
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = '初始化失败: $e';
    }
    notifyListeners();
  }

  /// 登录
  Future<void> login({
    required String homeserverUrl,
    required String username,
    required String password,
  }) async {
    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      await matrixService.login(
        homeserverUrl: homeserverUrl,
        username: username,
        password: password,
      );
      _state = AuthState.authenticated;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = '登录失败: $e';
    }
    notifyListeners();
  }

  /// 注册（含 homeserver UIA：dummy/terms）并进入已登录态
  Future<void> register({
    required String homeserverUrl,
    required String username,
    required String password,
  }) async {
    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      await matrixService.registerWithAutoUia(
        homeserverUrl: homeserverUrl,
        username: username,
        password: password,
      );
      _state = AuthState.authenticated;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = '注册失败: $e';
    }
    notifyListeners();
  }

  /// 登出
  Future<void> logout() async {
    await matrixService.logout();
    _state = AuthState.initial;
    notifyListeners();
  }
}

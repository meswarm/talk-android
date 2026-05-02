import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqlite;

import '../matrix/matrix_register_uia_logic.dart';

void _assertRegisterResponseHasLogin(RegisterResponse res) {
  if (res.accessToken == null || res.userId.isEmpty) {
    throw Exception('注册成功但未返回登录令牌，请改用其它客户端注册。');
  }
}

class MatrixService {
  Client? _client;
  bool _initialized = false;

  Client get client {
    if (_client == null) throw Exception('MatrixService not initialized');
    return _client!;
  }

  bool get isInitialized => _initialized;
  bool get isLoggedIn => _client != null && _client!.isLogged();

  /// 初始化 Matrix 客户端
  Future<void> init() async {
    final dbDirectory = await getApplicationSupportDirectory();
    final dbPath = '${dbDirectory.path}/talk_matrix.sqlite';
    final sqliteDb = await sqlite.openDatabase(dbPath);

    _client = Client(
      'TalkApp',
      database: await MatrixSdkDatabase.init(
        'talk_app',
        database: sqliteDb,
      ),
    );

    await _client!.init();
    _initialized = true;
  }

  /// 登录到 Matrix 服务器
  Future<LoginResponse> login({
    required String homeserverUrl,
    required String username,
    required String password,
  }) async {
    await client.checkHomeserver(Uri.parse(homeserverUrl));

    final response = await client.login(
      LoginType.mLoginPassword,
      identifier: AuthenticationUserIdentifier(user: username),
      password: password,
    );

    return response;
  }

  /// 注册并完成 homeserver 允许的 dummy/terms UIA；成功后 [client] 已登录。
  Future<RegisterResponse> registerWithAutoUia({
    required String homeserverUrl,
    required String username,
    required String password,
  }) async {
    await client.checkHomeserver(Uri.parse(homeserverUrl));

    final u = username.trim();

    try {
      final res = await client.register(
        username: u,
        password: password,
        initialDeviceDisplayName: 'Talk Web',
        auth: AuthenticationData(type: 'm.login.dummy'),
      );
      _assertRegisterResponseHasLogin(res);
      return res;
    } on MatrixException catch (e0) {
      if (e0.error == MatrixError.M_USER_IN_USE) {
        throw Exception('该用户名已被占用');
      }

      final session0 = e0.session;
      final apiFlows = e0.authenticationFlows;
      if (session0 == null ||
          session0.isEmpty ||
          apiFlows == null ||
          apiFlows.isEmpty) {
        rethrow;
      }

      final flows =
          apiFlows.map((f) => AuthFlow(stages: f.stages)).toList(growable: false);
      final stages = pickAutoCompletableFlow(flows);
      if (stages == null) {
        throw Exception(
          '该 Homeserver 的注册需要额外步骤（${flowSummary(flows)}）。'
          '请使用 Element 等客户端完成注册后再登录，或请管理员开启仅 dummy/terms 的开放注册。',
        );
      }

      var session = session0;
      for (var i = 0; i < stages.length; i++) {
        final stage = stages[i];
        final auth = stage == 'm.login.terms'
            ? AuthenticationData(
                type: 'm.login.terms',
                session: session,
                additionalFields: {'accepted': true},
              )
            : AuthenticationData(type: 'm.login.dummy', session: session);

        try {
          final res = await client.register(
            username: u,
            password: password,
            initialDeviceDisplayName: 'Talk Web',
            auth: auth,
          );
          _assertRegisterResponseHasLogin(res);
          return res;
        } on MatrixException catch (e) {
          if (e.error == MatrixError.M_USER_IN_USE) {
            throw Exception('该用户名已被占用');
          }
          final newSession = e.session;
          if (newSession != null && newSession.isNotEmpty) {
            session = newSession;
          }
          if (i == stages.length - 1) {
            final msg = e.errorMessage;
            throw Exception(msg.isNotEmpty ? msg : '注册失败');
          }
        }
      }

      throw Exception('注册未完成，请稍后再试');
    }
  }

  /// 登出
  Future<void> logout() async {
    await client.logout();
  }

  /// 获取所有房间（已排序，最新在前）
  List<Room> get rooms {
    final roomList = List<Room>.from(client.rooms);
    roomList.sort((a, b) {
      final aTime = a.lastEvent?.originServerTs ?? DateTime(0);
      final bTime = b.lastEvent?.originServerTs ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return roomList;
  }

  /// 获取指定房间
  Room? getRoom(String roomId) {
    return client.getRoomById(roomId);
  }

  /// 发送文本消息
  Future<String?> sendTextMessage(Room room, String message) async {
    return await room.sendTextEvent(
      message,
      parseCommands: false,
      displayPendingEvent: false,
    );
  }

  /// 获取房间的显示名称
  String getRoomDisplayName(Room room) {
    return room.getLocalizedDisplayname();
  }

  /// 获取房间头像 URL（异步）
  Future<Uri?> getRoomAvatarUrl(Room room) async {
    final avatar = room.avatar;
    if (avatar == null) return null;
    try {
      return await avatar.getDownloadUri(client);
    } catch (_) {
      return null;
    }
  }

  /// 当前登录用户头像的 HTTP 下载地址（请求须带 `Authorization: Bearer`，见 SDK `MxcUriExtension.getDownloadUri`）。
  Future<Uri?> getOwnAvatarDownloadUri() async {
    try {
      final profile = await client.fetchOwnProfile();
      if (profile.avatarUrl == null) return null;
      return await profile.avatarUrl!.getDownloadUri(client);
    } catch (_) {
      return null;
    }
  }

  /// 获取房间最后一条消息的预览文本
  String getLastMessagePreview(Room room) {
    final lastEvent = room.lastEvent;
    if (lastEvent == null) return '';

    if (lastEvent.type == EventTypes.Message) {
      final msgType = lastEvent.messageType;
      if (msgType == MessageTypes.Text) {
        final body = lastEvent.body;
        return body.length > 50 ? '${body.substring(0, 50)}...' : body;
      } else if (msgType == MessageTypes.Image) {
        return '[图片]';
      } else if (msgType == MessageTypes.Video) {
        return '[视频]';
      } else if (msgType == MessageTypes.File) {
        return '[文件]';
      } else if (msgType == MessageTypes.Audio) {
        return '[语音]';
      }
    }
    return '';
  }

  /// 释放资源
  Future<void> dispose() async {
    await _client?.dispose();
  }
}

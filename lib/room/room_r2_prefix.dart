import 'package:matrix/matrix.dart';

/// Matrix 房间状态事件：共享 R2 对象键前缀（不含 bucket）。
///
/// `state_key` 为空字符串；内容仅含 `prefix`，例如 `team-a/A-room`。
const String kTalkRoomR2PrefixEventType = 'com.talk.r2_prefix';

/// 从房间 state 读取的原始配置。
class RoomR2PrefixConfig {
  const RoomR2PrefixConfig({required this.prefix});

  final String prefix;
}

/// 解析与校验结果。
sealed class RoomR2PrefixParseResult {}

/// 未配置或已清空。
class RoomR2PrefixNotConfigured extends RoomR2PrefixParseResult {}

/// 已配置且合法。
class RoomR2PrefixOk extends RoomR2PrefixParseResult {
  RoomR2PrefixOk(this.normalized);

  final String normalized;
}

/// 已配置但非法（需提示管理员修正）。
class RoomR2PrefixInvalid extends RoomR2PrefixParseResult {
  RoomR2PrefixInvalid(this.message);

  final String message;
}

/// 从 [StrippedStateEvent] 解析 `prefix`。
RoomR2PrefixParseResult parseRoomR2PrefixFromState(StrippedStateEvent? state) {
  if (state == null) return RoomR2PrefixNotConfigured();
  final raw = state.content.tryGet<String>('prefix');
  if (raw == null) return RoomR2PrefixNotConfigured();
  return validateRoomR2Prefix(raw);
}

/// 校验并规范化用户输入或 state 中的字符串。
RoomR2PrefixParseResult validateRoomR2Prefix(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return RoomR2PrefixNotConfigured();

  if (t.contains('\\')) {
    return RoomR2PrefixInvalid('路径不能包含反斜杠');
  }
  if (t.startsWith('/') || t.endsWith('/')) {
    return RoomR2PrefixInvalid('路径不能以 / 开头或结尾');
  }

  final segments = t.split('/');
  for (final seg in segments) {
    if (seg.isEmpty) {
      return RoomR2PrefixInvalid('路径不能包含空段（连续 /）');
    }
    if (seg == '.' || seg == '..') {
      return RoomR2PrefixInvalid('路径段不能为 . 或 ..');
    }
  }

  return RoomR2PrefixOk(t);
}

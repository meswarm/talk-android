import 'package:flutter_test/flutter_test.dart';
import 'package:talk/room/room_r2_prefix.dart';

/// [RoomInfoPage] 依赖 Matrix [Room] 与同步客户端，完整 widget 测试成本较高。
/// 房间 R2 Prefix 的解析与校验逻辑见 [test/room/room_r2_prefix_test.dart]。
void main() {
  test('room R2 state event type is stable', () {
    expect(kTalkRoomR2PrefixEventType, 'com.talk.r2_prefix');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:talk/r2/r2_ref.dart';

/// 旧版依赖 `?mime=` 的规范化已移除；预览与推断仅依据路径段 / 扩展名。
void main() {
  test('bracket r2 link with only mime=video and no video path/ext is not video',
      () {
    expect(
      inferR2MediaKind('r2://b/attachments/blob?mime=video%2Fmp4'),
      R2MediaKind.unknown,
    );
  });

  test('video path infers video without mime query', () {
    expect(
      inferR2MediaKind('r2://bucket/team/videos/123-clip.mp4'),
      R2MediaKind.video,
    );
  });

  test('mp4 in attachments infers video without mime query', () {
    expect(
      inferR2MediaKind('r2://matrix/attachments/x-capture.mp4'),
      R2MediaKind.video,
    );
  });
}

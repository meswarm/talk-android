import 'package:flutter_test/flutter_test.dart';
import 'package:talk/matrix/typing_line.dart';

void main() {
  group('buildTypingLineFromNames', () {
    test('returns null for empty', () {
      expect(buildTypingLineFromNames([]), isNull);
    });

    test('one name', () {
      expect(buildTypingLineFromNames(['Alice']), 'Alice 正在输入…');
    });

    test('two names', () {
      expect(
        buildTypingLineFromNames(['甲', '乙']),
        '甲、乙 正在输入…',
      );
    });

    test('three names', () {
      expect(
        buildTypingLineFromNames(['A', 'B', 'C']),
        'A、B 等 3 人正在输入…',
      );
    });

    test('four names', () {
      expect(
        buildTypingLineFromNames(['一', '二', '三', '四']),
        '一、二 等 4 人正在输入…',
      );
    });
  });
}

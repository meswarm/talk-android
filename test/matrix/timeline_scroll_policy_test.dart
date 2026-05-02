import 'package:flutter_test/flutter_test.dart';
import 'package:talk/matrix/timeline_scroll_policy.dart';

void main() {
  group('shouldAutoScrollToBottomOnTimelineInsert', () {
    test(
      'does not auto-scroll when history is inserted away from newest edge',
      () {
        expect(
          shouldAutoScrollToBottomOnTimelineInsert(
            insertIndex: 8,
            wasAtBottom: true,
            userScrollInProgress: false,
          ),
          isFalse,
        );
      },
    );

    test('does not auto-scroll while the user is actively scrolling', () {
      expect(
        shouldAutoScrollToBottomOnTimelineInsert(
          insertIndex: 0,
          wasAtBottom: true,
          userScrollInProgress: true,
        ),
        isFalse,
      );
    });

    test(
      'auto-scrolls only for newest-edge insert while already at bottom',
      () {
        expect(
          shouldAutoScrollToBottomOnTimelineInsert(
            insertIndex: 0,
            wasAtBottom: true,
            userScrollInProgress: false,
          ),
          isTrue,
        );
        expect(
          shouldAutoScrollToBottomOnTimelineInsert(
            insertIndex: 0,
            wasAtBottom: false,
            userScrollInProgress: false,
          ),
          isFalse,
        );
      },
    );
  });
}

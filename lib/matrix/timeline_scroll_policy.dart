bool shouldAutoScrollToBottomOnTimelineInsert({
  required int insertIndex,
  required bool wasAtBottom,
  required bool userScrollInProgress,
}) {
  return insertIndex == 0 && wasAtBottom && !userScrollInProgress;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/quick_extract/quick_extract_models.dart';
import 'package:talk/widgets/quick_extract_candidates_panel.dart';

void main() {
  testWidgets('quick extract candidates panel calls onPick', (tester) async {
    QuickExtractCandidate? picked;
    const item = QuickExtractCandidate(
      label: '26050502 - 送钥匙',
      value: '26050502',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickExtractCandidatesPanel(
            items: const [item],
            onPick: (value) => picked = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('26050502 - 送钥匙'));
    await tester.pump();

    expect(picked, item);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:talk/matrix/matrix_register_uia_logic.dart';

void main() {
  test('pickAutoCompletableFlow selects dummy+terms flow', () {
    final flows = [
      const AuthFlow(stages: ['m.login.email.identity']),
      const AuthFlow(stages: ['m.login.terms', 'm.login.dummy']),
    ];

    expect(pickAutoCompletableFlow(flows), ['m.login.terms', 'm.login.dummy']);
  });

  test('flowSummary empty flows', () {
    expect(flowSummary([]), '（无）');
  });

  test('flowSummary joins flows with full-width semicolon and stages with arrow', () {
    final flows = [
      const AuthFlow(stages: ['m.login.dummy']),
      const AuthFlow(stages: ['m.login.terms', 'm.login.dummy']),
    ];
    expect(
      flowSummary(flows),
      'm.login.dummy； m.login.terms → m.login.dummy',
    );
  });
}

// Pure helpers for Matrix registration UIA (dummy / terms) flow selection.

class AuthFlow {
  final List<String> stages;
  const AuthFlow({required this.stages});
}

const _allowedStages = {'m.login.dummy', 'm.login.terms'};

/// Picks the first server flow whose stages are only dummy and/or terms.
List<String>? pickAutoCompletableFlow(List<AuthFlow> flows) {
  for (final f in flows) {
    final stages = f.stages;
    if (stages.isEmpty) continue;
    if (stages.every(_allowedStages.contains)) {
      return List<String>.from(stages);
    }
  }
  return null;
}

/// Human-readable summary of offered UIA flows (for error messages).
String flowSummary(List<AuthFlow> flows) {
  if (flows.isEmpty) return '（无）';
  return flows.map((f) => f.stages.join(' → ')).join('； ');
}

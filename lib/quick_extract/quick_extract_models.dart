import 'dart:convert';

class QuickExtractCandidate {
  const QuickExtractCandidate({required this.label, required this.value});

  final String label;
  final String value;

  factory QuickExtractCandidate.fromJson(Map<String, dynamic> json) {
    final value = _jsonScalarToText(json['value']);
    final label = _jsonScalarToText(json['label']).trim();
    return QuickExtractCandidate(
      label: label.isEmpty ? value : label,
      value: value.trim(),
    );
  }
}

String _jsonScalarToText(Object? raw) {
  if (raw == null) return '';
  if (raw is String) return raw;
  if (raw is num || raw is bool) return raw.toString();
  return '';
}

List<QuickExtractCandidate> parseQuickExtractCandidates(String content) {
  final decoded = jsonDecode(content);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('DeepSeek 返回不是 JSON object');
  }
  final rawItems = decoded['items'];
  if (rawItems is! List) return const [];
  final out = <QuickExtractCandidate>[];
  for (final raw in rawItems) {
    if (raw is! Map<String, dynamic>) continue;
    final item = QuickExtractCandidate.fromJson(raw);
    if (item.value.isEmpty) continue;
    out.add(item);
    if (out.length >= 30) break;
  }
  return out;
}

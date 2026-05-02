class DeepSeekConfig {
  const DeepSeekConfig({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  final String apiKey;
  final String baseUrl;
  final String model;

  static const defaultBaseUrl = 'https://api.deepseek.com';
  static const defaultModel = 'deepseek-v4-flash';

  static const defaults = DeepSeekConfig(
    apiKey: '',
    baseUrl: defaultBaseUrl,
    model: defaultModel,
  );

  bool get isConfigured => apiKey.trim().isNotEmpty;

  DeepSeekConfig normalized() {
    final nextBaseUrl = baseUrl.trim().isEmpty
        ? defaultBaseUrl
        : baseUrl.trim();
    final nextModel = model.trim().isEmpty ? defaultModel : model.trim();
    return DeepSeekConfig(
      apiKey: apiKey.trim(),
      baseUrl: nextBaseUrl.replaceFirst(RegExp(r'/$'), ''),
      model: nextModel,
    );
  }

  Map<String, dynamic> toJson() {
    final n = normalized();
    return {'apiKey': n.apiKey, 'baseUrl': n.baseUrl, 'model': n.model};
  }

  factory DeepSeekConfig.fromJson(Map<String, dynamic> json) {
    return DeepSeekConfig(
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? defaultBaseUrl,
      model: json['model'] as String? ?? defaultModel,
    ).normalized();
  }

  @override
  bool operator ==(Object other) {
    return other is DeepSeekConfig &&
        other.apiKey == apiKey &&
        other.baseUrl == baseUrl &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(apiKey, baseUrl, model);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:talk/quick_extract/deepseek_config.dart';

void main() {
  test('deepseek config defaults and json roundtrip', () {
    expect(DeepSeekConfig.defaults.baseUrl, 'https://api.deepseek.com');
    expect(DeepSeekConfig.defaults.model, 'deepseek-v4-flash');
    expect(DeepSeekConfig.defaults.isConfigured, isFalse);

    const config = DeepSeekConfig(
      apiKey: 'sk-test',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-v4-flash',
    );

    expect(config.isConfigured, isTrue);
    expect(DeepSeekConfig.fromJson(config.toJson()), config);
  });

  test('deepseek config trims values and falls back to defaults', () {
    final config = DeepSeekConfig.fromJson({
      'apiKey': '  sk-test  ',
      'baseUrl': '',
      'model': '',
    });

    expect(config.apiKey, 'sk-test');
    expect(config.baseUrl, 'https://api.deepseek.com');
    expect(config.model, 'deepseek-v4-flash');
  });
}

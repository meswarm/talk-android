import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'deepseek_config.dart';
import 'deepseek_config_store.dart';
import 'quick_extract_models.dart';

class DeepSeekQuickExtractService extends ChangeNotifier {
  DeepSeekQuickExtractService({
    DeepSeekConfigStore? store,
    http.Client? httpClient,
  }) : _store = store ?? SecureDeepSeekConfigStore(),
       _httpClient = httpClient ?? http.Client();

  final DeepSeekConfigStore _store;
  final http.Client _httpClient;

  DeepSeekConfig? _config;
  bool _loading = false;

  DeepSeekConfig? get config => _config;
  bool get loading => _loading;
  bool get isConfigured => _config?.isConfigured ?? false;

  Future<void> bootstrap() async {
    _loading = true;
    notifyListeners();
    try {
      _config = await _store.load();
    } catch (_) {
      _config = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> saveConfig(DeepSeekConfig config) async {
    final normalized = config.normalized();
    await _store.save(normalized);
    _config = normalized;
    notifyListeners();
  }

  Future<void> clearConfig() async {
    await _store.clear();
    _config = null;
    notifyListeners();
  }

  Future<List<QuickExtractCandidate>> extract({
    required DeepSeekConfig config,
    required String roomPrompt,
    required String markdown,
  }) async {
    final normalized = config.normalized();
    if (!normalized.isConfigured) {
      throw StateError('DeepSeek API Key 未配置');
    }
    if (roomPrompt.trim().isEmpty) {
      throw StateError('房间快速提取提示词未配置');
    }
    if (markdown.trim().isEmpty) {
      return const [];
    }

    final uri = Uri.parse('${normalized.baseUrl}/chat/completions');
    final response = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${normalized.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': normalized.model,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content':
                '你是一个信息提取器。你必须只输出 JSON object，不要输出 Markdown，不要解释。'
                'JSON 格式必须为：{"items":[{"label":"...","value":"..."}]}。'
                '最多返回 30 个选项。不要编造不存在的信息。',
          },
          {
            'role': 'user',
            'content': '房间提示词：\n$roomPrompt\n\n消息原文：\n$markdown',
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('DeepSeek 请求失败: ${response.statusCode}');
    }

    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    final first = choices != null && choices.isNotEmpty ? choices.first : null;
    if (first is! Map<String, dynamic>) return const [];
    final message = first['message'];
    if (message is! Map<String, dynamic>) return const [];
    final content = message['content'] as String?;
    if (content == null || content.trim().isEmpty) return const [];
    final items = _sortCandidatesByMarkdownOrder(
      parseQuickExtractCandidates(content),
      markdown,
    );
    if (items.isEmpty) {
      throw StateError('DeepSeek 未提取到选项，原始响应摘要: ${_responseSummary(content)}');
    }
    return items;
  }

  Future<List<QuickExtractCandidate>> extractWithCurrentConfig({
    required String roomPrompt,
    required String markdown,
  }) {
    final cfg = _config;
    if (cfg == null) {
      throw StateError('请先在个人资料页配置 DeepSeek');
    }
    return extract(config: cfg, roomPrompt: roomPrompt, markdown: markdown);
  }

  Future<List<QuickExtractCandidate>> runConnectivityTest() {
    return extractWithCurrentConfig(
      roomPrompt: '请提取所有候选项',
      markdown: '| 名称 |\n| --- |\n| 测试项A |\n| 测试项B |',
    );
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}

String _responseSummary(String content) {
  final oneLine = content.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (oneLine.length <= 180) return oneLine;
  return '${oneLine.substring(0, 180)}...';
}

List<QuickExtractCandidate> _sortCandidatesByMarkdownOrder(
  List<QuickExtractCandidate> items,
  String markdown,
) {
  final indexed = <({QuickExtractCandidate item, int index, int order})>[];
  final nextSearchStart = <String, int>{};
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    var index = _nextNeedleIndex(markdown, item.value, nextSearchStart);
    if (index < 0 && item.label != item.value) {
      index = _nextNeedleIndex(markdown, item.label, nextSearchStart);
    }
    indexed.add((item: item, index: index, order: i));
  }
  indexed.sort((a, b) {
    final ai = a.index < 0 ? 1 << 30 : a.index;
    final bi = b.index < 0 ? 1 << 30 : b.index;
    final byIndex = ai.compareTo(bi);
    if (byIndex != 0) return byIndex;
    return a.order.compareTo(b.order);
  });
  return [for (final row in indexed) row.item];
}

int _nextNeedleIndex(
  String haystack,
  String needle,
  Map<String, int> nextSearchStart,
) {
  if (needle.isEmpty) return -1;
  final start = nextSearchStart[needle] ?? 0;
  final index = haystack.indexOf(needle, start);
  if (index >= 0) {
    nextSearchStart[needle] = index + needle.length;
  }
  return index;
}

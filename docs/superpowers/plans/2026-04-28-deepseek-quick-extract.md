# DeepSeek Quick Extract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a DeepSeek-powered quick extract button above the chat input that extracts copyable options from the latest incoming text message using a per-room prompt.

**Architecture:** Store global DeepSeek credentials locally, store per-room quick extract prompts locally, and add a small DeepSeek chat-completions client that returns strict JSON candidates. ChatPage finds the latest non-own text event, calls the service, shows a bottom sheet of candidates, and copies plus inserts the selected value into the composer.

**Tech Stack:** Flutter/Dart, `http`, `flutter_secure_storage`, `shared_preferences`, Matrix `Room/Event`, Provider patterns already used in the app.

---

## File Structure

- Create `lib/quick_extract/deepseek_config.dart`: immutable local config model for API Key, Base URL, model, configured checks.
- Create `lib/quick_extract/quick_extract_models.dart`: candidate and response parsing models.
- Create `lib/quick_extract/deepseek_quick_extract_service.dart`: OpenAI-compatible DeepSeek client for strict JSON extraction.
- Create `lib/pages/deepseek_settings_page.dart`: personal profile config page for DeepSeek API settings and test call.
- Modify `lib/services/local_storage.dart`: add per-room quick extract prompt storage.
- Modify `lib/pages/profile_page.dart`: add DeepSeek settings entry.
- Modify `lib/pages/room_info_page.dart`: add quick extract prompt editor for the current room.
- Modify `lib/pages/chat_page.dart`: add collapsed composer toolbar row, quick extract icon button, latest incoming text selection, bottom sheet, and insert behavior.
- Add tests:
  - `test/quick_extract/deepseek_config_test.dart`
  - `test/quick_extract/deepseek_quick_extract_service_test.dart`
  - `test/services/local_storage_quick_extract_test.dart`
  - `test/pages/deepseek_settings_page_test.dart`

---

### Task 1: DeepSeek Config Model

**Files:**
- Create: `lib/quick_extract/deepseek_config.dart`
- Test: `test/quick_extract/deepseek_config_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/quick_extract/deepseek_config_test.dart
```

Expected: FAIL because `DeepSeekConfig` does not exist.

- [ ] **Step 3: Implement the model**

```dart
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
    final nextBaseUrl = baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl.trim();
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
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/quick_extract/deepseek_config_test.dart
```

Expected: PASS.

---

### Task 2: Local Storage For DeepSeek And Room Prompts

**Files:**
- Modify: `lib/services/local_storage.dart`
- Test: `test/services/local_storage_quick_extract_test.dart`

- [ ] **Step 1: Write failing storage tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/quick_extract/deepseek_config.dart';
import 'package:talk/services/local_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });

  test('deepseek config defaults and roundtrips', () async {
    final ls = LocalStorage();
    expect(await ls.loadDeepSeekConfig(), DeepSeekConfig.defaults);

    const config = DeepSeekConfig(
      apiKey: 'sk-test',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-v4-flash',
    );
    await ls.saveDeepSeekConfig(config);
    expect(await ls.loadDeepSeekConfig(), config);
  });

  test('room quick extract prompt roundtrips and clears when empty', () async {
    final ls = LocalStorage();
    expect(await ls.getRoomQuickExtractPrompt('!room:test'), '');

    await ls.saveRoomQuickExtractPrompt('!room:test', '提取第一列');
    expect(await ls.getRoomQuickExtractPrompt('!room:test'), '提取第一列');

    await ls.saveRoomQuickExtractPrompt('!room:test', '   ');
    expect(await ls.getRoomQuickExtractPrompt('!room:test'), '');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/services/local_storage_quick_extract_test.dart
```

Expected: FAIL because the storage methods do not exist.

- [ ] **Step 3: Implement storage methods**

Add imports and keys in `LocalStorage`:

```dart
import '../quick_extract/deepseek_config.dart';

static const _keyDeepSeekConfig = 'talk_deepseek_config_v1';
static const _keyRoomQuickExtractPromptPrefix = 'talk_room_quick_extract_prompt_';
```

Add methods:

```dart
Future<DeepSeekConfig> loadDeepSeekConfig() async {
  final prefs = await _preferences;
  final raw = prefs.getString(_keyDeepSeekConfig);
  if (raw == null || raw.isEmpty) return DeepSeekConfig.defaults;
  try {
    return DeepSeekConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return DeepSeekConfig.defaults;
  }
}

Future<void> saveDeepSeekConfig(DeepSeekConfig config) async {
  final prefs = await _preferences;
  await prefs.setString(_keyDeepSeekConfig, jsonEncode(config.normalized().toJson()));
}

static String _roomQuickExtractPromptKey(String roomId) =>
    '$_keyRoomQuickExtractPromptPrefix$roomId';

Future<String> getRoomQuickExtractPrompt(String roomId) async {
  final prefs = await _preferences;
  return prefs.getString(_roomQuickExtractPromptKey(roomId)) ?? '';
}

Future<void> saveRoomQuickExtractPrompt(String roomId, String prompt) async {
  final prefs = await _preferences;
  final key = _roomQuickExtractPromptKey(roomId);
  final trimmed = prompt.trim();
  if (trimmed.isEmpty) {
    await prefs.remove(key);
  } else {
    await prefs.setString(key, prompt);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/services/local_storage_quick_extract_test.dart
```

Expected: PASS.

---

### Task 3: Quick Extract Models And DeepSeek Client

**Files:**
- Create: `lib/quick_extract/quick_extract_models.dart`
- Create: `lib/quick_extract/deepseek_quick_extract_service.dart`
- Test: `test/quick_extract/deepseek_quick_extract_service_test.dart`

- [ ] **Step 1: Write failing service tests**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:talk/quick_extract/deepseek_config.dart';
import 'package:talk/quick_extract/deepseek_quick_extract_service.dart';

void main() {
  test('deepseek quick extract parses json candidates', () async {
    late http.Request request;
    final service = DeepSeekQuickExtractService(
      client: _FakeClient((req) async {
        request = req;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'items': [
                      {'label': 'ChatGPT Pro', 'value': 'ChatGPT Pro'},
                      {'label': 'Cursor Pro', 'value': 'Cursor Pro'},
                    ],
                  }),
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final items = await service.extract(
      config: const DeepSeekConfig(
        apiKey: 'sk-test',
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-v4-flash',
      ),
      roomPrompt: '提取第一列',
      markdown: '| 服务名称 |\n| --- |\n| ChatGPT Pro |',
    );

    expect(request.url.toString(), 'https://api.deepseek.com/chat/completions');
    expect(request.headers['Authorization'], 'Bearer sk-test');
    expect(request.headers['Content-Type'], contains('application/json'));
    expect(items.map((e) => e.value), ['ChatGPT Pro', 'Cursor Pro']);
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);
  final Future<http.Response> Function(http.Request request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final response = await handler(req);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/quick_extract/deepseek_quick_extract_service_test.dart
```

Expected: FAIL because the service and models do not exist.

- [ ] **Step 3: Implement models**

```dart
class QuickExtractCandidate {
  const QuickExtractCandidate({required this.label, required this.value});

  final String label;
  final String value;

  factory QuickExtractCandidate.fromJson(Map<String, dynamic> json) {
    final value = (json['value'] as String? ?? '').trim();
    final label = (json['label'] as String? ?? value).trim();
    return QuickExtractCandidate(label: label.isEmpty ? value : label, value: value);
  }
}

List<QuickExtractCandidate> parseQuickExtractCandidates(String content) {
  final decoded = jsonDecode(content);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('DeepSeek 返回不是 JSON object');
  }
  final rawItems = decoded['items'];
  if (rawItems is! List) return const [];
  final seen = <String>{};
  final out = <QuickExtractCandidate>[];
  for (final raw in rawItems) {
    if (raw is! Map<String, dynamic>) continue;
    final item = QuickExtractCandidate.fromJson(raw);
    if (item.value.isEmpty || !seen.add(item.value)) continue;
    out.add(item);
    if (out.length >= 30) break;
  }
  return out;
}
```

- [ ] **Step 4: Implement DeepSeek service**

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'deepseek_config.dart';
import 'quick_extract_models.dart';

class DeepSeekQuickExtractService {
  DeepSeekQuickExtractService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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
    final response = await _client.post(
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
                '最多返回 30 个选项。去重。不要编造不存在的信息。',
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
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    final message = choices?.isNotEmpty == true
        ? choices!.first['message'] as Map<String, dynamic>?
        : null;
    final content = message?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      return const [];
    }
    return parseQuickExtractCandidates(content);
  }
}
```

- [ ] **Step 5: Run service tests**

Run:

```bash
flutter test test/quick_extract/deepseek_quick_extract_service_test.dart
```

Expected: PASS.

---

### Task 4: DeepSeek Settings Page

**Files:**
- Create: `lib/pages/deepseek_settings_page.dart`
- Modify: `lib/pages/profile_page.dart`
- Test: `test/pages/deepseek_settings_page_test.dart`

- [ ] **Step 1: Write failing page test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/pages/deepseek_settings_page.dart';
import 'package:talk/services/local_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });

  testWidgets('deepseek settings page saves config', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeepSeekSettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('DeepSeek 配置'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'deepseek-v4-flash'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'sk-test');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final config = await LocalStorage().loadDeepSeekConfig();
    expect(config.apiKey, 'sk-test');
    expect(config.model, 'deepseek-v4-flash');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/pages/deepseek_settings_page_test.dart
```

Expected: FAIL because `DeepSeekSettingsPage` does not exist.

- [ ] **Step 3: Implement settings page**

Create a stateful page with:
- title `DeepSeek 配置`
- first `TextField` for API Key, `obscureText: true`
- second `TextField` for Base URL
- third `TextField` for Model
- `保存` button that calls `LocalStorage().saveDeepSeekConfig(...)`
- `测试` button can call `DeepSeekQuickExtractService.extract(...)` with a fixed short prompt and show SnackBar; keep test focused on saving.

- [ ] **Step 4: Add profile entry**

In `lib/pages/profile_page.dart`, import `deepseek_settings_page.dart` and add a profile item near `语音播报`:

```dart
_buildProfileItem(
  isDark: isDark,
  icon: Icons.smart_toy_outlined,
  label: 'DeepSeek 配置',
  value: '快速提取使用的大模型',
  onTap: _saving
      ? null
      : () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DeepSeekSettingsPage()),
          ),
),
```

- [ ] **Step 5: Run page test**

Run:

```bash
flutter test test/pages/deepseek_settings_page_test.dart
```

Expected: PASS.

---

### Task 5: Room Quick Extract Prompt Editor

**Files:**
- Modify: `lib/pages/room_info_page.dart`
- Test: extend existing `test/widgets/room_info_page_test.dart` if it can instantiate RoomInfoPage; otherwise cover storage in Task 2 and manually verify this UI.

- [ ] **Step 1: Add editor method**

Add method patterned after `_editRoomNote()`:

```dart
Future<void> _editQuickExtractPrompt() async {
  final initial = await LocalStorage().getRoomQuickExtractPrompt(widget.room.id);
  if (!mounted) return;
  final controller = TextEditingController(text: initial);
  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('快速提取提示词'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            maxLines: 12,
            minLines: 5,
            decoration: const InputDecoration(
              hintText: '例如：请将所给内容中的表格的第一列服务名称单独给出可以复制的选项。',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await LocalStorage().saveRoomQuickExtractPrompt(widget.room.id, controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('快速提取提示词已保存')),
      );
    }
  } finally {
    controller.dispose();
  }
}
```

- [ ] **Step 2: Add RoomInfoPage list item**

Add an item near `房间提示`:

```dart
ListTile(
  leading: const Icon(Icons.auto_fix_high_outlined),
  title: const Text('快速提取提示词'),
  subtitle: const Text('点击输入每个房间自己的提取规则'),
  onTap: _editQuickExtractPrompt,
),
```

- [ ] **Step 3: Run room info tests if present**

Run:

```bash
flutter test test/widgets/room_info_page_test.dart
```

Expected: PASS, or document if this test cannot cover the page due Matrix fixture limits.

---

### Task 6: ChatPage Quick Extract Button And Flow

**Files:**
- Modify: `lib/pages/chat_page.dart`
- Test: add focused pure helper test if practical, otherwise cover service/storage and run ChatPage widget tests.

- [ ] **Step 1: Add helper to find latest incoming text**

Add a private method in `_ChatPageState`:

```dart
Event? _latestIncomingTextEvent() {
  final myId = widget.room.client.userID;
  final events = timelineMessagesForDisplay(_timeline?.events ?? const []);
  for (var i = events.length - 1; i >= 0; i--) {
    final event = events[i];
    if (event.senderId == myId) continue;
    if (event.type != EventTypes.Message) continue;
    final text = event.body.trim();
    if (text.isEmpty) continue;
    return event;
  }
  return null;
}
```

- [ ] **Step 2: Add insert behavior**

Add:

```dart
void _insertQuickExtractValue(String value) {
  final current = _messageController.text;
  final selection = _messageController.selection;
  final insert = current.trim().isEmpty ? value : '\n$value';
  final start = selection.isValid ? selection.start : current.length;
  final end = selection.isValid ? selection.end : current.length;
  final next = current.replaceRange(start, end, insert);
  final cursor = start + insert.length;
  _messageController.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: cursor),
  );
  _onComposerTextChanged(next);
}
```

- [ ] **Step 3: Add quick extract action**

Add:

```dart
Future<void> _runQuickExtract() async {
  final config = await LocalStorage().loadDeepSeekConfig();
  if (!config.isConfigured) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先在个人资料页配置 DeepSeek')),
    );
    return;
  }
  final prompt = await LocalStorage().getRoomQuickExtractPrompt(widget.room.id);
  if (prompt.trim().isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先在房间设置中配置快速提取提示词')),
    );
    return;
  }
  final event = _latestIncomingTextEvent();
  if (event == null) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('没有可提取的对方文本消息')),
    );
    return;
  }
  try {
    final items = await DeepSeekQuickExtractService().extract(
      config: config,
      roomPrompt: prompt,
      markdown: event.body,
    );
    if (!mounted) return;
    await _showQuickExtractCandidates(items);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('快速提取失败: $e')),
    );
  }
}
```

- [ ] **Step 4: Add bottom sheet**

Add:

```dart
Future<void> _showQuickExtractCandidates(List<QuickExtractCandidate> items) async {
  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('未提取到选项')),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, index) {
          final item = items[index];
          return ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: Text(item.label),
            subtitle: item.value == item.label ? null : Text(item.value),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: item.value));
              if (!mounted) return;
              Navigator.pop(ctx);
              _insertQuickExtractValue(item.value);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制并插入输入框')),
              );
            },
          );
        },
      ),
    ),
  );
}
```

- [ ] **Step 5: Add toolbar icon above collapsed input**

Refactor `_buildCollapsedComposer` so the expanded input area contains:

```dart
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    SizedBox(
      height: 36,
      child: Row(
        children: [
          IconButton(
            tooltip: '快速提取',
            icon: const Icon(Icons.auto_fix_high_outlined),
            onPressed: _uploadingMedia ? null : () => unawaited(_runQuickExtract()),
          ),
        ],
      ),
    ),
    TextField(
      controller: _messageController,
      minLines: 2,
      maxLines: 2,
      ...
    ),
  ],
)
```

Keep the right-side Markdown and Send buttons unchanged.

- [ ] **Step 6: Run targeted chat/composer tests**

Run:

```bash
flutter test test/widgets/composer/mobile_markdown_composer_test.dart test/widgets/composer/markdown_composer_toolbar_test.dart
```

Expected: PASS.

---

### Task 7: Final Verification

**Files:**
- All files touched above.

- [ ] **Step 1: Format**

Run:

```bash
dart format lib/quick_extract lib/pages/deepseek_settings_page.dart lib/pages/profile_page.dart lib/pages/room_info_page.dart lib/pages/chat_page.dart lib/services/local_storage.dart test/quick_extract test/pages/deepseek_settings_page_test.dart test/services/local_storage_quick_extract_test.dart
```

Expected: exits 0.

- [ ] **Step 2: Analyze**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Run targeted tests**

Run:

```bash
flutter test test/quick_extract test/services/local_storage_quick_extract_test.dart test/pages/deepseek_settings_page_test.dart test/widgets/composer/mobile_markdown_composer_test.dart test/widgets/composer/markdown_composer_toolbar_test.dart
```

Expected: all tests pass.

- [ ] **Step 4: Manual smoke test on device/emulator**

Steps:
1. Open personal profile, configure DeepSeek API Key, keep model `deepseek-v4-flash`.
2. Open a room, set quick extract prompt: `请将所给内容中的表格的第一列服务名称单独给出可以复制的选项。`
3. Ensure the latest incoming message contains a Markdown table.
4. Tap the quick extract icon above the input.
5. Confirm bottom sheet shows candidates.
6. Tap one candidate.
7. Confirm the value is copied to clipboard and inserted into the input box on a new line if text already exists.

Expected: no crash, correct candidate insertion, SnackBar confirms completion.

---

## Self-Review

- Spec coverage: global DeepSeek config, per-room prompt, latest incoming text, JSON response, bottom sheet, copy plus insert, and edge cases are covered.
- Placeholder scan: no TBD/TODO steps remain.
- Type consistency: `DeepSeekConfig`, `QuickExtractCandidate`, `DeepSeekQuickExtractService.extract`, and `LocalStorage` method names are consistent across tasks.

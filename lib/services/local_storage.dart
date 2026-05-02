import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../media/media_preview_sizes.dart';

/// 本地持久化存储 — 登录偏好、草稿等
class LocalStorage {
  static final LocalStorage _instance = LocalStorage._();
  factory LocalStorage() => _instance;
  LocalStorage._();

  static const _keyServerUrl = 'login_server_url';
  static const _keyUsername = 'login_username';

  /// Same prefix as talkweb `KEY_DRAFT_PREFIX`.
  static const _keyDraftPrefixTalkweb = 'talkweb_draft_';

  /// Legacy drafts written by earlier Flutter builds.
  static const _keyDraftPrefixLegacy = 'draft_';

  /// Same string as talkweb `KEY_PINNED_ROOMS`.
  static const _keyPinnedRooms = 'talkweb_pinned_rooms';
  static const _keyPinnedRoomsLegacy = 'talk_pinned_rooms';

  /// Same string as talkweb `KEY_THEME`; values `light` / `dark` / `system` (web persists light/dark only).
  static const _keyTheme = 'talkweb_theme';
  static const _keyThemeLegacy = 'talk_theme';

  /// Same key as talkweb `KEY_COMPOSER_HEIGHT_PCT` (stored as int percent).
  static const _keyComposerHeightPct = 'talkweb_composer_height_pct';
  static const _keyComposerHeightPctLegacy = 'talk_composer_height_pct';

  /// 全局字体档位（相对「标准」每档约 ±10%），与 talkweb 无关，仅 Flutter 端。
  static const _keyTextScaleStep = 'talk_text_scale_step';

  /// 聊天气泡内 Markdown 收起态最大高度（占屏幕高度百分比），仅 Flutter。
  static const _keyBubbleMaxHeightPct = 'talk_bubble_max_height_pct';

  /// 插入聊天（R2 / Matrix）前是否压缩位图图片；默认开启。
  static const _keyCompressUploadImages = 'talk_compress_upload_images';

  static const _keyBubbleMediaPreviewSizes =
      'talk_bubble_media_preview_sizes_v1';
  static const _keyTableMediaPreviewSizes = 'talk_table_media_preview_sizes_v1';
  static const _keyRoomQuickExtractPromptPrefix =
      'talk_room_quick_extract_prompt_';

  /// 按房间保存的「聊天提示备注」（仅本机，与 Matrix 无关）。
  static const _keyRoomNotePrefix = 'talk_room_note_';

  /// 按房间保存的「长消息是否自动折叠」；缺省为开启。
  static const _keyRoomAutoCollapsePrefix = 'talk_room_auto_collapse_';

  /// Defaults match `talkweb/src/storage/prefs.ts`.
  static const int defaultComposerHeightPct = 50;
  static const int minComposerHeightPct = 28;
  static const int maxComposerHeightPct = 78;

  static const int defaultBubbleMaxHeightPct = 35;
  static const int minBubbleMaxHeightPct = 12;
  static const int maxBubbleMaxHeightPct = 80;

  static const bool defaultCompressUploadImages = true;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Clears the in-memory prefs handle (for tests after
  /// [SharedPreferences.setMockInitialValues]).
  void resetPrefsCacheForTest() {
    _prefs = null;
  }

  Future<void> _migratePinnedRoomsIfNeeded(SharedPreferences prefs) async {
    if (prefs.containsKey(_keyPinnedRooms)) return;
    final legacy = prefs.getString(_keyPinnedRoomsLegacy);
    if (legacy != null) {
      await prefs.setString(_keyPinnedRooms, legacy);
      await prefs.remove(_keyPinnedRoomsLegacy);
    }
  }

  Future<void> _migrateThemeIfNeeded(SharedPreferences prefs) async {
    if (prefs.containsKey(_keyTheme)) return;
    final legacy = prefs.getString(_keyThemeLegacy);
    if (legacy != null) {
      await prefs.setString(_keyTheme, legacy);
      await prefs.remove(_keyThemeLegacy);
    }
  }

  Future<void> _migrateComposerHeightPctIfNeeded(
    SharedPreferences prefs,
  ) async {
    if (prefs.containsKey(_keyComposerHeightPct)) return;
    final legacy = prefs.getInt(_keyComposerHeightPctLegacy);
    if (legacy != null) {
      await prefs.setInt(
        _keyComposerHeightPct,
        legacy.clamp(minComposerHeightPct, maxComposerHeightPct),
      );
      await prefs.remove(_keyComposerHeightPctLegacy);
    }
  }

  // ========== 登录偏好 ==========

  /// 保存登录偏好
  Future<void> saveLoginPrefs({
    required String serverUrl,
    required String username,
  }) async {
    final prefs = await _preferences;
    await prefs.setString(_keyServerUrl, serverUrl);
    await prefs.setString(_keyUsername, username);
  }

  /// 获取上次使用的服务器地址
  Future<String> getServerUrl() async {
    final prefs = await _preferences;
    return prefs.getString(_keyServerUrl) ?? 'http://localhost:6167';
  }

  /// 获取上次使用的用户名
  Future<String> getUsername() async {
    final prefs = await _preferences;
    return prefs.getString(_keyUsername) ?? '';
  }

  // ========== 消息草稿 ==========

  /// 保存指定房间的草稿
  Future<void> saveDraft(String roomId, String text) async {
    final prefs = await _preferences;
    final tw = '$_keyDraftPrefixTalkweb$roomId';
    final leg = '$_keyDraftPrefixLegacy$roomId';
    if (text.isEmpty) {
      await prefs.remove(tw);
      await prefs.remove(leg);
    } else {
      await prefs.setString(tw, text);
      await prefs.remove(leg);
    }
  }

  /// 读取指定房间的草稿
  Future<String> getDraft(String roomId) async {
    final prefs = await _preferences;
    final tw = '$_keyDraftPrefixTalkweb$roomId';
    final leg = '$_keyDraftPrefixLegacy$roomId';
    final primary = prefs.getString(tw);
    if (primary != null) return primary;
    final migrated = prefs.getString(leg);
    if (migrated != null) {
      await prefs.setString(tw, migrated);
      await prefs.remove(leg);
      return migrated;
    }
    return '';
  }

  /// 清除指定房间的草稿
  Future<void> clearDraft(String roomId) async {
    final prefs = await _preferences;
    await prefs.remove('$_keyDraftPrefixTalkweb$roomId');
    await prefs.remove('$_keyDraftPrefixLegacy$roomId');
  }

  // ========== 置顶房间 ==========

  /// 读取置顶房间 ID 列表（有序）；默认空列表
  Future<List<String>> loadPinnedRoomIds() async {
    final prefs = await _preferences;
    await _migratePinnedRoomsIfNeeded(prefs);
    final raw = prefs.getString(_keyPinnedRooms);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 保存置顶房间 ID 列表（JSON 数组）
  Future<void> savePinnedRoomIds(List<String> ids) async {
    final prefs = await _preferences;
    await prefs.setString(_keyPinnedRooms, jsonEncode(ids));
  }

  // ========== 主题（talkweb_theme：light / dark / system）==========

  /// 读取保存的主题；缺省或未知值返回 [ThemeMode.system]。
  Future<ThemeMode> loadThemeMode() async {
    final prefs = await _preferences;
    await _migrateThemeIfNeeded(prefs);
    final raw = prefs.getString(_keyTheme);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _preferences;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_keyTheme, value);
  }

  // ========== Composer 高度（对齐 talkweb `loadComposerHeightPct`）==========

  Future<int> loadComposerHeightPct() async {
    final prefs = await _preferences;
    await _migrateComposerHeightPctIfNeeded(prefs);
    final v = prefs.getInt(_keyComposerHeightPct);
    if (v == null) return defaultComposerHeightPct;
    return v.clamp(minComposerHeightPct, maxComposerHeightPct);
  }

  Future<void> saveComposerHeightPct(int pct) async {
    final prefs = await _preferences;
    final n = pct.clamp(minComposerHeightPct, maxComposerHeightPct);
    await prefs.setInt(_keyComposerHeightPct, n);
  }

  // ========== 全局字体缩放（仅 App）==========

  static const int minTextScaleStep = -4;
  static const int maxTextScaleStep = 4;

  /// 未设置时返回 0（标准）。
  Future<int> loadTextScaleStep() async {
    final prefs = await _preferences;
    final v = prefs.getInt(_keyTextScaleStep);
    if (v == null) return 0;
    return v.clamp(minTextScaleStep, maxTextScaleStep);
  }

  Future<void> saveTextScaleStep(int step) async {
    final prefs = await _preferences;
    final n = step.clamp(minTextScaleStep, maxTextScaleStep);
    await prefs.setInt(_keyTextScaleStep, n);
  }

  // ========== 聊天气泡 Markdown 最大高度（屏幕高度 %）==========

  Future<int> loadBubbleMaxHeightPct() async {
    final prefs = await _preferences;
    final v = prefs.getInt(_keyBubbleMaxHeightPct);
    if (v == null) return defaultBubbleMaxHeightPct;
    return v.clamp(minBubbleMaxHeightPct, maxBubbleMaxHeightPct);
  }

  Future<void> saveBubbleMaxHeightPct(int pct) async {
    final prefs = await _preferences;
    final n = pct.clamp(minBubbleMaxHeightPct, maxBubbleMaxHeightPct);
    await prefs.setInt(_keyBubbleMaxHeightPct, n);
  }

  // ========== 聊天图片压缩上传 ==========

  /// 未设置时返回 [defaultCompressUploadImages]（开启压缩）。
  Future<bool> loadCompressUploadImages() async {
    final prefs = await _preferences;
    return prefs.getBool(_keyCompressUploadImages) ??
        defaultCompressUploadImages;
  }

  Future<void> saveCompressUploadImages(bool enabled) async {
    final prefs = await _preferences;
    await prefs.setBool(_keyCompressUploadImages, enabled);
  }

  // ========== Markdown 媒体预览尺寸 ==========

  Future<MediaPreviewSizes> loadBubbleMediaPreviewSizes() async {
    return _loadMediaPreviewSizes(
      key: _keyBubbleMediaPreviewSizes,
      defaults: MediaPreviewSizes.bubbleDefaults,
    );
  }

  Future<void> saveBubbleMediaPreviewSizes(MediaPreviewSizes sizes) async {
    await _saveMediaPreviewSizes(
      key: _keyBubbleMediaPreviewSizes,
      sizes: sizes,
    );
  }

  Future<MediaPreviewSizes> loadTableMediaPreviewSizes() async {
    return _loadMediaPreviewSizes(
      key: _keyTableMediaPreviewSizes,
      defaults: MediaPreviewSizes.tableDefaults,
    );
  }

  Future<void> saveTableMediaPreviewSizes(MediaPreviewSizes sizes) async {
    await _saveMediaPreviewSizes(key: _keyTableMediaPreviewSizes, sizes: sizes);
  }

  Future<MediaPreviewSizes> _loadMediaPreviewSizes({
    required String key,
    required MediaPreviewSizes defaults,
  }) async {
    final prefs = await _preferences;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return defaults;
    try {
      return MediaPreviewSizes.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        defaults,
      );
    } catch (_) {
      return defaults;
    }
  }

  Future<void> _saveMediaPreviewSizes({
    required String key,
    required MediaPreviewSizes sizes,
  }) async {
    final prefs = await _preferences;
    await prefs.setString(key, jsonEncode(sizes.clamp().toJson()));
  }

  // ========== 房间提示备注（聊天页只读展示，房间信息页编辑）==========

  static String _roomNoteKey(String roomId) => '$_keyRoomNotePrefix$roomId';

  Future<String> getRoomNote(String roomId) async {
    final prefs = await _preferences;
    return prefs.getString(_roomNoteKey(roomId)) ?? '';
  }

  Future<void> saveRoomNote(String roomId, String text) async {
    final prefs = await _preferences;
    final key = _roomNoteKey(roomId);
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, text);
    }
  }

  // ========== 房间快速提取提示词（仅本机）==========

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

  // ========== 房间长消息自动折叠（仅本机）==========

  static String _roomAutoCollapseKey(String roomId) =>
      '$_keyRoomAutoCollapsePrefix$roomId';

  /// 未设置时默认开启自动折叠。
  Future<bool> loadRoomAutoCollapseEnabled(String roomId) async {
    final prefs = await _preferences;
    return prefs.getBool(_roomAutoCollapseKey(roomId)) ?? true;
  }

  Future<void> saveRoomAutoCollapseEnabled(String roomId, bool enabled) async {
    final prefs = await _preferences;
    await prefs.setBool(_roomAutoCollapseKey(roomId), enabled);
  }

  // ========== 清理 ==========

  /// 登出时清除所有偏好
  Future<void> clearAll() async {
    final prefs = await _preferences;
    // 只清除草稿，保留登录偏好（方便重新登录）
    final keys = prefs.getKeys().where(
      (k) =>
          k.startsWith(_keyDraftPrefixTalkweb) ||
          k.startsWith(_keyDraftPrefixLegacy),
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

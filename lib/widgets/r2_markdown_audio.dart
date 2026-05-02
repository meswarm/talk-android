import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../r2/r2_service.dart';
import '../theme/app_colors.dart';
import 'markdown_image_frame.dart';
import 'r2_markdown_card_shell.dart';

/// 聊天气泡内 `r2://` 音频：小播放按钮 + 可拖动 / 点击跳转的进度条 + 单行标题。
class R2MarkdownAudio extends StatefulWidget {
  final R2Service r2;
  final String ref;
  final String title;
  final bool isDark;
  final double maxImageHeight;
  final double? cardHeight;
  final double? maxImageWidth;
  final VoidCallback? onDelete;

  const R2MarkdownAudio({
    super.key,
    required this.r2,
    required this.ref,
    required this.title,
    required this.isDark,
    this.maxImageHeight = 220,
    this.cardHeight,
    this.maxImageWidth,
    this.onDelete,
  });

  @override
  State<R2MarkdownAudio> createState() => _R2MarkdownAudioState();
}

class _R2MarkdownAudioState extends State<R2MarkdownAudio> {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subs = [];

  bool _loading = false;
  String? _error;
  String? _cachedFilePath;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _state = PlayerState.stopped;

  String get _displayTitle {
    var t = widget.title.trim();
    t = _stripAudioSuffix(t);
    return t.isEmpty ? '音频' : t;
  }

  /// 全角 / 半角「音频」后缀（与编辑器里实际插入的文案一致）。
  static String _stripAudioSuffix(String t) {
    const full = '（音频）';
    const half = '(音频)';
    if (t.endsWith(full)) {
      return t.substring(0, t.length - full.length).trim();
    }
    if (t.endsWith(half)) {
      return t.substring(0, t.length - half.length).trim();
    }
    return t;
  }

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    final p = _player!;
    _subs.add(
      p.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      }),
    );
    _subs.add(
      p.onPositionChanged.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }),
    );
    _subs.add(
      p.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _state = s);
      }),
    );
    _subs.add(
      p.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _position = Duration.zero;
          _state = PlayerState.completed;
        });
      }),
    );
  }

  @override
  void didUpdateWidget(R2MarkdownAudio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ref != widget.ref ||
        oldWidget.r2.session != widget.r2.session) {
      unawaited(_resetForNewRef());
    }
  }

  Future<void> _resetForNewRef() async {
    _cachedFilePath = null;
    final p = _player;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _duration = Duration.zero;
        _position = Duration.zero;
        _error = null;
        _loading = false;
        _state = PlayerState.stopped;
      });
    }
  }

  Future<void> _togglePlay() async {
    if (widget.r2.session == null) {
      setState(() => _error = '解锁 R2 后可播放此音频');
      return;
    }
    final p = _player;
    if (p == null) return;

    try {
      if (_cachedFilePath == null) {
        setState(() {
          _loading = true;
          _error = null;
        });
        final filePath = await widget.r2.fetchRefFile(widget.ref);
        _cachedFilePath = filePath;
        await p.play(DeviceFileSource(filePath));
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (_state == PlayerState.playing) {
        await p.pause();
      } else {
        if (_state == PlayerState.completed || _state == PlayerState.stopped) {
          await p.play(DeviceFileSource(_cachedFilePath!));
        } else {
          await p.resume();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _seekToFraction(double fraction) async {
    final p = _player;
    if (p == null || _duration <= Duration.zero) return;
    final ms = (_duration.inMilliseconds * fraction).round().clamp(
      0,
      _duration.inMilliseconds,
    );
    final target = Duration(milliseconds: ms);
    try {
      await p.seek(target);
      if (mounted) setState(() => _position = target);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    final p = _player;
    _player = null;
    if (p != null) {
      unawaited(p.dispose());
    }
    super.dispose();
  }

  double get _progress {
    final d = _duration.inMilliseconds;
    if (d <= 0) return 0;
    return (_position.inMilliseconds.clamp(0, d)) / d;
  }

  bool get _canSeek =>
      !_loading &&
      _duration > Duration.zero &&
      _player != null &&
      _error == null;

  @override
  Widget build(BuildContext context) {
    final sub = widget.isDark
        ? const Color(0xFF9E9E9E)
        : const Color(0xFF616161);
    final track = widget.isDark ? Colors.white24 : Colors.black26;
    final fill = widget.isDark ? const Color(0xFF6CB6FF) : AppColors.primary;
    final cardHeight = (widget.cardHeight ?? 64).clamp(36.0, 120.0);
    final cardWidth = widget.maxImageWidth?.clamp(96.0, 420.0).toDouble();
    final compact = cardHeight <= 48;
    final verticalPad = compact ? 4.0 : 8.0;
    final iconBox = (cardHeight - verticalPad * 2).clamp(28.0, 40.0);
    final iconSize = iconBox.clamp(22.0, 28.0);
    final progressHeight = compact ? 16.0 : 28.0;
    final titleFontSize = compact ? 12.0 : 13.0;

    if (_error != null) {
      return Text(
        '[R2 音频: $_error]',
        style: TextStyle(fontSize: 13, color: sub),
      );
    }

    final playing = _state == PlayerState.playing;
    final icon = _loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.isDark ? Colors.white54 : AppColors.primary,
            ),
          )
        : Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: iconSize,
            color: widget.isDark
                ? const Color(0xFFE0E0E0)
                : const Color(0xFF111111),
          );

    return R2MarkdownCardShell(
      onDelete: widget.onDelete,
      child: MarkdownImageFrame(
        isDark: widget.isDark,
        maxHeight: cardHeight,
        maxWidth: widget.maxImageWidth ?? double.infinity,
        child: Material(
          color: widget.isDark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFF3F4F6),
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: verticalPad,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: iconBox,
                    height: iconBox,
                    child: InkWell(
                      onTap: _loading ? null : () => unawaited(_togglePlay()),
                      child: Center(
                        child: IconTheme(
                          data: IconThemeData(size: iconSize),
                          child: icon,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: progressHeight,
                          child: LayoutBuilder(
                            builder: (context, cons) {
                              final w = cons.maxWidth;
                              if (w <= 0) {
                                return const SizedBox.shrink();
                              }
                              void seekFromDx(double dx) {
                                if (!_canSeek) return;
                                unawaited(
                                  _seekToFraction((dx / w).clamp(0.0, 1.0)),
                                );
                              }

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: _canSeek
                                    ? (d) => seekFromDx(d.localPosition.dx)
                                    : null,
                                onHorizontalDragUpdate: _canSeek
                                    ? (d) => seekFromDx(d.localPosition.dx)
                                    : null,
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      // `value == null` 会触发不确定态的循环动画；未拿到时长时用 0 保持静态底轨。
                                      value: _duration > Duration.zero
                                          ? _progress
                                          : 0,
                                      minHeight: 5,
                                      backgroundColor: track,
                                      color: fill,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: compact ? 1 : 6),
                        Text(
                          _displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            height: 1.2,
                            color: widget.isDark
                                ? const Color(0xFFE0E0E0)
                                : const Color(0xFF111111),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

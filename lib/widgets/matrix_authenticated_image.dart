import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../theme/app_colors.dart';

/// 圆角半径；设为 0 即为直角正方形。
const double kMatrixAvatarBorderRadius = 4;

/// Matrix 媒体/头像 HTTP 地址通常需要 `Authorization: Bearer`（见 matrix SDK
/// [MxcUriExtension.getDownloadUri] 文档）。普通 [NetworkImage] 无法带此头，会导致 401、头像不显示。
class MatrixAuthenticatedImage extends StatelessWidget {
  final Uri uri;
  final Client client;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const MatrixAuthenticatedImage({
    super.key,
    required this.uri,
    required this.client,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  static Map<String, String>? _headers(Client client) {
    final t = client.accessToken;
    if (t == null || t.isEmpty) return null;
    return {'Authorization': 'Bearer $t'};
  }

  @override
  Widget build(BuildContext context) {
    final headers = _headers(client);
    if (headers == null) {
      return SizedBox(
        width: width,
        height: height,
        child: errorBuilder?.call(
              context,
              StateError('No access token'),
              null,
            ) ??
            const SizedBox.shrink(),
      );
    }
    return Image.network(
      uri.toString(),
      headers: headers,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );
  }
}

class _SquarePlaceholder extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final double borderRadius;
  final Widget child;

  const _SquarePlaceholder({
    required this.size,
    required this.backgroundColor,
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// 圆角正方形头像（Matrix 鉴权下载）。
class MatrixAuthenticatedSquareAvatar extends StatelessWidget {
  final Uri? uri;
  final Client client;
  final double size;
  final Color backgroundColor;
  final Widget fallback;
  final double borderRadius;

  const MatrixAuthenticatedSquareAvatar({
    super.key,
    required this.uri,
    required this.client,
    required this.size,
    required this.backgroundColor,
    required this.fallback,
    this.borderRadius = kMatrixAvatarBorderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final u = uri;
    final t = client.accessToken;
    final br = borderRadius;
    if (u == null || t == null || t.isEmpty) {
      return _SquarePlaceholder(
        size: size,
        backgroundColor: backgroundColor,
        borderRadius: br,
        child: fallback,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(br),
        child: MatrixAuthenticatedImage(
          uri: u,
          client: client,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _SquarePlaceholder(
            size: size,
            backgroundColor: backgroundColor,
            borderRadius: br,
            child: fallback,
          ),
        ),
      ),
    );
  }
}

/// 房间头像：有 `m.room.avatar` 或 DM 对方头像时拉取，否则首字占位。
class RoomSquareAvatar extends StatefulWidget {
  final Room room;
  final double size;
  final Color? backgroundColor;
  final double borderRadius;

  const RoomSquareAvatar({
    super.key,
    required this.room,
    required this.size,
    this.backgroundColor,
    this.borderRadius = kMatrixAvatarBorderRadius,
  });

  @override
  State<RoomSquareAvatar> createState() => _RoomSquareAvatarState();
}

class _RoomSquareAvatarState extends State<RoomSquareAvatar> {
  Uri? _uri;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RoomSquareAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id ||
        oldWidget.room.avatar != widget.room.avatar) {
      _uri = null;
      _load();
    }
  }

  Future<void> _load() async {
    final av = widget.room.avatar;
    if (av == null) {
      if (mounted) setState(() => _uri = null);
      return;
    }
    try {
      final u = await av.getDownloadUri(widget.room.client);
      if (mounted) setState(() => _uri = u);
    } catch (_) {
      if (mounted) setState(() => _uri = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.room.getLocalizedDisplayname();
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final bg =
        widget.backgroundColor ?? AppColors.primary.withValues(alpha: 0.15);
    return MatrixAuthenticatedSquareAvatar(
      uri: _uri,
      client: widget.room.client,
      size: widget.size,
      borderRadius: widget.borderRadius,
      backgroundColor: bg,
      fallback: Text(
        letter,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: (widget.size * 0.42).clamp(10, 22),
        ),
      ),
    );
  }
}

/// 成员头像（房间内 User 状态）。
class UserSquareAvatar extends StatefulWidget {
  final User user;
  final double size;
  final Color? backgroundColor;
  final double borderRadius;

  const UserSquareAvatar({
    super.key,
    required this.user,
    required this.size,
    this.backgroundColor,
    this.borderRadius = kMatrixAvatarBorderRadius,
  });

  @override
  State<UserSquareAvatar> createState() => _UserSquareAvatarState();
}

class _UserSquareAvatarState extends State<UserSquareAvatar> {
  Uri? _uri;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UserSquareAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _uri = null;
      _load();
    }
  }

  Future<void> _load() async {
    final av = widget.user.avatarUrl;
    if (av == null) {
      if (mounted) setState(() => _uri = null);
      return;
    }
    try {
      final u = await av.getDownloadUri(widget.user.room.client);
      if (mounted) setState(() => _uri = u);
    } catch (_) {
      if (mounted) setState(() => _uri = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.user.calcDisplayname();
    final letter = label.isNotEmpty ? label.substring(0, 1).toUpperCase() : '?';
    final bg =
        widget.backgroundColor ?? AppColors.primary.withValues(alpha: 0.15);
    return MatrixAuthenticatedSquareAvatar(
      uri: _uri,
      client: widget.user.room.client,
      size: widget.size,
      borderRadius: widget.borderRadius,
      backgroundColor: bg,
      fallback: Text(
        letter,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: (widget.size * 0.42).clamp(10, 22),
        ),
      ),
    );
  }
}

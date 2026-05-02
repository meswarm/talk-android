import 'package:flutter/material.dart';

class ChatVideoPreviewCard extends StatelessWidget {
  const ChatVideoPreviewCard({
    super.key,
    required this.child,
    required this.duration,
    required this.onPlay,
  });

  final Widget child;
  final Duration duration;
  final VoidCallback onPlay;

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Colors.black26),
            ),
          ),
          IconButton(
            iconSize: 58,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black45,
              foregroundColor: Colors.white,
            ),
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _format(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

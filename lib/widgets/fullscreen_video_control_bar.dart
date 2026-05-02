import 'package:flutter/material.dart';

class FullscreenVideoControlBar extends StatelessWidget {
  const FullscreenVideoControlBar({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.progressValue,
    required this.onPlayPause,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double progressValue;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.56)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            IconButton(
              onPressed: onPlayPause,
              color: Colors.white,
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            Text(_format(position), style: const TextStyle(color: Colors.white)),
            Expanded(
              child: Slider(
                value: progressValue,
                onChanged: onChanged,
                onChangeStart: onChangeStart,
                onChangeEnd: onChangeEnd,
              ),
            ),
            Text(_format(duration), style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

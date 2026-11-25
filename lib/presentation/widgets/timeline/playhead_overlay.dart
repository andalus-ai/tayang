import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/playback_controller.dart';
import '../../../core/theme/app_theme.dart';
import 'timeline_geometry.dart';

/// Vertical playhead line. Must be a child of the timeline's content `Stack`.
class PlayheadOverlay extends ConsumerWidget {
  const PlayheadOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geo = TimelineScope.of(context);
    final position = ref.watch(playbackProvider.select((s) => s.position));
    final dx = geo.scale.toDx(position);

    return Positioned(
      left: dx - 6,
      top: 0,
      bottom: 0,
      width: 12,
      child: IgnorePointer(
        child: Column(
          children: [
            CustomPaint(size: const Size(12, 10), painter: _HeadPainter()),
            Expanded(child: Container(width: 2, color: AppColors.playhead)),
          ],
        ),
      ),
    );
  }
}

class _HeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.playhead);
  }

  @override
  bool shouldRepaint(_HeadPainter old) => false;
}

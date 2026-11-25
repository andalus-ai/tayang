import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/playback_controller.dart';
import '../../../core/theme/app_theme.dart';
import 'timeline_geometry.dart';

/// Time ruler. Tap or drag on it to scrub.
class TimelineRuler extends ConsumerWidget {
  const TimelineRuler({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geo = TimelineScope.of(context);
    void seek(double dx) =>
        ref.read(playbackProvider.notifier).seek(geo.scale.toTime(dx));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => seek(d.localPosition.dx),
      onHorizontalDragStart: (d) => seek(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
      child: CustomPaint(
        size: Size(width, geo.rulerHeight),
        painter: _RulerPainter(geo.scale.pixelsPerSecond),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.pps);

  final double pps;

  static const _steps = [0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 300.0, 600.0];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.surfaceHigh);

    final step = _steps.firstWhere((s) => s * pps >= 80, orElse: () => _steps.last);
    final minor = step / 5;
    final major = Paint()
      ..color = AppColors.mutedText
      ..strokeWidth = 1;
    final small = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;

    final count = (size.width / pps / minor).ceil();
    for (var i = 0; i <= count; i++) {
      final x = i * minor * pps;
      final isMajor = i % 5 == 0;
      canvas.drawLine(
        Offset(x, size.height - (isMajor ? 12 : 6)),
        Offset(x, size.height),
        isMajor ? major : small,
      );
      if (isMajor) _label(canvas, _format(i * minor, step), Offset(x + 4, 3));
    }
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), small);
  }

  String _format(double seconds, double step) {
    final m = seconds ~/ 60;
    final s = seconds - m * 60;
    final secText = step < 1
        ? s.toStringAsFixed(1).padLeft(4, '0')
        : s.round().toString().padLeft(2, '0');
    return '$m:$secText';
  }

  void _label(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.pps != pps;
}

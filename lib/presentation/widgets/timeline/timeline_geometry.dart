import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Pixel ↔ time conversion at the current zoom level.
class TimelineScale {
  const TimelineScale(this.pixelsPerSecond);

  final double pixelsPerSecond;

  double toDx(Duration d) =>
      d.inMicroseconds / Duration.microsecondsPerSecond * pixelsPerSecond;

  Duration toTime(double dx) => Duration(
      microseconds: (dx / pixelsPerSecond * Duration.microsecondsPerSecond).round());
}

/// Shared layout facts for the ruler, lanes, clips and playhead. [lanesKey]
/// marks the box whose local x=0 is time 0 and local y=0 is the ruler's top, so
/// global pointer positions can be converted to time / lane index anywhere.
class TimelineGeometry {
  const TimelineGeometry({
    required this.scale,
    required this.lanesKey,
    this.rulerHeight = 28,
    this.laneHeight = 60,
  });

  final TimelineScale scale;
  final GlobalKey lanesKey;
  final double rulerHeight;
  final double laneHeight;

  RenderBox? get _box => lanesKey.currentContext?.findRenderObject() as RenderBox?;

  Duration timeAt(Offset global) {
    final box = _box;
    if (box == null) return Duration.zero;
    final dx = box.globalToLocal(global).dx;
    return dx <= 0 ? Duration.zero : scale.toTime(dx);
  }

  int laneIndexAt(Offset global, int laneCount) {
    final box = _box;
    if (box == null || laneCount <= 0) return 0;
    final dy = box.globalToLocal(global).dy - rulerHeight;
    return math.max(0, math.min(laneCount - 1, (dy / laneHeight).floor()));
  }
}

class TimelineScope extends InheritedWidget {
  const TimelineScope({super.key, required this.geometry, required super.child});

  final TimelineGeometry geometry;

  static TimelineGeometry of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TimelineScope>()!.geometry;

  @override
  bool updateShouldNotify(TimelineScope old) =>
      old.geometry.scale.pixelsPerSecond != geometry.scale.pixelsPerSecond;
}

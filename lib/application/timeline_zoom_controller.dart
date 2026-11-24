import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Timeline zoom in pixels per second.
class TimelineZoomController extends Notifier<double> {
  static const min = 10.0;
  static const max = 400.0;

  @override
  double build() => 80;

  void set(double value) => state = value.clamp(min, max);
  void zoomIn() => set(state * 1.25);
  void zoomOut() => set(state / 1.25);
}

final timelineZoomProvider =
    NotifierProvider<TimelineZoomController, double>(TimelineZoomController.new);

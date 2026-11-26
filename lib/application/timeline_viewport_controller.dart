import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A span of timeline time.
class TimeRange {
  const TimeRange(this.start, this.end);

  final Duration start;
  final Duration end;

  bool overlaps(Duration s, Duration e) => s <= end && e >= start;

  @override
  bool operator ==(Object other) =>
      other is TimeRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// The part of the timeline that is (nearly) on screen. Clips outside it are not
/// built, so very long projects stay fast. Updated by the timeline panel in
/// coarse steps while scrolling/zooming.
class TimelineViewportController extends Notifier<TimeRange> {
  @override
  TimeRange build() => const TimeRange(Duration.zero, Duration(hours: 24));

  void set(TimeRange range) {
    if (range != state) state = range;
  }
}

final timelineViewportProvider =
    NotifierProvider<TimelineViewportController, TimeRange>(TimelineViewportController.new);

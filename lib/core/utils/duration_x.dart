extension DurationX on Duration {
  double get seconds => inMicroseconds / Duration.microsecondsPerSecond;

  Duration clampTo(Duration min, Duration max) {
    if (max < min) return min;
    return this < min ? min : (this > max ? max : this);
  }

  /// `mm:ss.cc`
  String get timecode {
    final ms = inMilliseconds.abs();
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final cs = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }
}

Duration secondsToDuration(double seconds) =>
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());

Duration minDuration(Duration a, Duration b) => a < b ? a : b;
Duration maxDuration(Duration a, Duration b) => a > b ? a : b;

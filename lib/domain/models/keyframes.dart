enum KeyframeProperty { opacity, volume }

class Keyframe {
  const Keyframe(this.time, this.value);

  /// Relative to the owning clip's start.
  final Duration time;
  final double value;

  Map<String, dynamic> toJson() => {'t': time.inMicroseconds, 'v': value};

  factory Keyframe.fromJson(Map<String, dynamic> json) => Keyframe(
        Duration(microseconds: json['t'] as int),
        (json['v'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is Keyframe && other.time == time && other.value == value;

  @override
  int get hashCode => Object.hash(time, value);
}

/// Immutable, time-sorted keyframes with linear interpolation.
class Keyframes {
  const Keyframes([this.points = const []]);

  final List<Keyframe> points;

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  double valueAt(Duration t, double fallback) {
    if (points.isEmpty) return fallback;
    if (t <= points.first.time) return points.first.value;
    if (t >= points.last.time) return points.last.value;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (t <= b.time) {
        final span = (b.time - a.time).inMicroseconds;
        if (span <= 0) return b.value;
        final f = (t - a.time).inMicroseconds / span;
        return a.value + (b.value - a.value) * f;
      }
    }
    return points.last.value;
  }

  /// Adds a keyframe, replacing any existing one within [mergeWithin].
  Keyframes set(Duration time, double value,
      {Duration mergeWithin = const Duration(milliseconds: 40)}) {
    final next = <Keyframe>[
      for (final p in points)
        if ((p.time - time).abs() > mergeWithin) p,
      Keyframe(time, value),
    ]..sort((a, b) => a.time.compareTo(b.time));
    return Keyframes(next);
  }

  Keyframes removeAt(int index) => Keyframes([
        for (var i = 0; i < points.length; i++)
          if (i != index) points[i],
      ]);

  /// Multiplies every keyframe time (used when clip speed changes).
  Keyframes scaleTime(double factor) => isEmpty
      ? this
      : Keyframes([
          for (final p in points)
            Keyframe(
              Duration(microseconds: (p.time.inMicroseconds * factor).round()),
              p.value,
            ),
        ]);

  /// Window `[from, from + length]` re-based to 0, with interpolated boundary
  /// points so the curve is preserved (used by split and trim).
  Keyframes slice(Duration from, Duration length) {
    if (isEmpty) return this;
    final end = from + length;
    final raw = <Keyframe>[
      Keyframe(Duration.zero, valueAt(from, points.first.value)),
      for (final p in points)
        if (p.time > from && p.time < end) Keyframe(p.time - from, p.value),
      Keyframe(length, valueAt(end, points.last.value)),
    ];
    final out = <Keyframe>[];
    for (final k in raw) {
      if (out.isNotEmpty && (k.time - out.last.time).inMilliseconds.abs() < 2) continue;
      out.add(k);
    }
    return Keyframes(out);
  }

  List<Map<String, dynamic>> toJson() => [for (final p in points) p.toJson()];

  factory Keyframes.fromJson(List<dynamic>? json) => Keyframes([
        for (final p in json ?? const <dynamic>[])
          Keyframe.fromJson(p as Map<String, dynamic>),
      ]);

  @override
  bool operator ==(Object other) {
    if (other is! Keyframes || other.points.length != points.length) return false;
    for (var i = 0; i < points.length; i++) {
      if (other.points[i] != points[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(points);
}

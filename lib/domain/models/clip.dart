import 'dart:math' as math;

import 'keyframes.dart';
import 'media_asset.dart';

enum ClipKind { video, audio, image, text }

extension MediaKindClip on MediaKind {
  ClipKind get clipKind => switch (this) {
        MediaKind.video => ClipKind.video,
        MediaKind.audio => ClipKind.audio,
        MediaKind.image => ClipKind.image,
      };
}

/// Styling for a text clip. Position is the normalised centre of the text.
class TextOverlay {
  const TextOverlay({
    this.content = 'Your text',
    this.fontSize = 64,
    this.color = 0xFFFFFFFF,
    this.x = 0.5,
    this.y = 0.85,
  });

  final String content;

  /// In pixels at the project's canvas height.
  final double fontSize;
  final int color;
  final double x;
  final double y;

  TextOverlay copyWith({
    String? content,
    double? fontSize,
    int? color,
    double? x,
    double? y,
  }) =>
      TextOverlay(
        content: content ?? this.content,
        fontSize: fontSize ?? this.fontSize,
        color: color ?? this.color,
        x: x ?? this.x,
        y: y ?? this.y,
      );

  Map<String, dynamic> toJson() => {
        'content': content,
        'fontSize': fontSize,
        'color': color,
        'x': x,
        'y': y,
      };

  factory TextOverlay.fromJson(Map<String, dynamic> json) => TextOverlay(
        content: json['content'] as String,
        fontSize: (json['fontSize'] as num).toDouble(),
        color: json['color'] as int,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is TextOverlay &&
      other.content == content &&
      other.fontSize == fontSize &&
      other.color == color &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(content, fontSize, color, x, y);
}

/// A piece of media (or text) placed on a track.
///
/// [duration] is the length **on the timeline**. The slice of source media it
/// consumes is `duration * speed`, starting at [sourceStart].
class TimelineClip {
  const TimelineClip({
    required this.id,
    required this.kind,
    required this.start,
    required this.duration,
    this.assetId,
    this.sourceStart = Duration.zero,
    this.speed = 1.0,
    this.volume = 1.0,
    this.opacity = 1.0,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.opacityKeys = const Keyframes(),
    this.volumeKeys = const Keyframes(),
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.text,
  });

  final String id;
  final ClipKind kind;
  final String? assetId;
  final Duration start;
  final Duration duration;
  final Duration sourceStart;
  final double speed;
  final double volume;
  final double opacity;
  final Duration fadeIn;
  final Duration fadeOut;
  final Keyframes opacityKeys;
  final Keyframes volumeKeys;

  /// Visual transform: zoom factor and offset as a fraction of the canvas.
  final double scale;
  final double offsetX;
  final double offsetY;
  final TextOverlay? text;

  Duration get end => start + duration;

  bool get isTimeBased => kind == ClipKind.video || kind == ClipKind.audio;

  Duration get sourceDuration =>
      Duration(microseconds: (duration.inMicroseconds * speed).round());

  Duration get sourceEnd => sourceStart + sourceDuration;

  bool containsTime(Duration t) => t >= start && t < end;

  bool get hasTransform => scale != 1.0 || offsetX != 0.0 || offsetY != 0.0;

  bool get isAnimated =>
      hasFades || opacityKeys.isNotEmpty || volumeKeys.isNotEmpty;

  /// Effective opacity at timeline time [t] (keyframes × fades).
  double opacityAt(Duration t) {
    final base = opacityKeys.isEmpty ? opacity : opacityKeys.valueAt(t - start, opacity);
    return (base * fadeFactorAt(t)).clamp(0.0, 1.0).toDouble();
  }

  /// Effective volume at timeline time [t] (keyframes × fades).
  double volumeAt(Duration t) {
    final base = volumeKeys.isEmpty ? volume : volumeKeys.valueAt(t - start, volume);
    return base * fadeFactorAt(t);
  }

  bool get hasFades => fadeIn > Duration.zero || fadeOut > Duration.zero;

  /// 0..1 multiplier for opacity / volume at timeline time [t].
  double fadeFactorAt(Duration t) {
    var factor = 1.0;
    if (fadeIn > Duration.zero) {
      factor = math.min(factor, (t - start).inMicroseconds / fadeIn.inMicroseconds);
    }
    if (fadeOut > Duration.zero) {
      factor = math.min(factor, (end - t).inMicroseconds / fadeOut.inMicroseconds);
    }
    return factor.clamp(0.0, 1.0).toDouble();
  }

  /// Position inside the source media that corresponds to timeline time [t].
  Duration sourcePositionAt(Duration t) => sourceStart +
      Duration(microseconds: ((t - start).inMicroseconds * speed).round());

  TimelineClip copyWith({
    String? id,
    Duration? start,
    Duration? duration,
    Duration? sourceStart,
    double? speed,
    double? volume,
    double? opacity,
    Duration? fadeIn,
    Duration? fadeOut,
    Keyframes? opacityKeys,
    Keyframes? volumeKeys,
    double? scale,
    double? offsetX,
    double? offsetY,
    TextOverlay? text,
  }) =>
      TimelineClip(
        id: id ?? this.id,
        kind: kind,
        assetId: assetId,
        start: start ?? this.start,
        duration: duration ?? this.duration,
        sourceStart: sourceStart ?? this.sourceStart,
        speed: speed ?? this.speed,
        volume: volume ?? this.volume,
        opacity: opacity ?? this.opacity,
        fadeIn: fadeIn ?? this.fadeIn,
        fadeOut: fadeOut ?? this.fadeOut,
        opacityKeys: opacityKeys ?? this.opacityKeys,
        volumeKeys: volumeKeys ?? this.volumeKeys,
        scale: scale ?? this.scale,
        offsetX: offsetX ?? this.offsetX,
        offsetY: offsetY ?? this.offsetY,
        text: text ?? this.text,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'assetId': assetId,
        'start': start.inMicroseconds,
        'duration': duration.inMicroseconds,
        'sourceStart': sourceStart.inMicroseconds,
        'speed': speed,
        'volume': volume,
        'opacity': opacity,
        'fadeIn': fadeIn.inMicroseconds,
        'fadeOut': fadeOut.inMicroseconds,
        'opacityKeys': opacityKeys.toJson(),
        'volumeKeys': volumeKeys.toJson(),
        'scale': scale,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'text': text?.toJson(),
      };

  factory TimelineClip.fromJson(Map<String, dynamic> json) => TimelineClip(
        id: json['id'] as String,
        kind: ClipKind.values.byName(json['kind'] as String),
        assetId: json['assetId'] as String?,
        start: Duration(microseconds: json['start'] as int),
        duration: Duration(microseconds: json['duration'] as int),
        sourceStart: Duration(microseconds: json['sourceStart'] as int),
        speed: (json['speed'] as num).toDouble(),
        volume: (json['volume'] as num).toDouble(),
        opacity: (json['opacity'] as num).toDouble(),
        fadeIn: Duration(microseconds: (json['fadeIn'] as int?) ?? 0),
        fadeOut: Duration(microseconds: (json['fadeOut'] as int?) ?? 0),
        opacityKeys: Keyframes.fromJson(json['opacityKeys'] as List<dynamic>?),
        volumeKeys: Keyframes.fromJson(json['volumeKeys'] as List<dynamic>?),
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.0,
        offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0.0,
        text: json['text'] == null
            ? null
            : TextOverlay.fromJson(json['text'] as Map<String, dynamic>),
      );

  @override
  bool operator ==(Object other) =>
      other is TimelineClip &&
      other.id == id &&
      other.kind == kind &&
      other.assetId == assetId &&
      other.start == start &&
      other.duration == duration &&
      other.sourceStart == sourceStart &&
      other.speed == speed &&
      other.volume == volume &&
      other.opacity == opacity &&
      other.fadeIn == fadeIn &&
      other.fadeOut == fadeOut &&
      other.opacityKeys == opacityKeys &&
      other.volumeKeys == volumeKeys &&
      other.scale == scale &&
      other.offsetX == offsetX &&
      other.offsetY == offsetY &&
      other.text == text;

  @override
  int get hashCode => Object.hash(
      id, kind, assetId, start, duration, sourceStart, speed, volume, opacity, fadeIn, fadeOut, opacityKeys, volumeKeys, scale, offsetX, offsetY, text);
}

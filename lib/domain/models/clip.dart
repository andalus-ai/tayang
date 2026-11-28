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
  int get hashCode => Object.hashAll([
        id, kind, assetId, start, duration, sourceStart, speed, volume, opacity,
        fadeIn, fadeOut, opacityKeys, volumeKeys, scale, offsetX, offsetY,
        brightness, contrast, saturation, rotation, flipH, flipV, text,
      ]);
}

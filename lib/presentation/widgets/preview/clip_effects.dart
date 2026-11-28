import 'package:flutter/widgets.dart';

import '../../../domain/models/clip.dart';

/// 5x4 colour matrix for brightness / contrast / saturation, matching FFmpeg's
/// `eq` filter closely: saturate, then `out = contrast * (in - 0.5) + 0.5 + brightness`.
List<double> lookMatrix(TimelineClip clip) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722; // Rec.709 luma
  final s = clip.saturation;
  final c = clip.contrast;
  final offset = (0.5 * (1 - c) + clip.brightness) * 255;
  double row(double a) => a * c;
  return [
    row(lr * (1 - s) + s), row(lg * (1 - s)), row(lb * (1 - s)), 0, offset,
    row(lr * (1 - s)), row(lg * (1 - s) + s), row(lb * (1 - s)), 0, offset,
    row(lr * (1 - s)), row(lg * (1 - s)), row(lb * (1 - s) + s), 0, offset,
    0, 0, 0, 1, 0,
  ];
}

/// Colour adjustments, rotation and mirroring of a clip's picture in the preview
/// (the export does the same with FFmpeg's `eq`, `transpose`, `hflip`, `vflip`).
class ClipEffects extends StatelessWidget {
  const ClipEffects({super.key, required this.clip, required this.child});

  final TimelineClip clip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var widget = child;
    if (clip.rotation % 4 != 0) {
      widget = RotatedBox(quarterTurns: clip.rotation % 4, child: widget);
    }
    if (clip.flipH || clip.flipV) {
      widget = Transform.flip(flipX: clip.flipH, flipY: clip.flipV, child: widget);
    }
    if (clip.hasLook) {
      widget = ColorFiltered(colorFilter: ColorFilter.matrix(lookMatrix(clip)), child: widget);
    }
    return widget;
  }
}

import 'package:flutter/widgets.dart';

import '../../../domain/models/clip.dart';

/// Applies a clip's scale / offset (fractions of the canvas) to its picture.
class ClipTransform extends StatelessWidget {
  const ClipTransform({super.key, required this.clip, required this.child});

  final TimelineClip clip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!clip.hasTransform) return child;
    return LayoutBuilder(
      builder: (context, box) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.translationValues(
              clip.offsetX * box.maxWidth,
              clip.offsetY * box.maxHeight,
              0,
            ) *
            Matrix4.diagonal3Values(clip.scale, clip.scale, 1.0),
        child: child,
      ),
    );
  }
}

import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

import '../../../core/utils/duration_x.dart';

class TimecodeText extends StatelessWidget {
  const TimecodeText(this.value, {super.key, this.style});

  final Duration value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      value.timecode,
      style: (style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

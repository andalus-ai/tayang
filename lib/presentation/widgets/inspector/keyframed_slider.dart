import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/playback_controller.dart';
import '../../../application/project_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_x.dart';
import '../../../domain/models/clip.dart';
import '../../../domain/models/keyframes.dart';
import '../common/labeled_slider.dart';

/// A property slider that can be animated with keyframes.
///
/// * No keyframes: edits the static value.
/// * With keyframes: the slider shows the value at the playhead and editing it
///   writes a keyframe there.
class KeyframedSlider extends ConsumerWidget {
  const KeyframedSlider({
    super.key,
    required this.clip,
    required this.property,
    required this.label,
    required this.max,
  });

  final TimelineClip clip;
  final KeyframeProperty property;
  final String label;
  final double max;

  Keyframes get _keys =>
      property == KeyframeProperty.opacity ? clip.opacityKeys : clip.volumeKeys;

  double get _static =>
      property == KeyframeProperty.opacity ? clip.opacity : clip.volume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(projectControllerProvider.notifier);
    final animated = _keys.isNotEmpty;
    // Only follow the playhead (and rebuild every frame) when keyframed.
    final playhead = animated
        ? ref.watch(playbackProvider.select((s) => s.position))
        : Duration.zero;
    final value = animated ? _keys.valueAt(playhead - clip.start, _static) : _static;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledSlider(
          label: animated ? '$label · keyframed' : label,
          value: value,
          min: 0,
          max: max,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) {
            if (animated) {
              controller.setKeyframeLive(clip.id, property, v);
            } else {
              controller.updateClipLive(
                clip.id,
                (c) => property == KeyframeProperty.opacity
                    ? c.copyWith(opacity: v)
                    : c.copyWith(volume: v),
              );
            }
          },
          onChangeEnd: controller.endGesture,
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => controller.setKeyframe(clip.id, property, value),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Keyframe at playhead'),
            ),
            if (animated)
              TextButton(
                onPressed: () => controller.clearKeyframes(clip.id, property),
                child: const Text('Clear'),
              ),
          ],
        ),
        if (animated)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _keys.points.length; i++)
                InputChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    '${_keys.points[i].time.timecode} · ${(_keys.points[i].value * 100).round()}%',
                    style: muted,
                  ),
                  onPressed: () => ref
                      .read(playbackProvider.notifier)
                      .seek(clip.start + _keys.points[i].time),
                  onDeleted: () => controller.removeKeyframe(clip.id, property, i),
                ),
            ],
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

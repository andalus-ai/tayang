import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/editor_actions.dart';
import '../../../application/project_controller.dart';
import '../../../application/selection_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_x.dart';
import '../../../domain/models/clip.dart';
import '../../../domain/models/keyframes.dart';
import '../common/labeled_slider.dart';
import 'keyframed_slider.dart';
import '../common/panel_container.dart';
import '../common/synced_text_field.dart';

class InspectorPanel extends ConsumerWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectionProvider);
    final clip = selectedId == null
        ? null
        : ref.watch(projectProvider.select((p) => p.clipById(selectedId)));

    return PanelContainer(
      title: clip == null ? 'Project' : 'Inspector',
      child: clip == null ? const _ProjectSettings() : _ClipInspector(clip: clip),
    );
  }
}

// ------------------------------------------------------------------ project

class _ProjectSettings extends ConsumerWidget {
  const _ProjectSettings();

  static const _canvases = [
    ('16:9', 1920, 1080),
    ('9:16', 1080, 1920),
    ('1:1', 1080, 1080),
    ('4:3', 1440, 1080),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text('Canvas', style: muted),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, w, h) in _canvases)
              ChoiceChip(
                label: Text(label),
                selected: project.width == w && project.height == h,
                onSelected: (_) => controller.setCanvas(w, h),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Frame rate', style: muted),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 24, label: Text('24')),
            ButtonSegment(value: 30, label: Text('30')),
            ButtonSegment(value: 60, label: Text('60')),
          ],
          selected: {project.fps},
          onSelectionChanged: (s) => controller.setFps(s.first),
        ),
        const SizedBox(height: 24),
        Text('Select a clip on the timeline to edit its properties.', style: muted),
      ],
    );
  }
}

// --------------------------------------------------------------------- clip

class _ClipInspector extends ConsumerWidget {
  const _ClipInspector({required this.clip});

  final TimelineClip clip;

  static const _maxFade = 5.0;

  static const _swatches = [
    0xFFFFFFFF,
    0xFFFFD84D,
    0xFFFF6B6B,
    0xFF6BD6FF,
    0xFF7CFFA8,
    0xFF000000,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(projectControllerProvider.notifier);
    final actions = ref.read(editorActionsProvider);
    final asset = ref.watch(projectProvider.select((p) => p.assetById(clip.assetId)));
    final crossfaded = ref.watch(projectProvider.select((p) => p.hasCrossfadeIn(clip.id)));
    final title = clip.kind == ClipKind.text ? 'Text clip' : (asset?.name ?? 'Missing media');
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: AppColors.forClip(clip.kind)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoRow('Start', clip.start.timecode),
        _InfoRow('Duration', clip.duration.timecode),
        _InfoRow('End', clip.end.timecode),
        const Divider(height: 28),
        if (clip.isTimeBased) ...[
          LabeledSlider(
            label: 'Speed',
            value: clip.speed,
            min: 0.25,
            max: 4,
            format: (v) => '${v.toStringAsFixed(2)}×',
            onChanged: (v) => controller.setSpeedLive(clip.id, v),
            onChangeEnd: controller.endGesture,
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final s in const [0.5, 1.0, 1.5, 2.0])
                ActionChip(
                  label: Text('$s×'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => controller.setSpeed(clip.id, s),
                ),
            ],
          ),
          const SizedBox(height: 8),
          KeyframedSlider(
            clip: clip,
            property: KeyframeProperty.volume,
            label: 'Volume',
            max: 2,
          ),
        ],
        if (clip.kind == ClipKind.video || clip.kind == ClipKind.image)
          KeyframedSlider(
            clip: clip,
            property: KeyframeProperty.opacity,
            label: 'Opacity',
            max: 1,
          ),
        if (clip.kind == ClipKind.text)
          LabeledSlider(
            label: 'Opacity',
            value: clip.opacity,
            min: 0,
            max: 1,
            format: (v) => '${(v * 100).round()}%',
            onChanged: (v) =>
                controller.updateClipLive(clip.id, (c) => c.copyWith(opacity: v)),
            onChangeEnd: controller.endGesture,
          ),
        if (clip.kind != ClipKind.text) ...[
          LabeledSlider(
            label: 'Fade in',
            value: clip.fadeIn.seconds,
            min: 0,
            max: _maxFade,
            format: (v) => '${v.toStringAsFixed(1)} s',
            onChanged: (v) => controller.updateClipLive(
                clip.id, (c) => c.copyWith(fadeIn: secondsToDuration(v))),
            onChangeEnd: controller.endGesture,
          ),
          LabeledSlider(
            label: 'Fade out',
            value: clip.fadeOut.seconds,
            min: 0,
            max: _maxFade,
            format: (v) => '${v.toStringAsFixed(1)} s',
            onChanged: (v) => controller.updateClipLive(
                clip.id, (c) => c.copyWith(fadeOut: secondsToDuration(v))),
            onChangeEnd: controller.endGesture,
          ),
        ],
        if (clip.kind == ClipKind.video || clip.kind == ClipKind.image)
          ..._transformSection(controller, muted),
        if (clip.kind == ClipKind.text) ..._textSection(controller, muted),
        const Divider(height: 28),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: actions.splitAtPlayhead,
              icon: const Icon(Icons.content_cut, size: 16),
              label: const Text('Split'),
            ),
            OutlinedButton.icon(
              onPressed: actions.duplicateSelected,
              icon: const Icon(Icons.copy_all_outlined, size: 16),
              label: const Text('Duplicate'),
            ),
            OutlinedButton.icon(
              onPressed: actions.copySelected,
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text('Copy'),
            ),
            if (crossfaded)
              OutlinedButton.icon(
                onPressed: actions.removeCrossfadeFromSelected,
                icon: const Icon(Icons.layers_clear, size: 16),
                label: const Text('Remove crossfade'),
              )
            else
              OutlinedButton.icon(
                onPressed: actions.addCrossfadeToSelected,
                icon: const Icon(Icons.layers, size: 16),
                label: const Text('Crossfade to next'),
              ),
            OutlinedButton.icon(
              onPressed: actions.addTransitionToSelected,
              icon: const Icon(Icons.blur_linear, size: 16),
              label: const Text('Dip to next'),
            ),
            OutlinedButton.icon(
              onPressed: () => actions.deleteSelected(),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete'),
            ),
            OutlinedButton.icon(
              onPressed: () => actions.deleteSelected(ripple: true),
              icon: const Icon(Icons.playlist_remove, size: 16),
              label: const Text('Ripple delete'),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _transformSection(ProjectController controller, TextStyle? muted) {
    return [
      const SizedBox(height: 8),
      Text('Transform', style: muted),
      LabeledSlider(
        label: 'Scale',
        value: clip.scale,
        min: 0.1,
        max: 4,
        format: (v) => '${v.toStringAsFixed(2)}×',
        onChanged: (v) => controller.updateClipLive(clip.id, (c) => c.copyWith(scale: v)),
        onChangeEnd: controller.endGesture,
      ),
      LabeledSlider(
        label: 'Position X',
        value: clip.offsetX,
        min: -1,
        max: 1,
        format: (v) => '${(v * 100).round()}%',
        onChanged: (v) => controller.updateClipLive(clip.id, (c) => c.copyWith(offsetX: v)),
        onChangeEnd: controller.endGesture,
      ),
      LabeledSlider(
        label: 'Position Y',
        value: clip.offsetY,
        min: -1,
        max: 1,
        format: (v) => '${(v * 100).round()}%',
        onChanged: (v) => controller.updateClipLive(clip.id, (c) => c.copyWith(offsetY: v)),
        onChangeEnd: controller.endGesture,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => controller.updateClip(
              clip.id, (c) => c.copyWith(scale: 1.0, offsetX: 0.0, offsetY: 0.0)),
          child: const Text('Reset transform'),
        ),
      ),
    ];
  }

  List<Widget> _textSection(ProjectController controller, TextStyle? muted) {
    final text = clip.text ?? const TextOverlay();

    void edit(TextOverlay Function(TextOverlay) change, {bool live = true}) {
      TimelineClip apply(TimelineClip c) =>
          c.copyWith(text: change(c.text ?? const TextOverlay()));
      live ? controller.updateClipLive(clip.id, apply) : controller.updateClip(clip.id, apply);
    }

    return [
      const SizedBox(height: 12),
      SyncedTextField(
        label: 'Text',
        value: text.content,
        maxLines: 3,
        onChanged: (v) => edit((t) => t.copyWith(content: v)),
        onCommit: controller.endGesture,
      ),
      const SizedBox(height: 8),
      LabeledSlider(
        label: 'Size',
        value: text.fontSize,
        min: 12,
        max: 240,
        format: (v) => '${v.round()} px',
        onChanged: (v) => edit((t) => t.copyWith(fontSize: v)),
        onChangeEnd: controller.endGesture,
      ),
      LabeledSlider(
        label: 'Horizontal position',
        value: text.x,
        min: 0,
        max: 1,
        format: (v) => '${(v * 100).round()}%',
        onChanged: (v) => edit((t) => t.copyWith(x: v)),
        onChangeEnd: controller.endGesture,
      ),
      LabeledSlider(
        label: 'Vertical position',
        value: text.y,
        min: 0,
        max: 1,
        format: (v) => '${(v * 100).round()}%',
        onChanged: (v) => edit((t) => t.copyWith(y: v)),
        onChangeEnd: controller.endGesture,
      ),
      const SizedBox(height: 4),
      Text('Colour', style: muted),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        children: [
          for (final argb in _swatches)
            GestureDetector(
              onTap: () => edit((t) => t.copyWith(color: argb), live: false),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Color(argb),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: text.color == argb ? AppColors.accent : AppColors.outline,
                    width: text.color == argb ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    ];
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style?.copyWith(color: AppColors.mutedText)),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/editor_actions.dart';
import '../../../application/project_controller.dart';
import '../../../application/selection_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_x.dart';
import '../../../domain/models/clip.dart';
import '../common/labeled_slider.dart';
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
          LabeledSlider(
            label: 'Volume',
            value: clip.volume,
            min: 0,
            max: 2,
            format: (v) => '${(v * 100).round()}%',
            onChanged: (v) => controller.updateClipLive(clip.id, (c) => c.copyWith(volume: v)),
            onChangeEnd: controller.endGesture,
          ),
        ],
        if (clip.kind != ClipKind.audio)
          LabeledSlider(
            label: 'Opacity',
            value: clip.opacity,
            min: 0,
            max: 1,
            format: (v) => '${(v * 100).round()}%',
            onChanged: (v) => controller.updateClipLive(clip.id, (c) => c.copyWith(opacity: v)),
            onChangeEnd: controller.endGesture,
          ),
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

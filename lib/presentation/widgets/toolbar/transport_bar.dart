import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/editor_actions.dart';
import '../../../application/playback_controller.dart';
import '../../../application/project_controller.dart';
import '../../../application/selection_controller.dart';
import '../../../application/timeline_zoom_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_x.dart';
import '../../../domain/models/track.dart';
import '../common/icon_action_button.dart';
import '../common/timecode_text.dart';

/// Playback controls, editing tools and zoom. The panel buttons are only passed
/// on compact screens, where media/inspector live in bottom sheets.
class TransportBar extends ConsumerWidget {
  const TransportBar({super.key, this.onOpenMedia, this.onOpenInspector});

  final VoidCallback? onOpenMedia;
  final VoidCallback? onOpenInspector;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(editorActionsProvider);
    final isPlaying = ref.watch(playbackProvider.select((s) => s.isPlaying));
    final hasSelection = ref.watch(selectionProvider.select((id) => id != null));
    final zoom = ref.watch(timelineZoomProvider);
    final zoomController = ref.read(timelineZoomProvider.notifier);
    final snapping = ref.watch(snapEnabledProvider);

    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.outline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (onOpenMedia != null)
              IconActionButton(
                icon: Icons.video_library_outlined,
                tooltip: 'Media',
                onPressed: onOpenMedia,
              ),
            IconActionButton(
              icon: Icons.skip_previous,
              tooltip: 'Go to start',
              onPressed: actions.seekToStart,
            ),
            IconActionButton(
              icon: Icons.keyboard_arrow_left,
              tooltip: 'Previous frame (←)',
              onPressed: () => actions.stepFrames(-1),
            ),
            IconButton.filled(
              tooltip: isPlaying ? 'Pause (Space)' : 'Play (Space)',
              onPressed: actions.togglePlay,
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            IconActionButton(
              icon: Icons.keyboard_arrow_right,
              tooltip: 'Next frame (→)',
              onPressed: () => actions.stepFrames(1),
            ),
            IconActionButton(
              icon: Icons.skip_next,
              tooltip: 'Go to end',
              onPressed: actions.seekToEnd,
            ),
            const SizedBox(width: 10),
            const _Timecode(),
            const SizedBox(width: 10),
            const SizedBox(height: 24, child: VerticalDivider()),
            IconActionButton(
              icon: Icons.content_cut,
              tooltip: 'Split at playhead (S)',
              onPressed: actions.splitAtPlayhead,
            ),
            IconActionButton(
              icon: Icons.copy_all_outlined,
              tooltip: 'Duplicate clip',
              onPressed: hasSelection ? actions.duplicateSelected : null,
            ),
            IconActionButton(
              icon: Icons.delete_outline,
              tooltip: 'Delete clip (Del)',
              onPressed: hasSelection ? () => actions.deleteSelected() : null,
            ),
            IconActionButton(
              icon: Icons.playlist_remove,
              tooltip: 'Ripple delete (Shift+Del)',
              onPressed: hasSelection ? () => actions.deleteSelected(ripple: true) : null,
            ),
            const SizedBox(height: 24, child: VerticalDivider()),
            IconActionButton(
              icon: Icons.title,
              tooltip: 'Add text at playhead',
              onPressed: actions.addText,
            ),
            PopupMenuButton<TrackKind>(
              tooltip: 'Add track',
              icon: const Icon(Icons.add_box_outlined, size: 20),
              onSelected: actions.addTrack,
              itemBuilder: (_) => [
                for (final kind in TrackKind.values)
                  PopupMenuItem(value: kind, child: Text('Add ${kind.label.toLowerCase()} track')),
              ],
            ),
            const SizedBox(height: 24, child: VerticalDivider()),
            IconActionButton(
              icon: Icons.zoom_out,
              tooltip: 'Zoom out',
              onPressed: zoomController.zoomOut,
            ),
            SizedBox(
              width: 120,
              child: Slider(
                value: zoom.clamp(TimelineZoomController.min, TimelineZoomController.max).toDouble(),
                min: TimelineZoomController.min,
                max: TimelineZoomController.max,
                onChanged: zoomController.set,
              ),
            ),
            IconActionButton(
              icon: Icons.zoom_in,
              tooltip: 'Zoom in',
              onPressed: zoomController.zoomIn,
            ),
            IconActionButton(
              icon: Icons.align_horizontal_center,
              tooltip: snapping ? 'Snapping on' : 'Snapping off',
              selected: snapping,
              onPressed: ref.read(snapEnabledProvider.notifier).toggle,
            ),
            if (onOpenInspector != null)
              IconActionButton(
                icon: Icons.tune,
                tooltip: 'Inspector',
                onPressed: onOpenInspector,
              ),
          ],
        ),
      ),
    );
  }
}

class _Timecode extends ConsumerWidget {
  const _Timecode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playbackProvider.select((s) => s.position));
    final duration = ref.watch(projectProvider.select((p) => p.duration));
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText);
    return Row(
      children: [
        TimecodeText(position),
        Text('  /  ${duration.timecode}', style: muted),
      ],
    );
  }
}

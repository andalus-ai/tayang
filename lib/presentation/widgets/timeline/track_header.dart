import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/project_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/clip.dart';
import '../../../domain/models/track.dart';

class TrackHeader extends ConsumerWidget {
  const TrackHeader({super.key, required this.trackId, required this.height});

  final String trackId;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(projectProvider.select((p) => p.trackById(trackId)));
    if (track == null) return SizedBox(height: height);
    final controller = ref.read(projectControllerProvider.notifier);

    void update(Track Function(Track) fn) => controller.updateTrack(trackId, fn);

    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outline),
          right: BorderSide(color: AppColors.outline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _icon(track.kind),
                size: 14,
                color: AppColors.forClip(_clipKind(track.kind)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  track.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Track options',
                padding: EdgeInsets.zero,
                onSelected: (_) => controller.removeTrack(trackId),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete track')),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.more_horiz, size: 16, color: AppColors.mutedText),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (track.hasVisual)
                _MiniToggle(
                  icon: track.isVisible ? Icons.visibility : Icons.visibility_off,
                  tooltip: track.isVisible ? 'Hide track' : 'Show track',
                  active: !track.isVisible,
                  onTap: () => update((t) => t.copyWith(isVisible: !t.isVisible)),
                ),
              if (track.hasAudio)
                _MiniToggle(
                  icon: track.isMuted ? Icons.volume_off : Icons.volume_up,
                  tooltip: track.isMuted ? 'Unmute track' : 'Mute track',
                  active: track.isMuted,
                  onTap: () => update((t) => t.copyWith(isMuted: !t.isMuted)),
                ),
              _MiniToggle(
                icon: track.isLocked ? Icons.lock : Icons.lock_open,
                tooltip: track.isLocked ? 'Unlock track' : 'Lock track',
                active: track.isLocked,
                onTap: () => update((t) => t.copyWith(isLocked: !t.isLocked)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _icon(TrackKind kind) => switch (kind) {
        TrackKind.video => Icons.movie_outlined,
        TrackKind.audio => Icons.graphic_eq,
        TrackKind.text => Icons.title,
      };

  ClipKind _clipKind(TrackKind kind) => switch (kind) {
        TrackKind.video => ClipKind.video,
        TrackKind.audio => ClipKind.audio,
        TrackKind.text => ClipKind.text,
      };
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color: active ? AppColors.accent : AppColors.mutedText,
          ),
        ),
      ),
    );
  }
}

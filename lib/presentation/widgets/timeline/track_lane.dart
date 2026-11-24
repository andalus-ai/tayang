import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/editor_actions.dart';
import '../../../application/project_controller.dart';
import '../../../application/selection_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/clip.dart';
import '../../../domain/models/media_asset.dart';
import 'timeline_geometry.dart';

/// Lane background + drop target for media dragged from the media bin.
/// (Clips are drawn by `ClipsLayer`, not here — see the note there.)
class TrackLane extends ConsumerWidget {
  const TrackLane({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geo = TimelineScope.of(context);
    final track = ref.watch(projectProvider.select((p) => p.trackById(trackId)));
    if (track == null) return const SizedBox.shrink();

    return DragTarget<MediaAsset>(
      onWillAcceptWithDetails: (d) =>
          !track.isLocked && track.kind.accepts(d.data.kind.clipKind),
      onAcceptWithDetails: (d) {
        final box = context.findRenderObject() as RenderBox;
        final dx = math.max(0.0, box.globalToLocal(d.offset).dx);
        ref
            .read(editorActionsProvider)
            .addAsset(d.data, at: geo.scale.toTime(dx), trackId: trackId);
      },
      builder: (context, candidates, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(selectionProvider.notifier).clear(),
          child: Container(
            height: geo.laneHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: candidates.isNotEmpty
                  ? AppColors.accent.withAlpha(36)
                  : track.isLocked
                      ? AppColors.background
                      : AppColors.surface,
              border: const Border(bottom: BorderSide(color: AppColors.outline)),
            ),
          ),
        );
      },
    );
  }
}

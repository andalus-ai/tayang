import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/project_controller.dart';
import 'clip_widget.dart';

/// Draws every clip of every track in ONE flat stack, keyed by clip id.
///
/// Why not nest clips inside their lane? When a clip is dragged onto another
/// track, a nested widget would be re-parented → its element (and the active
/// drag gesture) would be destroyed mid-drag. With a flat keyed stack the same
/// element simply moves vertically and the drag continues.
class ClipsLayer extends ConsumerWidget {
  const ClipsLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(projectProvider.select((p) => p.tracks));
    return Stack(
      children: [
        for (var lane = 0; lane < tracks.length; lane++)
          for (final clip in tracks[lane].clips)
            ClipWidget(
              key: ValueKey(clip.id),
              clip: clip,
              track: tracks[lane],
              laneIndex: lane,
            ),
      ],
    );
  }
}

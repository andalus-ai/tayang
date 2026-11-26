import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/project_controller.dart';
import 'clip_placement.dart';
import 'clip_widget.dart';

/// Draws every clip of every track in ONE flat stack, keyed by clip id.
///
/// Why not nest clips inside their lane? When a clip is dragged onto another
/// track, a nested widget would be re-parented → its element (and the active
/// drag gesture) would be destroyed mid-drag. With a flat keyed stack the same
/// element simply moves vertically and the drag continues.
///
/// This layer watches only the clip *structure*, so it does not rebuild while
/// clips are dragged, trimmed or edited; each [ClipWidget] watches its own data.
class ClipsLayer extends ConsumerWidget {
  const ClipsLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(projectProvider.select(layoutOf));
    return Stack(
      children: [
        for (final id in layout.ids) ClipWidget(key: ValueKey(id), clipId: id),
      ],
    );
  }
}

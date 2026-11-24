import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/project_controller.dart';
import '../../../application/selection_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/clip.dart';
import '../../../domain/models/track.dart';
import 'timeline_geometry.dart';

class ClipWidget extends ConsumerStatefulWidget {
  const ClipWidget({
    super.key,
    required this.clip,
    required this.track,
    required this.laneIndex,
  });

  final TimelineClip clip;
  final Track track;
  final int laneIndex;

  @override
  ConsumerState<ClipWidget> createState() => _ClipWidgetState();
}

class _ClipWidgetState extends ConsumerState<ClipWidget> {
  /// Time between the clip's start and the pointer when the drag began.
  Duration _grab = Duration.zero;

  ProjectController get _controller => ref.read(projectControllerProvider.notifier);

  void _onMoveStart(TimelineGeometry geo, DragStartDetails d) {
    ref.read(selectionProvider.notifier).select(widget.clip.id);
    _grab = geo.timeAt(d.globalPosition) - widget.clip.start;
  }

  void _onMoveUpdate(TimelineGeometry geo, DragUpdateDetails d) {
    final project = ref.read(projectProvider);
    final lane = geo.laneIndexAt(d.globalPosition, project.tracks.length);
    final hovered = project.tracks[lane];
    final current = project.trackOfClip(widget.clip.id);
    // Hovering a track that can't hold this clip keeps it on its own track.
    final target = hovered.kind.accepts(widget.clip.kind) ? hovered : current;

    _controller.moveClipLive(
      widget.clip.id,
      geo.timeAt(d.globalPosition) - _grab,
      toTrackId: target?.id,
      snapThreshold: geo.scale.toTime(8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final geo = TimelineScope.of(context);
    final clip = widget.clip;
    final locked = widget.track.isLocked;
    final selected = ref.watch(selectionProvider.select((id) => id == clip.id));
    final asset = ref.watch(projectProvider.select((p) => p.assetById(clip.assetId)));

    final width = math.max(geo.scale.toDx(clip.duration), 6.0);
    final handleWidth = math.min(10.0, width / 3);
    final label = clip.kind == ClipKind.text
        ? (clip.text?.content ?? 'Text')
        : (asset?.name ?? 'Missing media');

    return Positioned(
      left: geo.scale.toDx(clip.start),
      top: widget.laneIndex * geo.laneHeight + 4,
      width: width,
      height: geo.laneHeight - 8,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(selectionProvider.notifier).select(clip.id),
              onHorizontalDragStart: locked ? null : (d) => _onMoveStart(geo, d),
              onHorizontalDragUpdate: locked ? null : (d) => _onMoveUpdate(geo, d),
              onHorizontalDragEnd: locked ? null : (_) => _controller.endGesture(),
              onHorizontalDragCancel: locked ? null : _controller.endGesture,
              child: _ClipBody(
                clip: clip,
                label: label,
                selected: selected,
                dimmed: locked || !widget.track.isVisible && widget.track.hasVisual,
              ),
            ),
          ),
          if (!locked) ...[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: handleWidth,
              child: _TrimHandle(
                onDrag: (g) => _controller.trimClipStartLive(clip.id, geo.timeAt(g)),
                onEnd: _controller.endGesture,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: handleWidth,
              child: _TrimHandle(
                onDrag: (g) => _controller.trimClipEndLive(clip.id, geo.timeAt(g)),
                onEnd: _controller.endGesture,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClipBody extends StatelessWidget {
  const _ClipBody({
    required this.clip,
    required this.label,
    required this.selected,
    required this.dimmed,
  });

  final TimelineClip clip;
  final String label;
  final bool selected;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forClip(clip.kind);
    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(dimmed ? 90 : (selected ? 255 : 205)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? Colors.white : color.withAlpha(255),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if ((clip.speed - 1).abs() > 0.01)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${clip.speed.toStringAsFixed(2)}×',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrimHandle extends StatelessWidget {
  const _TrimHandle({required this.onDrag, required this.onEnd});

  final ValueChanged<Offset> onDrag;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDrag(d.globalPosition),
        onHorizontalDragEnd: (_) => onEnd(),
        onHorizontalDragCancel: onEnd,
        child: Center(
          child: Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

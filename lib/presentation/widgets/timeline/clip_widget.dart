import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/project_controller.dart';
import '../../../application/selection_controller.dart';
import '../../../application/thumbnails.dart';
import '../../../application/timeline_viewport_controller.dart';
import '../../../application/timeline_zoom_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/clip.dart';
import '../../../domain/models/media_asset.dart';
import 'clip_placement.dart';
import 'timeline_geometry.dart';

class ClipWidget extends ConsumerStatefulWidget {
  const ClipWidget({super.key, required this.clipId});

  final String clipId;

  @override
  ConsumerState<ClipWidget> createState() => _ClipWidgetState();
}

class _ClipWidgetState extends ConsumerState<ClipWidget> {
  /// Time between the clip's start and the pointer when the drag began.
  Duration _grab = Duration.zero;

  /// Offset between the pointer and the trimmed edge when a handle is grabbed.
  Duration _trimGrab = Duration.zero;

  ProjectController get _controller => ref.read(projectControllerProvider.notifier);

  TimelineClip? get _current => ref.read(projectProvider).clipById(widget.clipId);

  /// Pointer touched the clip: remember where inside it, so the clip follows the
  /// pointer exactly (no lag from the touch-slop distance).
  void _onPointerDown(TimelineGeometry geo, DragDownDetails d) {
    final clip = _current;
    if (clip == null) return;
    ref.read(selectionProvider.notifier).select(clip.id);
    _grab = geo.timeAt(d.globalPosition) - clip.start;
  }

  void _onMoveUpdate(TimelineGeometry geo, DragUpdateDetails d) {
    final clip = _current;
    if (clip == null) return;
    final project = ref.read(projectProvider);
    final lane = geo.laneIndexAt(d.globalPosition, project.tracks.length);
    final hovered = project.tracks[lane];
    final own = project.trackOfClip(clip.id);
    // Hovering a track that can't hold this clip keeps it on its own track.
    final target = hovered.kind.accepts(clip.kind) ? hovered : own;

    _controller.moveClipLive(
      clip.id,
      geo.timeAt(d.globalPosition) - _grab,
      toTrackId: target?.id,
      snapThreshold:
          ref.read(snapEnabledProvider) ? geo.scale.toTime(8) : Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final geo = TimelineScope.of(context);
    // Only THIS clip's data: other edits/drags don't rebuild this widget.
    final placement =
        ref.watch(clipPlacementsProvider.select((m) => m[widget.clipId]));
    if (placement == null) return const SizedBox.shrink();

    final clip = placement.clip;
    final locked = placement.locked;
    final selected = ref.watch(selectionProvider.select((id) => id == widget.clipId));

    // Culling: clips well outside the visible area build nothing (no layout, no
    // layers). The selected clip is always kept so an active drag survives
    // leaving the viewport.
    final visible = ref.watch(timelineViewportProvider);
    if (!selected && !visible.overlaps(clip.start, clip.end)) {
      return const SizedBox.shrink();
    }

    final asset = ref.watch(projectProvider.select((p) => p.assetById(clip.assetId)));

    final width = math.max(geo.scale.toDx(clip.duration), 6.0);
    final handleWidth = math.min(10.0, width / 3);
    final label = clip.kind == ClipKind.text
        ? (clip.text?.content ?? 'Text')
        : (asset?.name ?? 'Missing media');

    return Positioned(
      left: geo.scale.toDx(clip.start),
      top: placement.lane * geo.laneHeight + 4,
      width: width,
      height: geo.laneHeight - 8,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(selectionProvider.notifier).select(clip.id),
              onHorizontalDragDown: locked ? null : (d) => _onPointerDown(geo, d),
              onHorizontalDragUpdate: locked ? null : (d) => _onMoveUpdate(geo, d),
              onHorizontalDragEnd: locked ? null : (_) => _controller.endGesture(),
              onHorizontalDragCancel: locked ? null : _controller.endGesture,
              onVerticalDragDown: locked ? null : (d) => _onPointerDown(geo, d),
              onVerticalDragUpdate: locked ? null : (d) => _onMoveUpdate(geo, d),
              onVerticalDragEnd: locked ? null : (_) => _controller.endGesture(),
              onVerticalDragCancel: locked ? null : _controller.endGesture,
              child: _ClipBody(
                clip: clip,
                asset: asset,
                label: label,
                selected: selected,
                dimmed: placement.dimmed,
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
                onDown: (g) =>
                    _trimGrab = geo.timeAt(g) - (_current?.start ?? Duration.zero),
                onDrag: (g) =>
                    _controller.trimClipStartLive(clip.id, geo.timeAt(g) - _trimGrab),
                onEnd: _controller.endGesture,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: handleWidth,
              child: _TrimHandle(
                onDown: (g) =>
                    _trimGrab = geo.timeAt(g) - (_current?.end ?? Duration.zero),
                onDrag: (g) =>
                    _controller.trimClipEndLive(clip.id, geo.timeAt(g) - _trimGrab),
                onEnd: _controller.endGesture,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClipBody extends ConsumerWidget {
  const _ClipBody({
    required this.clip,
    required this.asset,
    required this.label,
    required this.selected,
    required this.dimmed,
  });

  final TimelineClip clip;
  final MediaAsset? asset;
  final String label;
  final bool selected;
  final bool dimmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppColors.forClip(clip.kind);
    final thumbnail = asset == null || asset!.kind == MediaKind.audio
        ? null
        : ref.watch(thumbnailPathProvider(asset!)).valueOrNull;
    final wave = asset != null && clip.kind == ClipKind.audio
        ? ref.watch(waveformPathProvider(asset!)).valueOrNull
        : null;
    return Container(
      // No clipBehavior: the decoration clips its own image and the label clips
      // itself, so we avoid one extra compositing layer per clip.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(dimmed ? 90 : (selected ? 255 : 205)),
        image: thumbnail == null
            ? null
            : DecorationImage(
                image: FileImage(File(thumbnail)),
                fit: BoxFit.cover,
                alignment: Alignment.centerLeft,
                colorFilter: ColorFilter.mode(
                  color.withAlpha(150),
                  BlendMode.srcOver,
                ),
              ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? Colors.white : color.withAlpha(255),
          width: selected ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (wave != null) Positioned.fill(child: _Waveform(path: wave, clip: clip, asset: asset!)),
          if (clip.opacityKeys.isNotEmpty || clip.volumeKeys.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _KeyMarkers(clip))),
            ),
          Row(
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
        ],
      ),
    );
  }
}

/// Draws only the slice of the asset's waveform that this clip plays.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.path, required this.clip, required this.asset});

  final String path;
  final TimelineClip clip;
  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    final total = asset.duration.inMicroseconds;
    final slice = clip.sourceDuration.inMicroseconds;
    if (total <= 0 || slice <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, box) {
        final fullWidth = box.maxWidth * total / slice;
        final offset = box.maxWidth * clip.sourceStart.inMicroseconds / slice;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: fullWidth,
            maxWidth: fullWidth,
            child: Transform.translate(
              offset: Offset(-offset, 0),
              child: Opacity(
                opacity: 0.8,
                child: Image.file(
                  File(path),
                  width: fullWidth,
                  height: box.maxHeight,
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrimHandle extends StatelessWidget {
  const _TrimHandle({required this.onDown, required this.onDrag, required this.onEnd});

  final ValueChanged<Offset> onDown;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragDown: (d) => onDown(d.globalPosition),
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

/// Small diamonds along the bottom edge of a clip at each keyframe time.
class _KeyMarkers extends CustomPainter {
  _KeyMarkers(this.clip);

  final TimelineClip clip;

  @override
  void paint(Canvas canvas, Size size) {
    final total = clip.duration.inMicroseconds;
    if (total <= 0) return;
    final paint = Paint()..color = Colors.white;
    final times = {
      for (final k in clip.opacityKeys.points) k.time.inMicroseconds,
      for (final k in clip.volumeKeys.points) k.time.inMicroseconds,
    };
    for (final t in times) {
      final x = size.width * t / total;
      final y = size.height - 7;
      canvas.drawPath(
        Path()
          ..moveTo(x, y - 4)
          ..lineTo(x + 4, y)
          ..lineTo(x, y + 4)
          ..lineTo(x - 4, y)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_KeyMarkers old) => old.clip != clip;
}

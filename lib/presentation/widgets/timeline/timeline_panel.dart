import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/playback_controller.dart';
import '../../../application/project_controller.dart';
import '../../../application/timeline_viewport_controller.dart';
import '../../../application/timeline_zoom_controller.dart';
import '../common/panel_container.dart';
import 'clips_layer.dart';
import 'playhead_overlay.dart';
import 'timeline_geometry.dart';
import 'timeline_ruler.dart';
import 'track_header.dart';
import 'track_lane.dart';

class TimelinePanel extends ConsumerStatefulWidget {
  const TimelinePanel({super.key});

  @override
  ConsumerState<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends ConsumerState<TimelinePanel> {
  static const _headerWidth = 156.0;

  final _scroll = ScrollController();
  final _lanesKey = GlobalKey();
  double _viewport = 0;
  String _lastViewportKey = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _syncViewport(TimelineScale(ref.read(timelineZoomProvider))));
  }

  /// Publishes the visible time range in coarse (half-viewport) steps, so clips
  /// off screen aren't built and scrolling doesn't rebuild on every pixel.
  void _syncViewport(TimelineScale scale) {
    if (!_scroll.hasClients || _viewport <= 0) return;
    final half = _viewport / 2;
    final bucket = (_scroll.offset / half).floor();
    final key = '$bucket|${scale.pixelsPerSecond}|${_viewport.round()}';
    if (key == _lastViewportKey) return;
    _lastViewportKey = key;
    ref.read(timelineViewportProvider.notifier).set(TimeRange(
          scale.toTime(math.max(0.0, (bucket - 2) * half)),
          scale.toTime((bucket + 5) * half),
        ));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the playhead on screen while playing.
  void _followPlayhead(Duration position, TimelineScale scale) {
    if (!_scroll.hasClients || !ref.read(playbackProvider).isPlaying) return;
    final x = scale.toDx(position);
    final offset = _scroll.offset;
    if (x > offset + _viewport - 48 || x < offset) {
      _scroll.jumpTo(
        math.min(math.max(0.0, x - 48), _scroll.position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = TimelineScale(ref.watch(timelineZoomProvider));
    final geometry = TimelineGeometry(scale: scale, lanesKey: _lanesKey);

    final joinedIds = ref.watch(
      projectProvider.select((p) => p.tracks.map((t) => t.id).join('|')),
    );
    final trackIds = joinedIds.isEmpty ? const <String>[] : joinedIds.split('|');
    final duration = ref.watch(projectProvider.select((p) => p.duration));

    ref.listen<Duration>(
      playbackProvider.select((s) => s.position),
      (_, position) => _followPlayhead(position, scale),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncViewport(scale);
    });

    final contentHeight = geometry.rulerHeight + trackIds.length * geometry.laneHeight;

    return PanelContainer(
      title: 'Timeline',
      child: TimelineScope(
        geometry: geometry,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _viewport = constraints.maxWidth - _headerWidth;
            final contentWidth = math.max(
              _viewport,
              scale.toDx(duration + const Duration(seconds: 20)),
            );

            return SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _headerWidth,
                    child: Column(
                      children: [
                        SizedBox(height: geometry.rulerHeight),
                        for (final id in trackIds)
                          TrackHeader(
                            key: ValueKey(id),
                            trackId: id,
                            height: geometry.laneHeight,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        key: _lanesKey,
                        width: contentWidth,
                        height: contentHeight,
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerSignal: _onPointerSignal,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: geometry.rulerHeight,
                                child: RepaintBoundary(
                                  child: TimelineRuler(width: contentWidth),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: geometry.rulerHeight,
                                child: RepaintBoundary(
                                  child: Column(
                                    children: [
                                      for (final id in trackIds)
                                        TrackLane(key: ValueKey(id), trackId: id),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: geometry.rulerHeight,
                                bottom: 0,
                                child: const RepaintBoundary(child: ClipsLayer()),
                              ),
                              const PlayheadOverlay(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Ctrl / ⌘ + scroll wheel zooms the timeline.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final zoom = ref.read(timelineZoomProvider.notifier);
      final factor = (e as PointerScrollEvent).scrollDelta.dy > 0 ? 0.9 : 1.1;
      zoom.set(ref.read(timelineZoomProvider) * factor);
    });
  }
}

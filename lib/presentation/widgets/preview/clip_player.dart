import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../application/di.dart';
import '../../../application/playback_controller.dart';
import '../../../core/utils/duration_x.dart';
import '../../../data/playback/player_pool.dart';
import '../../../domain/models/clip.dart';
import '../../../domain/models/media_asset.dart';
import 'clip_effects.dart';
import 'clip_transform.dart';

/// Plays one timeline clip, slaved to the timeline clock (`playbackProvider`).
/// With `showVideo: false` it is audio-only (audio-track clips, hidden layers).
///
/// Create it with `ValueKey(clip.id)` so each clip gets its own state; the
/// controller itself comes from the shared `PlayerPool`.
class ClipPlayer extends ConsumerStatefulWidget {
  const ClipPlayer({
    super.key,
    required this.clip,
    required this.asset,
    required this.muted,
    required this.showVideo,
    this.audioFadeOut = Duration.zero,
  });

  final TimelineClip clip;
  final MediaAsset asset;
  final bool muted;
  final bool showVideo;

  /// Extra audio fade-out (crossfading into the next clip on the same track).
  final Duration audioFadeOut;

  @override
  ConsumerState<ClipPlayer> createState() => _ClipPlayerState();
}

class _ClipPlayerState extends ConsumerState<ClipPlayer> {
  static const _maxDrift = Duration(milliseconds: 350);

  VideoPlayerController? _controller;
  PlayerLease? _lease;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  Future<void> _attach() async {
    try {
      _lease = ref.read(playerPoolProvider).acquire(widget.asset.path);
      final controller = await _lease!.controller;
      if (!mounted) return;
      setState(() => _controller = controller);
      await _applyProperties();
      await _syncToTimeline(force: true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(ClipPlayer old) {
    super.didUpdateWidget(old);
    if (old.clip.volume != widget.clip.volume ||
        old.clip.speed != widget.clip.speed ||
        old.audioFadeOut != widget.audioFadeOut ||
        old.muted != widget.muted) {
      _applyProperties();
    }
  }

  Future<void> _applyProperties() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setVolume(widget.muted ? 0.0 : widget.clip.volume.clamp(0.0, 1.0).toDouble());
    await controller.setPlaybackSpeed(widget.clip.speed);
  }

  Future<void> _syncToTimeline({bool force = false}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final timeline = ref.read(playbackProvider);
    final expected = widget.clip.sourcePositionAt(timeline.position);
    final drift = (controller.value.position - expected).abs();

    // Scrubbing (paused) always seeks; while playing only correct real drift.
    if ((widget.clip.isAnimated || widget.audioFadeOut > Duration.zero) && !widget.muted) {
      final fadeOut = maxDuration(widget.clip.fadeOut, widget.audioFadeOut);
      await controller.setVolume(
        widget.clip.volumeAt(timeline.position, fadeOut: fadeOut).clamp(0.0, 1.0).toDouble(),
      );
    }
    if (force || !timeline.isPlaying || drift > _maxDrift) {
      await controller.seekTo(expected);
    }
    if (timeline.isPlaying && !controller.value.isPlaying) {
      await controller.play();
    } else if (!timeline.isPlaying && controller.value.isPlaying) {
      await controller.pause();
    }
  }

  @override
  void dispose() {
    _lease?.release(); // controller stays pooled for reuse
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaybackState>(playbackProvider, (_, __) => _syncToTimeline());

    if (!widget.showVideo) return const SizedBox.shrink();
    if (_failed) return const _MissingMedia();

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final opacity = widget.clip.isAnimated
        ? widget.clip.opacityAt(ref.watch(playbackProvider.select((s) => s.position)))
        : widget.clip.opacity.clamp(0.0, 1.0).toDouble();
    return ClipTransform(
      clip: widget.clip,
      child: Opacity(
        opacity: opacity,
        child: ClipEffects(
          clip: widget.clip,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingMedia extends StatelessWidget {
  const _MissingMedia();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: Colors.white38),
            SizedBox(height: 6),
            Text('Media unavailable', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
}

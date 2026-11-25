import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/playback_controller.dart';
import '../../../application/preview_providers.dart';
import '../../../application/project_controller.dart';
import '../../../domain/models/clip.dart';
import '../../../domain/models/media_asset.dart';
import '../../../domain/models/track.dart';
import '../common/panel_container.dart';
import 'clip_player.dart';
import 'clip_transform.dart';

class PreviewPanel extends ConsumerWidget {
  const PreviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aspect = ref.watch(projectProvider.select((p) => p.width / p.height));
    return PanelContainer(
      title: 'Preview',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 18)],
              ),
              child: ClipRect(child: _Canvas()),
            ),
          ),
        ),
      ),
    );
  }
}

class _Canvas extends StatelessWidget {
  const _Canvas();

  @override
  Widget build(BuildContext context) => const Stack(
        fit: StackFit.expand,
        children: [
          _VisualLayer(),
          _TextLayer(),
          _AudioLayer(),
        ],
      );
}

class _VisualLayer extends ConsumerWidget {
  const _VisualLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeVisualClipsProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final clip in active.clips) _ClipLayer(key: ValueKey(clip.id), clip: clip),
      ],
    );
  }
}

class _ClipLayer extends ConsumerWidget {
  const _ClipLayer({super.key, required this.clip});

  final TimelineClip clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(projectProvider.select((p) => p.assetById(clip.assetId)));
    if (asset == null) return const SizedBox.expand();

    if (clip.kind == ClipKind.image) {
      final opacity = clip.isAnimated
          ? clip.opacityAt(ref.watch(playbackProvider.select((s) => s.position)))
          : clip.opacity.clamp(0.0, 1.0).toDouble();
      return ClipTransform(
        clip: clip,
        child: Opacity(
          opacity: opacity,
          child: Image.file(
            File(asset.path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.expand(),
          ),
        ),
      );
    }

    final muted =
        ref.watch(projectProvider.select((p) => p.trackOfClip(clip.id)?.isMuted ?? false));
    final audioFadeOut = ref.watch(projectProvider.select((p) => p.crossfadeOutOf(clip)));
    return ClipPlayer(
      clip: clip,
      asset: asset,
      muted: muted,
      showVideo: true,
      audioFadeOut: audioFadeOut,
    );
  }
}

class _TextLayer extends ConsumerWidget {
  const _TextLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final position = ref.watch(playbackProvider.select((s) => s.position));

    return LayoutBuilder(
      builder: (context, box) {
        final scale = box.maxHeight / project.height;
        final children = <Widget>[];
        // Lower tracks first so upper tracks end up on top.
        for (final track in project.tracks.reversed) {
          if (track.kind != TrackKind.text || !track.isVisible) continue;
          for (final clip in track.clips) {
            final text = clip.text;
            if (text == null || !clip.containsTime(position)) continue;
            children.add(
              Positioned(
                left: text.x * box.maxWidth,
                top: text.y * box.maxHeight,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Opacity(
                    opacity: clip.opacity.clamp(0.0, 1.0).toDouble(),
                    child: Text(
                      text.content,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: text.fontSize * scale,
                        color: Color(text.color),
                        fontWeight: FontWeight.w700,
                        shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }
        return IgnorePointer(child: Stack(children: children));
      },
    );
  }
}

/// Invisible players for everything audible that isn't the on-screen video:
/// audio-track clips and video clips hidden behind / outside the visual layer.
class _AudioLayer extends ConsumerWidget {
  const _AudioLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final position = ref.watch(playbackProvider.select((s) => s.position));
    final visibleIds = {for (final c in ref.watch(activeVisualClipsProvider).clips) c.id};

    final players = <Widget>[];
    for (final track in project.tracks) {
      if (track.isMuted || !track.hasAudio) continue;
      for (final clip in track.clips) {
        if (!clip.containsTime(position)) continue;
        if (clip.kind != ClipKind.audio && clip.kind != ClipKind.video) continue;
        if (clip.kind == ClipKind.video && visibleIds.contains(clip.id)) continue;
        final MediaAsset? asset = project.assetById(clip.assetId);
        if (asset == null || !asset.hasAudio) continue;
        players.add(
          ClipPlayer(
            key: ValueKey('audio_${clip.id}'),
            clip: clip,
            asset: asset,
            muted: false,
            showVideo: false,
            audioFadeOut: project.crossfadeOutOf(clip),
          ),
        );
      }
    }
    return Stack(children: players);
  }
}

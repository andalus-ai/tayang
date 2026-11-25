import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/clip.dart';
import '../domain/models/track.dart';
import 'playback_controller.dart';
import 'project_controller.dart';

/// Value-equal wrapper so the preview only rebuilds when the *set* of visible
/// clips changes, not on every playback tick.
class ActiveClips {
  const ActiveClips(this.clips);

  final List<TimelineClip> clips;

  @override
  bool operator ==(Object other) {
    if (other is! ActiveClips || other.clips.length != clips.length) return false;
    for (var i = 0; i < clips.length; i++) {
      if (other.clips[i] != clips[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(clips);
}

/// Every picture on screen at the playhead, ordered bottom → top: clips of all
/// visible video tracks (picture-in-picture) plus overlapping clips on one
/// track (crossfades, later start = on top).
final activeVisualClipsProvider = Provider<ActiveClips>((ref) {
  final project = ref.watch(projectProvider);
  final position = ref.watch(playbackProvider.select((s) => s.position));
  final out = <TimelineClip>[];
  for (final track in project.tracks.reversed) {
    if (track.kind != TrackKind.video || !track.isVisible) continue;
    final inTrack = [
      for (final clip in track.clips)
        if (clip.containsTime(position)) clip,
    ]..sort((a, b) => a.start.compareTo(b.start));
    out.addAll(inTrack);
  }
  return ActiveClips(out);
});

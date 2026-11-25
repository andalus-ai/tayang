import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/clip.dart';
import '../domain/models/track.dart';
import 'playback_controller.dart';
import 'project_controller.dart';

/// The clip whose picture is on screen at the playhead (top-most visible video
/// track wins). TimelineClip has value-equality, so this only notifies on a real change.
final activeVisualClipProvider = Provider<TimelineClip?>((ref) {
  final project = ref.watch(projectProvider);
  final position = ref.watch(playbackProvider.select((s) => s.position));
  for (final track in project.tracks) {
    if (track.kind != TrackKind.video || !track.isVisible) continue;
    for (final clip in track.clips) {
      if (clip.containsTime(position)) return clip;
    }
  }
  return null;
});

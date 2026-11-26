import '../../../domain/models/clip.dart';
import '../../../domain/models/project.dart';

/// Everything a timeline clip widget needs, as a value-equal object so
/// `ref.watch(select(...))` only rebuilds that one clip when *its* data changes.
class ClipPlacement {
  const ClipPlacement(this.clip, this.lane, this.locked, this.dimmed);

  final TimelineClip clip;
  final int lane;
  final bool locked;
  final bool dimmed;

  @override
  bool operator ==(Object other) =>
      other is ClipPlacement &&
      other.clip == clip &&
      other.lane == lane &&
      other.locked == locked &&
      other.dimmed == dimmed;

  @override
  int get hashCode => Object.hash(clip, lane, locked, dimmed);
}

ClipPlacement? placementOf(Project p, String clipId) {
  for (var lane = 0; lane < p.tracks.length; lane++) {
    final track = p.tracks[lane];
    for (final clip in track.clips) {
      if (clip.id == clipId) {
        return ClipPlacement(
          clip,
          lane,
          track.isLocked,
          track.isLocked || (!track.isVisible && track.hasVisual),
        );
      }
    }
  }
  return null;
}

/// The ids of all clips (structure only). Equal while clips are merely moved,
/// trimmed or edited, so the clips layer doesn't rebuild during a drag.
class ClipLayout {
  const ClipLayout(this.ids);

  final List<String> ids;

  @override
  bool operator ==(Object other) {
    if (other is! ClipLayout || other.ids.length != ids.length) return false;
    for (var i = 0; i < ids.length; i++) {
      if (other.ids[i] != ids[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(ids);
}

ClipLayout layoutOf(Project p) => ClipLayout([
      for (final track in p.tracks)
        for (final clip in track.clips) clip.id,
    ]);

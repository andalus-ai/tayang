import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/id.dart';
import '../domain/models/clip.dart';
import '../domain/models/history.dart';
import '../domain/models/keyframes.dart';
import '../domain/models/media_asset.dart';
import '../domain/models/project.dart';
import '../domain/models/track.dart';
import '../domain/services/timeline_editor.dart';
import 'di.dart';
import 'playback_controller.dart';

/// Owns the project + its undo/redo history and exposes intent-level commands.
/// All the actual editing maths lives in [TimelineEditor]; this class only
/// manages state, history and gesture transactions.
class ProjectController extends Notifier<History<Project>> {
  /// Snapshot taken when a continuous gesture (drag, slider) starts, so the
  /// whole gesture becomes ONE undo step.
  Project? _gestureBase;

  @override
  History<Project> build() => History(present: ref.read(initialProjectProvider));

  TimelineEditor get _editor => ref.read(timelineEditorProvider);
  Project get _project => state.present;
  Duration get _playhead => ref.read(playbackProvider).position;

  // ----------------------------------------------------- history & gestures

  void _commit(Project next) {
    endGesture();
    state = state.push(next);
  }

  void _live(Project next) {
    if (identical(next, state.present)) return;
    _gestureBase ??= state.present;
    state = state.replacePresent(next);
  }

  /// Call when a drag / slider ends.
  void endGesture() {
    final base = _gestureBase;
    if (base == null) return;
    _gestureBase = null;
    if (!identical(base, state.present)) state = state.commitFrom(base);
  }

  void undo() {
    endGesture();
    state = state.undo();
  }

  void redo() {
    endGesture();
    state = state.redo();
  }

  // ---------------------------------------------------------------- project

  void replaceProject(Project project) => state = History(present: project);

  void rename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _commit(_project.copyWith(name: trimmed));
  }

  void setCanvas(int width, int height) =>
      _commit(_project.copyWith(width: width, height: height));

  void setFps(int fps) => _commit(_project.copyWith(fps: fps));

  // ----------------------------------------------------------------- assets

  void addAssets(Iterable<MediaAsset> assets) =>
      _commit(assets.fold(_project, _editor.addAsset));

  void relinkAsset(MediaAsset replacement) =>
      _commit(_editor.relinkAsset(_project, replacement));

  void removeAsset(String assetId) =>
      _commit(_editor.removeAsset(_project, assetId));

  // ------------------------------------------------------------------ clips

  /// Returns the new clip's id.
  String addClipFromAsset(MediaAsset asset, {Duration? at, String? trackId}) {
    final id = newId('clip_');
    _commit(_editor.addClipFromAsset(
      _project,
      asset,
      clipId: id,
      newTrackId: newId('track_'),
      at: at ?? _playhead,
      trackId: trackId,
    ));
    return id;
  }

  String addText({Duration? at}) {
    final id = newId('clip_');
    _commit(_editor.addTextClip(
      _project,
      clipId: id,
      newTrackId: newId('track_'),
      at: at ?? _playhead,
    ));
    return id;
  }

  void moveClipLive(
    String clipId,
    Duration start, {
    String? toTrackId,
    Duration snapThreshold = Duration.zero,
  }) {
    _live(_editor.moveClip(
      _project,
      clipId,
      start,
      toTrackId: toTrackId,
      snapPoints: [..._editor.edgePoints(_project, exclude: clipId), _playhead],
      snapThreshold: snapThreshold,
    ));
  }

  void trimClipStartLive(String clipId, Duration start) =>
      _live(_editor.trimClipStart(_project, clipId, start));

  void trimClipEndLive(String clipId, Duration end) =>
      _live(_editor.trimClipEnd(_project, clipId, end));

  void updateClipLive(String clipId, TimelineClip Function(TimelineClip) update) =>
      _live(_editor.updateClip(_project, clipId, update));

  void setSpeedLive(String clipId, double speed) =>
      _live(_editor.setSpeed(_project, clipId, speed));

  void updateClip(String clipId, TimelineClip Function(TimelineClip) update) =>
      _commit(_editor.updateClip(_project, clipId, update));

  void setSpeed(String clipId, double speed) =>
      _commit(_editor.setSpeed(_project, clipId, speed));

  // -------------------------------------------------------------- keyframes

  /// Sets a keyframe at the playhead (ignored if the playhead is outside the clip).
  void setKeyframeLive(String clipId, KeyframeProperty property, double value) =>
      _live(_editor.setKeyframe(_project, clipId, property, _playhead, value));

  void setKeyframe(String clipId, KeyframeProperty property, double value) =>
      _commit(_editor.setKeyframe(_project, clipId, property, _playhead, value));

  void removeKeyframe(String clipId, KeyframeProperty property, int index) =>
      _commit(_editor.removeKeyframe(_project, clipId, property, index));

  void clearKeyframes(String clipId, KeyframeProperty property) =>
      _commit(_editor.clearKeyframes(_project, clipId, property));

  void addTransition(String clipId,
          {Duration length = const Duration(milliseconds: 500)}) =>
      _commit(_editor.addTransition(_project, clipId, length));

  void addCrossfade(String clipId, {Duration length = const Duration(seconds: 1)}) =>
      _commit(_editor.addCrossfade(_project, clipId, length));

  void removeCrossfade(String clipId) =>
      _commit(_editor.removeCrossfade(_project, clipId));

  String pasteClip(TimelineClip clip, {Duration? at}) {
    final id = newId('clip_');
    _commit(_editor.insertClip(
      _project,
      clip,
      newClipId: id,
      newTrackId: newId('track_'),
      at: at ?? _playhead,
    ));
    return id;
  }

  /// Splits [clipId] at [at]; with no id, splits every unlocked clip under [at].
  void splitAt(Duration at, {String? clipId}) {
    var p = _project;
    final targets = clipId != null
        ? [clipId]
        : [
            for (final t in p.tracks)
              if (!t.isLocked)
                for (final c in t.clips)
                  if (c.start < at && at < c.end) c.id,
          ];
    for (final id in targets) {
      p = _editor.splitClip(p, id, at, rightClipId: newId('clip_'));
    }
    _commit(p);
  }

  void deleteClip(String clipId, {bool ripple = false}) =>
      _commit(_editor.deleteClip(_project, clipId, ripple: ripple));

  String duplicateClip(String clipId) {
    final id = newId('clip_');
    _commit(_editor.duplicateClip(_project, clipId, newClipId: id));
    return id;
  }

  // ----------------------------------------------------------------- tracks

  void addTrack(TrackKind kind) =>
      _commit(_editor.addTrack(_project, kind, trackId: newId('track_')));

  void removeTrack(String trackId) =>
      _commit(_editor.removeTrack(_project, trackId));

  void updateTrack(String trackId, Track Function(Track) update) =>
      _commit(_editor.updateTrack(_project, trackId, update));
}

final projectControllerProvider =
    NotifierProvider<ProjectController, History<Project>>(ProjectController.new);

/// The current project snapshot. Watch with `.select` for fine-grained rebuilds.
final projectProvider =
    Provider<Project>((ref) => ref.watch(projectControllerProvider).present);

final canUndoProvider =
    Provider<bool>((ref) => ref.watch(projectControllerProvider).canUndo);

final canRedoProvider =
    Provider<bool>((ref) => ref.watch(projectControllerProvider).canRedo);

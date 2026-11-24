import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/media_asset.dart';
import '../domain/models/track.dart';
import 'playback_controller.dart';
import 'project_controller.dart';
import 'selection_controller.dart';

/// Use-case layer: orchestrates several controllers so that toolbar buttons,
/// keyboard shortcuts and drag-and-drop all trigger exactly the same behaviour.
class EditorActions {
  EditorActions(this._ref);

  final Ref _ref;

  ProjectController get _project => _ref.read(projectControllerProvider.notifier);
  PlaybackController get _playback => _ref.read(playbackProvider.notifier);
  SelectionController get _selection => _ref.read(selectionProvider.notifier);
  Duration get _playhead => _ref.read(playbackProvider).position;
  String? get _selectedId => _ref.read(selectionProvider);

  void addAsset(MediaAsset asset, {Duration? at, String? trackId}) {
    final id = _project.addClipFromAsset(asset, at: at ?? _playhead, trackId: trackId);
    _selection.select(id);
  }

  void addText() => _selection.select(_project.addText(at: _playhead));

  void addTrack(TrackKind kind) => _project.addTrack(kind);

  /// Splits the selected clip if the playhead is inside it, otherwise every
  /// unlocked clip under the playhead.
  void splitAtPlayhead() {
    final at = _playhead;
    final id = _selectedId;
    final clip = id == null ? null : _ref.read(projectProvider).clipById(id);
    final selectedUnderPlayhead = clip != null && clip.containsTime(at);
    _project.splitAt(at, clipId: selectedUnderPlayhead ? id : null);
  }

  void deleteSelected({bool ripple = false}) {
    final id = _selectedId;
    if (id != null) _project.deleteClip(id, ripple: ripple);
  }

  void duplicateSelected() {
    final id = _selectedId;
    if (id != null) _selection.select(_project.duplicateClip(id));
  }

  void togglePlay() => _playback.toggle();
  void seekToStart() => _playback.seek(Duration.zero);
  void seekToEnd() => _playback.seek(_ref.read(projectProvider).duration);
  void stepFrames(int frames) => _playback.stepFrames(frames);
  void undo() => _project.undo();
  void redo() => _project.redo();
}

final editorActionsProvider =
    Provider<EditorActions>((ref) => EditorActions(ref));

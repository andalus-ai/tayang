import '../../core/utils/id.dart';
import 'clip.dart';
import 'media_asset.dart';
import 'track.dart';

/// The whole editable document. Immutable: every edit produces a new [Project].
class Project {
  const Project({
    required this.id,
    required this.name,
    this.tracks = const [],
    this.assets = const [],
    this.width = 1920,
    this.height = 1080,
    this.fps = 30,
  });

  factory Project.empty() => Project(
        id: newId('project_'),
        name: 'Untitled project',
        tracks: [
          Track(id: newId('track_'), kind: TrackKind.text, name: 'Text 1'),
          Track(id: newId('track_'), kind: TrackKind.video, name: 'Video 1'),
          Track(id: newId('track_'), kind: TrackKind.audio, name: 'Audio 1'),
        ],
      );

  final String id;
  final String name;
  final List<Track> tracks;
  final List<MediaAsset> assets;
  final int width;
  final int height;
  final int fps;

  Duration get duration {
    var end = Duration.zero;
    for (final track in tracks) {
      final e = track.end;
      if (e > end) end = e;
    }
    return end;
  }

  Track? trackById(String id) {
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Track? trackOfClip(String clipId) {
    for (final t in tracks) {
      for (final c in t.clips) {
        if (c.id == clipId) return t;
      }
    }
    return null;
  }

  TimelineClip? clipById(String id) {
    for (final t in tracks) {
      for (final c in t.clips) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  MediaAsset? assetById(String? id) {
    if (id == null) return null;
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// The clip on the same track that starts inside [clip] with a fade-in, i.e.
  /// the clip this one is crossfading into.
  TimelineClip? crossfadeTarget(TimelineClip clip) {
    final track = trackOfClip(clip.id);
    if (track == null) return null;
    for (final c in track.clips) {
      if (c.id != clip.id &&
          c.start > clip.start &&
          c.start < clip.end &&
          c.fadeIn > Duration.zero) {
        return c;
      }
    }
    return null;
  }

  /// Length of the crossfade at the end of [clip] (zero when there is none).
  Duration crossfadeOutOf(TimelineClip clip) {
    final next = crossfadeTarget(clip);
    return next == null ? Duration.zero : clip.end - next.start;
  }

  /// Whether [clipId] overlaps the end of an earlier clip on its track.
  bool hasCrossfadeIn(String clipId) {
    final clip = clipById(clipId);
    final track = trackOfClip(clipId);
    if (clip == null || track == null) return false;
    return track.clips.any((a) => a.id != clipId && a.start < clip.start && a.end > clip.start);
  }

  Project copyWith({
    String? name,
    List<Track>? tracks,
    List<MediaAsset>? assets,
    int? width,
    int? height,
    int? fps,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        tracks: tracks ?? this.tracks,
        assets: assets ?? this.assets,
        width: width ?? this.width,
        height: height ?? this.height,
        fps: fps ?? this.fps,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'id': id,
        'name': name,
        'width': width,
        'height': height,
        'fps': fps,
        'assets': [for (final a in assets) a.toJson()],
        'tracks': [for (final t in tracks) t.toJson()],
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
        fps: json['fps'] as int,
        assets: [
          for (final a in json['assets'] as List<dynamic>)
            MediaAsset.fromJson(a as Map<String, dynamic>),
        ],
        tracks: [
          for (final t in json['tracks'] as List<dynamic>)
            Track.fromJson(t as Map<String, dynamic>),
        ],
      );
}

import 'clip.dart';

enum TrackKind {
  video,
  audio,
  text;

  String get label => switch (this) {
        TrackKind.video => 'Video',
        TrackKind.audio => 'Audio',
        TrackKind.text => 'Text',
      };

  bool accepts(ClipKind clip) => switch (this) {
        TrackKind.video => clip == ClipKind.video || clip == ClipKind.image,
        TrackKind.audio => clip == ClipKind.audio,
        TrackKind.text => clip == ClipKind.text,
      };

  static TrackKind forClip(ClipKind clip) => switch (clip) {
        ClipKind.video || ClipKind.image => TrackKind.video,
        ClipKind.audio => TrackKind.audio,
        ClipKind.text => TrackKind.text,
      };
}

/// Tracks are ordered top → bottom; upper tracks are composited on top.
class Track {
  const Track({
    required this.id,
    required this.kind,
    required this.name,
    this.clips = const [],
    this.isMuted = false,
    this.isLocked = false,
    this.isVisible = true,
  });

  final String id;
  final TrackKind kind;
  final String name;
  final List<TimelineClip> clips;
  final bool isMuted;
  final bool isLocked;
  final bool isVisible;

  bool get hasAudio => kind != TrackKind.text;
  bool get hasVisual => kind != TrackKind.audio;

  Duration get end {
    var end = Duration.zero;
    for (final clip in clips) {
      if (clip.end > end) end = clip.end;
    }
    return end;
  }

  Track copyWith({
    String? name,
    List<TimelineClip>? clips,
    bool? isMuted,
    bool? isLocked,
    bool? isVisible,
  }) =>
      Track(
        id: id,
        kind: kind,
        name: name ?? this.name,
        clips: clips ?? this.clips,
        isMuted: isMuted ?? this.isMuted,
        isLocked: isLocked ?? this.isLocked,
        isVisible: isVisible ?? this.isVisible,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'clips': [for (final c in clips) c.toJson()],
        'isMuted': isMuted,
        'isLocked': isLocked,
        'isVisible': isVisible,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        kind: TrackKind.values.byName(json['kind'] as String),
        name: json['name'] as String,
        clips: [
          for (final c in json['clips'] as List<dynamic>)
            TimelineClip.fromJson(c as Map<String, dynamic>),
        ],
        isMuted: json['isMuted'] as bool,
        isLocked: json['isLocked'] as bool,
        isVisible: json['isVisible'] as bool,
      );
}

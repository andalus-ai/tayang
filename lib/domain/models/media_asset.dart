enum MediaKind { video, audio, image }

abstract final class MediaKinds {
  static const _video = {'mp4', 'mov', 'm4v', 'mkv', 'webm', 'avi', '3gp'};
  static const _audio = {'mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'};
  static const _image = {'jpg', 'jpeg', 'png', 'webp', 'bmp'};

  static List<String> get allExtensions => [..._video, ..._audio, ..._image];

  static MediaKind? fromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = path.substring(dot + 1).toLowerCase();
    if (_video.contains(ext)) return MediaKind.video;
    if (_audio.contains(ext)) return MediaKind.audio;
    if (_image.contains(ext)) return MediaKind.image;
    return null;
  }
}

/// A file that has been imported into the project's media pool.
class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.path,
    required this.name,
    required this.kind,
    this.duration = Duration.zero,
    this.width,
    this.height,
    this.hasAudio = true,
  });

  final String id;
  final String path;
  final String name;
  final MediaKind kind;

  /// Zero for still images.
  final Duration duration;
  final int? width;
  final int? height;
  final bool hasAudio;

  bool get isTimeBased => kind != MediaKind.image;

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'name': name,
        'kind': kind.name,
        'duration': duration.inMicroseconds,
        'width': width,
        'height': height,
        'hasAudio': hasAudio,
      };

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        id: json['id'] as String,
        path: json['path'] as String,
        name: json['name'] as String,
        kind: MediaKind.values.byName(json['kind'] as String),
        duration: Duration(microseconds: json['duration'] as int),
        width: json['width'] as int?,
        height: json['height'] as int?,
        hasAudio: json['hasAudio'] as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is MediaAsset && other.id == id && other.path == path;

  @override
  int get hashCode => Object.hash(id, path);
}

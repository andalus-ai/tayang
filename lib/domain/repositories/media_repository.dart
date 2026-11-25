import '../models/media_asset.dart';

class MediaProbeException implements Exception {
  const MediaProbeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads technical metadata (duration, size, audio presence) from a file.
abstract interface class MediaProbe {
  Future<MediaAsset> probe(String path);
}

/// Lets the user choose media and returns analysed [MediaAsset]s.
abstract interface class MediaRepository {
  Future<List<MediaAsset>> pickAndImport();
}

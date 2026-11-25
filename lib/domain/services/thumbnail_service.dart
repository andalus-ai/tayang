import '../models/media_asset.dart';

abstract interface class ThumbnailService {
  /// Path of a small JPEG preview for [asset], or null (audio / failure).
  Future<String?> thumbnail(MediaAsset asset);
}

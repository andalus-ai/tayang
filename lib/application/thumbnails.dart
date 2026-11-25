import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/media_asset.dart';
import 'di.dart';

/// Thumbnail file path for an asset (null while unavailable / for audio).
final thumbnailPathProvider = FutureProvider.family<String?, MediaAsset>(
  (ref, asset) => ref.watch(thumbnailServiceProvider).thumbnail(asset),
);

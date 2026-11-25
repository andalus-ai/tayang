import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/media_asset.dart';
import 'di.dart';

/// Thumbnail file path for an asset (null while unavailable / for audio).
final thumbnailPathProvider = FutureProvider.family<String?, MediaAsset>(
  (ref, asset) => ref.watch(thumbnailServiceProvider).thumbnail(asset),
);

/// Waveform image path for an asset with audio (null while unavailable).
final waveformPathProvider = FutureProvider.family<String?, MediaAsset>(
  (ref, asset) => ref.watch(waveformServiceProvider).waveform(asset),
);

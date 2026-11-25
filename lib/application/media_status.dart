import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/media_asset.dart';
import 'di.dart';

/// True when the asset's source file can no longer be found on disk.
final assetMissingProvider = Provider.family<bool, MediaAsset>(
  (ref, asset) => !ref.watch(fileExistsProvider)(asset.path),
);

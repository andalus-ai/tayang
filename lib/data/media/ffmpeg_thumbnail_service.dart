import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/media_asset.dart';
import '../../domain/services/thumbnail_service.dart';

/// Runs FFmpeg with the given arguments; true on success.
typedef FfmpegRun = Future<bool> Function(List<String> args);

class FfmpegThumbnailService implements ThumbnailService {
  FfmpegThumbnailService({required FfmpegRun run, required Future<Directory> Function() cacheDir})
      : _run = run,
        _cacheDir = cacheDir;

  final FfmpegRun _run;
  final Future<Directory> Function() _cacheDir;
  final _inflight = <String, Future<String?>>{};

  @override
  Future<String?> thumbnail(MediaAsset asset) {
    if (asset.kind == MediaKind.audio) return Future.value(null);
    return _inflight.putIfAbsent(asset.id, () => _create(asset));
  }

  Future<String?> _create(MediaAsset asset) async {
    try {
      final dir = await _cacheDir();
      final out = File(p.join(dir.path, '${asset.id}.jpg'));
      if (await out.exists()) return out.path;

      final seekSeconds = asset.kind == MediaKind.video
          ? (asset.duration.inMilliseconds / 2000).clamp(0.0, 1.0).toDouble()
          : 0.0;
      final ok = await _run([
        '-y',
        '-ss', seekSeconds.toStringAsFixed(2),
        '-i', asset.path,
        '-frames:v', '1',
        '-vf', 'scale=240:-2',
        '-q:v', '4',
        out.path,
      ]);
      return ok && await out.exists() ? out.path : null;
    } catch (_) {
      return null;
    }
  }
}

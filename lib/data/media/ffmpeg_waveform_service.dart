import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/media_asset.dart';
import '../../domain/services/waveform_service.dart';
import 'ffmpeg_thumbnail_service.dart';

class FfmpegWaveformService implements WaveformService {
  FfmpegWaveformService({required FfmpegRun run, required Future<Directory> Function() cacheDir})
      : _run = run,
        _cacheDir = cacheDir;

  final FfmpegRun _run;
  final Future<Directory> Function() _cacheDir;
  final _inflight = <String, Future<String?>>{};

  @override
  Future<String?> waveform(MediaAsset asset) {
    if (!asset.isTimeBased || !asset.hasAudio) return Future.value(null);
    return _inflight.putIfAbsent(asset.id, () => _create(asset));
  }

  Future<String?> _create(MediaAsset asset) async {
    try {
      final dir = await _cacheDir();
      final out = File(p.join(dir.path, '${asset.id}_wave.png'));
      if (await out.exists()) return out.path;
      final ok = await _run([
        '-y',
        '-i', asset.path,
        '-filter_complex',
        '[0:a]aformat=channel_layouts=mono,showwavespic=s=1600x120:colors=white,'
            'format=rgba,colorkey=0x000000:0.1:0.1[v]',
        '-map', '[v]',
        '-frames:v', '1',
        out.path,
      ]);
      return ok && await out.exists() ? out.path : null;
    } catch (_) {
      return null;
    }
  }
}

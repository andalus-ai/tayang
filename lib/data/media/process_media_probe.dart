import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/duration_x.dart';
import '../../core/utils/id.dart';
import '../../domain/models/media_asset.dart';
import '../../domain/repositories/media_repository.dart';

/// `MediaProbe` backed by a system `ffprobe` binary.
class ProcessMediaProbe implements MediaProbe {
  ProcessMediaProbe({this.executable = 'ffprobe'});

  final String executable;

  @override
  Future<MediaAsset> probe(String path) async {
    final kind = MediaKinds.fromPath(path);
    if (kind == null) {
      throw MediaProbeException('Unsupported file type: ${p.basename(path)}');
    }

    final ProcessResult result;
    try {
      result = await Process.run(executable, [
        '-v', 'error',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        path,
      ]);
    } on ProcessException {
      throw MediaProbeException('"$executable" not found. Install FFmpeg and add it to PATH.');
    }
    if (result.exitCode != 0) {
      throw MediaProbeException('Could not read ${p.basename(path)}');
    }

    final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final streams = ((json['streams'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>();
    final video = streams.where((s) => s['codec_type'] == 'video').firstOrNull;
    final hasAudio = streams.any((s) => s['codec_type'] == 'audio');
    final format = json['format'] as Map<String, dynamic>?;
    final seconds = double.tryParse('${format?['duration'] ?? ''}') ?? 0;

    return MediaAsset(
      id: newId('asset_'),
      path: path,
      name: p.basename(path),
      kind: kind,
      duration: kind == MediaKind.image ? Duration.zero : secondsToDuration(seconds),
      width: video?['width'] as int?,
      height: video?['height'] as int?,
      hasAudio: kind != MediaKind.image && hasAudio,
    );
  }
}

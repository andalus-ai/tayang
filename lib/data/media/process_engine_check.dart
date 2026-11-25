import 'dart:io';

import '../../domain/services/engine_check.dart';

/// Verifies that system `ffmpeg` and `ffprobe` can be started (Linux).
class ProcessEngineCheck implements EngineCheck {
  @override
  Future<EngineStatus> check() async {
    final missing = <String>[];
    for (final tool in const ['ffmpeg', 'ffprobe']) {
      try {
        final result = await Process.run(tool, ['-version']);
        if (result.exitCode != 0) missing.add(tool);
      } on ProcessException {
        missing.add(tool);
      }
    }
    if (missing.isEmpty) return const EngineStatus.ready();
    return EngineStatus.missing(
      'FFmpeg tools not found (${missing.join(', ')}). Install FFmpeg, for example '
      '"sudo apt install ffmpeg", then restart Tayang to import and export media.',
    );
  }
}

/// Platforms that bundle FFmpeg (FFmpegKit) need no external install.
class BundledEngineCheck implements EngineCheck {
  @override
  Future<EngineStatus> check() async => const EngineStatus.ready();
}

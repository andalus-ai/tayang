import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/export/export_paths.dart';
import '../data/export/ffmpeg_runners.dart';
import '../data/export/ffmpeg_video_exporter.dart';
import '../data/export/process_video_exporter.dart';
import '../data/media/ffmpeg_thumbnail_service.dart';
import '../data/media/ffmpeg_waveform_service.dart';
import '../data/media/ffprobe_media_probe.dart';
import '../data/media/process_engine_check.dart';
import '../data/media/process_media_probe.dart';
import '../data/playback/player_pool.dart';
import '../data/repositories/file_media_repository.dart';
import '../data/repositories/json_project_repository.dart';
import '../data/repositories/json_settings_repository.dart';
import '../domain/export/video_exporter.dart';
import '../domain/models/project.dart';
import '../domain/repositories/media_repository.dart';
import '../domain/repositories/project_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/services/engine_check.dart';
import '../domain/services/thumbnail_service.dart';
import '../domain/services/timeline_editor.dart';
import '../domain/services/waveform_service.dart';

/// Composition root: the ONLY place that binds abstractions to implementations.
/// Override any of these in `main()` or in tests.

final initialProjectProvider = Provider<Project>((ref) => Project.empty());

/// Injected so "does this file exist?" can be faked in tests.
final fileExistsProvider =
    Provider<bool Function(String path)>((ref) => (path) => File(path).existsSync());

final timelineEditorProvider =
    Provider<TimelineEditor>((ref) => const TimelineEditor());

/// FFmpegKit has no Linux build, so Linux uses the system ffmpeg/ffprobe.
final bool _useSystemFfmpeg = Platform.isLinux;

final mediaProbeProvider = Provider<MediaProbe>(
  (ref) => _useSystemFfmpeg ? ProcessMediaProbe() : FfprobeMediaProbe(),
);

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => FileMediaRepository(probe: ref.watch(mediaProbeProvider)),
);

final projectRepositoryProvider =
    Provider<ProjectRepository>((ref) => JsonProjectRepository());

final videoExporterProvider = Provider<VideoExporter>(
  (ref) => _useSystemFfmpeg ? ProcessVideoExporter() : FfmpegVideoExporter(),
);

final thumbnailServiceProvider = Provider<ThumbnailService>(
  (ref) => FfmpegThumbnailService(
    run: _useSystemFfmpeg ? processRunner() : runWithFfmpegKit,
    cacheDir: () async {
      final tmp = await getTemporaryDirectory();
      return Directory(p.join(tmp.path, 'tayang_thumbs')).create(recursive: true);
    },
  ),
);

final exportPathResolverProvider =
    Provider<Future<String> Function(String fileName)>((ref) => defaultExportPath);

final playerPoolProvider = Provider<PlayerPool>((ref) {
  final pool = PlayerPool();
  ref.onDispose(pool.dispose);
  return pool;
});

final waveformServiceProvider = Provider<WaveformService>(
  (ref) => FfmpegWaveformService(
    run: _useSystemFfmpeg ? processRunner() : runWithFfmpegKit,
    cacheDir: () async {
      final tmp = await getTemporaryDirectory();
      return Directory(p.join(tmp.path, 'tayang_thumbs')).create(recursive: true);
    },
  ),
);

final engineCheckProvider = Provider<EngineCheck>(
  (ref) => _useSystemFfmpeg ? ProcessEngineCheck() : BundledEngineCheck(),
);

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => JsonSettingsRepository());

/// Overridden in `main()` with the persisted value. Defaults to "seen" so tests
/// and previews don't pop a dialog.
final initialWelcomeSeenProvider = Provider<bool>((ref) => true);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/export/export_paths.dart';
import '../data/export/ffmpeg_video_exporter.dart';
import '../data/media/ffprobe_media_probe.dart';
import '../data/playback/player_pool.dart';
import '../data/repositories/file_media_repository.dart';
import '../data/repositories/json_project_repository.dart';
import '../domain/export/video_exporter.dart';
import '../domain/models/project.dart';
import '../domain/repositories/media_repository.dart';
import '../domain/repositories/project_repository.dart';
import '../domain/services/timeline_editor.dart';

/// Composition root: the ONLY place that binds abstractions to implementations.
/// Override any of these in `main()` or in tests.

final initialProjectProvider = Provider<Project>((ref) => Project.empty());

final timelineEditorProvider =
    Provider<TimelineEditor>((ref) => const TimelineEditor());

final mediaProbeProvider = Provider<MediaProbe>((ref) => FfprobeMediaProbe());

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => FileMediaRepository(probe: ref.watch(mediaProbeProvider)),
);

final projectRepositoryProvider =
    Provider<ProjectRepository>((ref) => JsonProjectRepository());

final videoExporterProvider =
    Provider<VideoExporter>((ref) => FfmpegVideoExporter());

final exportPathResolverProvider =
    Provider<Future<String> Function(String fileName)>((ref) => defaultExportPath);

final playerPoolProvider = Provider<PlayerPool>((ref) {
  final pool = PlayerPool();
  ref.onDispose(pool.dispose);
  return pool;
});

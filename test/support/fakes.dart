import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayang/application/di.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/repositories/media_repository.dart';
import 'package:tayang/domain/repositories/project_repository.dart';
import 'package:tayang/domain/repositories/settings_repository.dart';
import 'package:tayang/domain/repositories/subtitle_source.dart';
import 'package:tayang/domain/services/subtitle_parser.dart';
import 'package:tayang/domain/services/engine_check.dart';
import 'package:tayang/domain/services/thumbnail_service.dart';
import 'package:tayang/domain/services/waveform_service.dart';

class FakeThumbnails implements ThumbnailService {
  @override
  Future<String?> thumbnail(MediaAsset asset) async => null;
}

class FakeWaveforms implements WaveformService {
  @override
  Future<String?> waveform(MediaAsset asset) async => null;
}

class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository([List<Project> projects = const []])
      : stored = {for (final p in projects) p.id: p};

  final Map<String, Project> stored;

  @override
  Future<void> save(Project project) async => stored[project.id] = project;

  @override
  Future<Project?> loadLatest() async => null;

  @override
  Future<List<ProjectSummary>> list() async => [
        for (final p in stored.values)
          ProjectSummary(
            id: p.id,
            name: p.name,
            modified: DateTime(2026, 11, 28, 10, 30),
            duration: p.duration,
            clipCount: p.tracks.fold(0, (n, t) => n + t.clips.length),
            assetCount: p.assets.length,
          ),
      ];

  @override
  Future<Project?> load(String id) async => stored[id];

  @override
  Future<void> delete(String id) async => stored.remove(id);
}

class FakeSubtitleSource implements SubtitleSource {
  FakeSubtitleSource(this.cues);
  final List<SubtitleCue>? cues;

  @override
  Future<List<SubtitleCue>?> pick() async => cues;
}

class FakeProbe implements MediaProbe {
  @override
  Future<MediaAsset> probe(String path) async =>
      throw const MediaProbeException('not available in tests');
}

class FakeExporter implements VideoExporter {
  @override
  Stream<ExportProgress> export(Project project, ExportSettings settings,
          {required String outputPath}) =>
      const Stream.empty();

  @override
  Future<void> cancel() async {}
}

class FakeEngineCheck implements EngineCheck {
  FakeEngineCheck(this.status);
  final EngineStatus status;

  @override
  Future<EngineStatus> check() async => status;
}

class FakeSettings implements SettingsRepository {
  bool seen = false;

  @override
  Future<bool> hasSeenWelcome() async => seen;

  @override
  Future<void> markWelcomeSeen() async => seen = true;
}

/// Replaces every platform-dependent service so widget tests need no FFmpeg,
/// disk or plugins.
List<Override> fakeOverrides({
  bool welcomeSeen = true,
  EngineStatus engine = const EngineStatus.ready(),
  FakeSettings? settings,
  FakeProjectRepository? projects,
  FakeSubtitleSource? subtitles,
}) =>
    [
      thumbnailServiceProvider.overrideWithValue(FakeThumbnails()),
      waveformServiceProvider.overrideWithValue(FakeWaveforms()),
      projectRepositoryProvider.overrideWithValue(projects ?? FakeProjectRepository()),
      subtitleSourceProvider.overrideWithValue(subtitles ?? FakeSubtitleSource(null)),
      mediaProbeProvider.overrideWithValue(FakeProbe()),
      videoExporterProvider.overrideWithValue(FakeExporter()),
      engineCheckProvider.overrideWithValue(FakeEngineCheck(engine)),
      settingsRepositoryProvider.overrideWithValue(settings ?? FakeSettings()),
      initialWelcomeSeenProvider.overrideWithValue(welcomeSeen),
    ];

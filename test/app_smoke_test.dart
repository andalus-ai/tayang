import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/app.dart';
import 'package:tayang/application/di.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/repositories/media_repository.dart';
import 'package:tayang/domain/repositories/project_repository.dart';
import 'package:tayang/domain/services/thumbnail_service.dart';
import 'package:tayang/domain/services/waveform_service.dart';

class _FakeThumbnails implements ThumbnailService {
  @override
  Future<String?> thumbnail(MediaAsset asset) async => null;
}

class _FakeWaveforms implements WaveformService {
  @override
  Future<String?> waveform(MediaAsset asset) async => null;
}

class _FakeRepository implements ProjectRepository {
  @override
  Future<void> save(Project project) async {}

  @override
  Future<Project?> loadLatest() async => null;
}

class _FakeProbe implements MediaProbe {
  @override
  Future<MediaAsset> probe(String path) async =>
      throw const MediaProbeException('not available in tests');
}

class _FakeExporter implements VideoExporter {
  @override
  Stream<ExportProgress> export(Project project, ExportSettings settings,
          {required String outputPath}) =>
      const Stream.empty();

  @override
  Future<void> cancel() async {}
}

void main() {
  testWidgets('add a text clip, then undo it', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thumbnailServiceProvider.overrideWithValue(_FakeThumbnails()),
          waveformServiceProvider.overrideWithValue(_FakeWaveforms()),
          projectRepositoryProvider.overrideWithValue(_FakeRepository()),
          mediaProbeProvider.overrideWithValue(_FakeProbe()),
          videoExporterProvider.overrideWithValue(_FakeExporter()),
        ],
        child: const TayangApp(),
      ),
    );
    await tester.pump();

    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.text('Your text'), findsNothing);

    await tester.tap(find.byTooltip('Add text at playhead'));
    await tester.pump();
    expect(find.text('Your text'), findsWidgets);

    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pump();
    expect(find.text('Your text'), findsNothing);

    // Let the autosave debounce timer finish.
    await tester.pump(const Duration(seconds: 3));
  });
}

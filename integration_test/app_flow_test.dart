import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tayang/app.dart';
import 'package:tayang/application/di.dart';
import 'package:tayang/application/project_controller.dart';
import 'package:tayang/data/media/ffprobe_media_probe.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/repositories/media_repository.dart';
import 'package:tayang/domain/repositories/project_repository.dart';
import 'package:tayang/presentation/pages/editor_page.dart';
import 'package:tayang/presentation/widgets/timeline/timeline_ruler.dart';

import 'fixtures.dart';

/// Stands in for the native file dialog (which can't be automated): returns the
/// fixture files, analysed by the real FFprobe engine.
class _FixtureMediaRepository implements MediaRepository {
  _FixtureMediaRepository(this.paths);
  final List<String> paths;

  @override
  Future<List<MediaAsset>> pickAndImport() async =>
      [for (final p in paths) await FfprobeMediaProbe().probe(p)];
}

class _MemoryProjectRepository implements ProjectRepository {
  @override
  Future<void> save(Project project) async {}

  @override
  Future<Project?> loadLatest() async => null;
}

Future<void> _waitFor(WidgetTester tester, Finder finder, {int seconds = 60}) async {
  for (var i = 0; i < seconds * 3; i++) {
    await tester.pump(const Duration(milliseconds: 330));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

/// Drives the real app (real FFmpeg engine, real widgets) from import to export.
/// Desktop only: the compact phone layout hides the panels in sheets.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('import, edit and export through the real UI', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tmp = await getTemporaryDirectory();
    final root = await Directory('${tmp.path}/tayang_flow').create(recursive: true);
    Future<String> write(String name, String b64) async {
      final file = File('${root.path}/$name');
      await file.writeAsBytes(base64Decode(b64));
      return file.path;
    }

    final videoPath = await write('v.mp4', videoBase64);
    final imagePath = await write('i.png', imageBase64);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        mediaRepositoryProvider
            .overrideWithValue(_FixtureMediaRepository([videoPath, imagePath])),
        projectRepositoryProvider.overrideWithValue(_MemoryProjectRepository()),
        exportPathResolverProvider.overrideWithValue((name) async => '${root.path}/$name'),
      ],
      child: const TayangApp(),
    ));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(EditorPage)));
    int clipCount() =>
        container.read(projectProvider).tracks.expand((t) => t.clips).length;

    // ---- import
    await tester.tap(find.byTooltip('Import media'));
    await _waitFor(tester, find.text('v.mp4'));
    await _waitFor(tester, find.text('i.png'));

    expect(container.read(projectProvider).assets.length, 2);

    // ---- place the video on the timeline
    await tester.tap(find.byTooltip('Add to timeline at playhead').first);
    await tester.pumpAndSettle();
    expect(clipCount(), 1);
    expect(find.text('v.mp4'), findsWidgets);

    // ---- seek to 1s by clicking the ruler (80 px per second), then split
    final rulerTopLeft = tester.getTopLeft(find.byType(TimelineRuler));
    await tester.tapAt(rulerTopLeft + const Offset(80, 14));
    await tester.pump();
    await tester.tap(find.byTooltip('Split at playhead (S)'));
    await tester.pumpAndSettle();
    expect(clipCount(), 2, reason: 'split at 1s makes two halves');

    // ---- undo / redo
    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pumpAndSettle();
    expect(clipCount(), 1);
    await tester.tap(find.byTooltip('Redo (Ctrl+Shift+Z)'));
    await tester.pumpAndSettle();
    expect(clipCount(), 2);

    // ---- text overlay
    await tester.tap(find.byTooltip('Add text at playhead'));
    await tester.pumpAndSettle();
    expect(find.text('Your text'), findsWidgets);

    expect(clipCount(), 3, reason: '2 video halves + text');
    final project = container.read(projectProvider);

    // ---- export through the dialog
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Export'),
    ));
    await _waitFor(tester, find.textContaining('Export finished'), seconds: 180);

    final path = tester.widget<SelectableText>(find.byType(SelectableText).first).data!;
    expect(File(path).existsSync(), isTrue, reason: 'exported file at $path');

    final exported = await FfprobeMediaProbe().probe(path);
    expect(exported.duration.inMilliseconds,
        closeTo(project.duration.inMilliseconds, 700));
    expect(exported.hasAudio, isTrue);
    expect(exported.width, 1920); // default 1080p export of the 16:9 canvas
  }, timeout: const Timeout(Duration(minutes: 8)));
}

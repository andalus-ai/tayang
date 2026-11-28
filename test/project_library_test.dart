import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/app.dart';
import 'package:tayang/application/di.dart';
import 'package:tayang/application/project_controller.dart';
import 'package:tayang/data/repositories/json_project_repository.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';
import 'package:tayang/presentation/pages/editor_page.dart';

import 'support/fakes.dart';

Project _project(String id, String name, {int clips = 0}) {
  const editor = TimelineEditor();
  const asset = MediaAsset(
    id: 'a', path: '/x/a.mp4', name: 'a.mp4',
    kind: MediaKind.video, duration: Duration(seconds: 3),
  );
  var p = Project(
    id: id, name: name, assets: const [asset],
    tracks: const [Track(id: 'v', kind: TrackKind.video, name: 'V')],
  );
  for (var i = 0; i < clips; i++) {
    p = editor.addClipFromAsset(p, asset, clipId: '$id$i', newTrackId: 'x');
  }
  return p;
}

void main() {
  group('JsonProjectRepository (real files)', () {
    late Directory dir;
    late JsonProjectRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('tayang_repo_');
      repo = JsonProjectRepository(rootProvider: () async => dir);
    });
    tearDown(() => dir.delete(recursive: true));

    test('lists projects newest first with name, duration and clip count', () async {
      await repo.save(_project('p1', 'Older', clips: 1));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await repo.save(_project('p2', 'Newer', clips: 2));

      final list = await repo.list();
      expect(list.map((s) => s.name), ['Newer', 'Older']);
      expect(list.first.clipCount, 2);
      expect(list.first.duration, const Duration(seconds: 6));
      expect(list.last.assetCount, 1);
    });

    test('load returns the project and makes it the one reopened next time', () async {
      await repo.save(_project('p1', 'One'));
      await repo.save(_project('p2', 'Two')); // latest = p2
      expect((await repo.loadLatest())!.id, 'p2');

      final loaded = await repo.load('p1');
      expect(loaded!.name, 'One');
      expect((await repo.loadLatest())!.id, 'p1');
    });

    test('delete removes the file and clears the latest pointer if it pointed there', () async {
      await repo.save(_project('p1', 'One'));
      await repo.delete('p1');
      expect(await repo.list(), isEmpty);
      expect(await repo.loadLatest(), isNull);
      await repo.delete('does-not-exist'); // must not throw
    });

    test('corrupt files are ignored instead of breaking the list', () async {
      await repo.save(_project('p1', 'Good'));
      await File('${dir.path}/broken.json').writeAsString('{ not json');
      final list = await repo.list();
      expect(list.map((s) => s.name), ['Good']);
      expect(await repo.load('broken'), isNull);
    });
  });

  group('Projects dialog', () {
    Future<ProviderContainer> pump(WidgetTester tester, FakeProjectRepository repo) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...fakeOverrides(projects: repo),
          initialProjectProvider.overrideWithValue(_project('alpha', 'Alpha', clips: 1)),
        ],
        child: const TayangApp(),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(EditorPage)));
    }

    Finder inDialog(String text) =>
        find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

    testWidgets('lists saved projects, marks the open one, and opens another', (tester) async {
      final repo = FakeProjectRepository([_project('beta', 'Beta', clips: 2)]);
      final c = await pump(tester, repo);

      await tester.tap(find.byTooltip('Projects'));
      await tester.pumpAndSettle();

      expect(inDialog('Alpha'), findsOneWidget, reason: 'current project is saved + listed');
      expect(inDialog('Beta'), findsOneWidget);
      expect(find.textContaining('open now'), findsOneWidget);

      await tester.tap(inDialog('Beta'));
      await tester.pumpAndSettle();

      expect(c.read(projectProvider).id, 'beta');
      expect(find.byType(AlertDialog), findsNothing, reason: 'dialog closes after opening');
      expect(repo.stored.containsKey('alpha'), isTrue, reason: 'the project we left was saved');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('deleting a project asks first, then removes it', (tester) async {
      final repo = FakeProjectRepository([_project('beta', 'Beta')]);
      await pump(tester, repo);

      await tester.tap(find.byTooltip('Projects'));
      await tester.pumpAndSettle();
      // Rows: Alpha (current), Beta. Delete Beta.
      await tester.tap(find.byTooltip('Delete project').last);
      await tester.pumpAndSettle();
      expect(find.text('Delete "Beta"?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.stored.containsKey('beta'), isFalse);
      expect(inDialog('Beta'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('cancelling the confirmation keeps the project', (tester) async {
      final repo = FakeProjectRepository([_project('beta', 'Beta')]);
      await pump(tester, repo);
      await tester.tap(find.byTooltip('Projects'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete project').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.stored.containsKey('beta'), isTrue);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('deleting the open project starts a fresh one', (tester) async {
      final repo = FakeProjectRepository();
      final c = await pump(tester, repo);
      await tester.tap(find.byTooltip('Projects'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete project').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(c.read(projectProvider).id, isNot('alpha'));
      expect(c.read(projectProvider).name, 'Untitled project');
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('phone-width top bar fits (no overflow) and keeps everything in a menu', (tester) async {
    tester.view.physicalSize = const Size(412 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: fakeOverrides(), child: const TayangApp()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow at 412 px');
    expect(find.byTooltip('Projects'), findsNothing, reason: 'folded into the menu');

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('New project'), findsOneWidget);
    expect(find.text('Help & shortcuts'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Projects'), findsOneWidget, reason: 'dialog title');
    await tester.pump(const Duration(seconds: 3));
  });
}

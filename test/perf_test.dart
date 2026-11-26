import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' show debugOnRebuildDirtyWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/app.dart';
import 'package:tayang/application/di.dart';
import 'package:tayang/application/playback_controller.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';
import 'package:tayang/presentation/pages/editor_page.dart';
import 'package:tayang/presentation/widgets/timeline/clip_widget.dart';

import 'support/fakes.dart';

/// Frame-cost benchmarks on a stress project (400 clips / 5 tracks / ~400 s).
/// These measure build + layout + paint time of the UI in a headless debug
/// build, so absolute numbers are pessimistic; use them to compare before/after
/// and to catch big regressions.
const _tracks = 5;
const _clipsPerTrack = 80;

Project _stressProject() {
  const editor = TimelineEditor();
  const image = MediaAsset(
    id: 'img', path: '/nonexistent/img.png', name: 'img.png', kind: MediaKind.image,
  );
  var p = Project(
    id: 'p',
    name: 'stress',
    assets: const [image],
    tracks: [
      for (var i = 0; i < _tracks; i++)
        Track(id: 'v$i', kind: TrackKind.video, name: 'V$i'),
    ],
  );
  for (var t = 0; t < _tracks; t++) {
    for (var c = 0; c < _clipsPerTrack; c++) {
      p = editor.addClipFromAsset(p, image,
          clipId: 'c${t}_$c', newTrackId: 'x', trackId: 'v$t');
    }
  }
  return p;
}

Future<ProviderContainer> _pump(WidgetTester tester, {Project? project}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...fakeOverrides(),
      initialProjectProvider.overrideWithValue(project ?? _stressProject()),
    ],
    child: const TayangApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(EditorPage)));
}

/// The timeline clip (the preview also uses clip ids as keys).
Finder _clip(String id) =>
    find.byWidgetPredicate((w) => w is ClipWidget && w.clipId == id);

void main() {
  testWidgets('PERF playback ticks on a 400-clip project', (tester) async {
    final c = await _pump(tester);
    final playback = c.read(playbackProvider.notifier);

    // warm-up
    for (var i = 0; i < 10; i++) {
      playback.seek(Duration(seconds: 30, milliseconds: i * 33));
      await tester.pump();
    }

    const ticks = 150;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ticks; i++) {
      playback.seek(Duration(seconds: 40, milliseconds: i * 33)); // like a 30fps playback
      await tester.pump();
    }
    sw.stop();
    final avg = sw.elapsedMicroseconds / ticks / 1000;
    debugPrint('PERF playback_tick_ms=${avg.toStringAsFixed(2)} (clips=${_tracks * _clipsPerTrack})');
    expect(avg, lessThan(25), reason: 'average playback tick took ${avg.toStringAsFixed(1)} ms');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('PERF baseline: playback ticks on an EMPTY project', (tester) async {
    final c = await _pump(tester, project: Project.empty());
    final playback = c.read(playbackProvider.notifier);
    const ticks = 150;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ticks; i++) {
      playback.seek(Duration(milliseconds: i * 33));
      await tester.pump();
    }
    sw.stop();
    debugPrint('PERF baseline_tick_ms=${(sw.elapsedMicroseconds / ticks / 1000).toStringAsFixed(2)} (clips=0)');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('PERF diagnostic: which widgets rebuild per playback tick', (tester) async {
    final c = await _pump(tester);
    final playback = c.read(playbackProvider.notifier);
    playback.seek(const Duration(seconds: 40));
    await tester.pump();

    final counts = <String, int>{};
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      counts.update(element.widget.runtimeType.toString(), (n) => n + 1, ifAbsent: () => 1);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    const ticks = 10;
    for (var i = 1; i <= ticks; i++) {
      playback.seek(Duration(seconds: 40, milliseconds: i * 33));
      await tester.pump();
    }
    debugOnRebuildDirtyWidget = null;

    final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    debugPrint('PERF rebuilds_per_tick: ${[for (final e in top.take(12)) '${e.key}=${(e.value / ticks).toStringAsFixed(1)}'].join(', ')}');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('PERF dragging a clip on a 400-clip project', (tester) async {
    final c = await _pump(tester);
    expect(c, isNotNull);
    final rect = tester.getRect(_clip('c0_3'));

    const steps = 60;
    final gesture = await tester.startGesture(rect.center);
    final sw = Stopwatch();
    for (var i = 1; i <= steps; i++) {
      sw.start();
      await gesture.moveTo(rect.center + Offset(i * 3.0, 0));
      await tester.pump();
      sw.stop();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    final avg = sw.elapsedMicroseconds / steps / 1000;
    debugPrint('PERF drag_step_ms=${avg.toStringAsFixed(2)} (clips=${_tracks * _clipsPerTrack})');
    expect(avg, lessThan(40), reason: 'average drag frame took ${avg.toStringAsFixed(1)} ms');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('PERF selecting clips on a 400-clip project', (tester) async {
    await _pump(tester);
    const taps = 20;
    final sw = Stopwatch()..start();
    for (var i = 0; i < taps; i++) {
      await tester.tap(_clip('c0_${i % 3}'));
      await tester.pump();
    }
    sw.stop();
    final avg = sw.elapsedMicroseconds / taps / 1000;
    debugPrint('PERF select_ms=${avg.toStringAsFixed(2)}');
    expect(avg, lessThan(120));
    await tester.pump(const Duration(seconds: 3));
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...fakeOverrides(),
      initialProjectProvider.overrideWithValue(_stressProject()),
    ],
    child: const TayangApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(EditorPage)));
}

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
    expect(avg, lessThan(60), reason: 'average playback tick took ${avg.toStringAsFixed(1)} ms');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('PERF dragging a clip on a 400-clip project', (tester) async {
    final c = await _pump(tester);
    expect(c, isNotNull);
    final rect = tester.getRect(find.byKey(const ValueKey('c0_3')));

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
    expect(avg, lessThan(120), reason: 'average drag frame took ${avg.toStringAsFixed(1)} ms');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('PERF selecting clips on a 400-clip project', (tester) async {
    await _pump(tester);
    const taps = 20;
    final sw = Stopwatch()..start();
    for (var i = 0; i < taps; i++) {
      await tester.tap(find.byKey(ValueKey('c0_${i % 8}')));
      await tester.pump();
    }
    sw.stop();
    final avg = sw.elapsedMicroseconds / taps / 1000;
    debugPrint('PERF select_ms=${avg.toStringAsFixed(2)}');
    expect(avg, lessThan(120));
    await tester.pump(const Duration(seconds: 3));
  });
}

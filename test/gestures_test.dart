import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/app.dart';
import 'package:tayang/application/di.dart';
import 'package:tayang/application/playback_controller.dart';
import 'package:tayang/application/project_controller.dart';
import 'package:tayang/application/timeline_zoom_controller.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';
import 'package:tayang/presentation/pages/editor_page.dart';
import 'package:tayang/presentation/widgets/media/media_bin.dart';
import 'package:tayang/presentation/widgets/timeline/clip_widget.dart';
import 'package:tayang/presentation/widgets/timeline/timeline_ruler.dart';
import 'package:tayang/presentation/widgets/timeline/track_lane.dart';

import 'support/fakes.dart';

/// Pointer-level tests of the timeline: real drags through the real widgets.
/// Zoom is the default 80 px/second, so 80 px == 1 s.
const _pps = 80.0;
const _asset = MediaAsset(
  id: 'a', path: '/tmp/a.mp4', name: 'a.mp4',
  kind: MediaKind.video, duration: Duration(seconds: 10),
);

/// Tracks (top→bottom): text, v2, v1, audio. v1 holds c1 = 1–4s and c2 = 8–11s.
Project _fixture() {
  const editor = TimelineEditor();
  var p = const Project(
    id: 'p',
    name: 'g',
    assets: [_asset],
    tracks: [
      Track(id: 'txt', kind: TrackKind.text, name: 'T'),
      Track(id: 'v2', kind: TrackKind.video, name: 'V2'),
      Track(id: 'v1', kind: TrackKind.video, name: 'V1'),
      Track(id: 'aud', kind: TrackKind.audio, name: 'A'),
    ],
  );
  p = editor.addClipFromAsset(p, _asset,
      clipId: 'c1', newTrackId: 'x', at: const Duration(seconds: 1), trackId: 'v1');
  p = editor.trimClipEnd(p, 'c1', const Duration(seconds: 4));
  p = editor.addClipFromAsset(p, _asset,
      clipId: 'c2', newTrackId: 'x', at: const Duration(seconds: 8), trackId: 'v1');
  return editor.trimClipEnd(p, 'c2', const Duration(seconds: 11));
}

Future<ProviderContainer> _pump(WidgetTester tester, {Project? project}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...fakeOverrides(),
      initialProjectProvider.overrideWithValue(project ?? _fixture()),
    ],
    child: const TayangApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(EditorPage)));
}

/// Presses at [from], moves in small steps (like a real hand) and releases.
Future<void> _drag(WidgetTester tester, Offset from, Offset delta, {int steps = 20}) async {
  final gesture = await tester.startGesture(from);
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(from + delta * (i / steps));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Rect _clipRect(WidgetTester tester, String id) => tester.getRect(find.byKey(ValueKey(id)));

/// Lets the 2-second autosave debounce finish so no timer is left pending.
Future<void> _finish(WidgetTester tester) => tester.pump(const Duration(seconds: 3));

void main() {
  testWidgets('dragging a clip moves it, and the whole drag is ONE undo step', (tester) async {
    final c = await _pump(tester);
    final rect = _clipRect(tester, 'c1');

    await _drag(tester, rect.center, const Offset(2 * _pps, 0)); // +2s

    expect(c.read(projectProvider).clipById('c1')!.start,
        const Duration(seconds: 3));

    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pumpAndSettle();
    expect(c.read(projectProvider).clipById('c1')!.start, const Duration(seconds: 1),
        reason: 'a single undo must undo the entire drag');
    await _finish(tester);
  });

  testWidgets('a drag into another clip is rejected (no overlap)', (tester) async {
    final c = await _pump(tester);
    await _drag(tester, _clipRect(tester, 'c1').center, const Offset(7 * _pps, 0));

    final p = c.read(projectProvider);
    final c1 = p.clipById('c1')!;
    final c2 = p.clipById('c2')!;
    expect(c1.end <= c2.start, isTrue, reason: 'c1 ends at ${c1.end}, c2 starts ${c2.start}');
    expect(c1.start > const Duration(seconds: 3), isTrue, reason: 'it still moved');
    await _finish(tester);
  });

  testWidgets('dragging a clip near a neighbour snaps its edge to it', (tester) async {
    final c = await _pump(tester);
    // c1 is 3s long; end would land at 7.95s -> snaps to c2's start (8s) => start 5s.
    await _drag(tester, _clipRect(tester, 'c1').center, const Offset(3.95 * _pps, 0));
    expect(c.read(projectProvider).clipById('c1')!.start, const Duration(seconds: 5));
    await _finish(tester);
  });

  testWidgets('snapping can be switched off', (tester) async {
    final c = await _pump(tester);
    c.read(snapEnabledProvider.notifier).toggle();
    await _drag(tester, _clipRect(tester, 'c1').center, const Offset(3.95 * _pps, 0));
    final start = c.read(projectProvider).clipById('c1')!.start;
    expect((start - const Duration(milliseconds: 4950)).abs() < const Duration(milliseconds: 30),
        isTrue,
        reason: 'unsnapped start should be ~4.95s, was $start');
    await _finish(tester);
  });

  testWidgets('dragging the right edge trims the clip end', (tester) async {
    final c = await _pump(tester);
    final rect = _clipRect(tester, 'c1');
    await _drag(tester, Offset(rect.right - 4, rect.center.dy), const Offset(_pps, 0));

    final clip = c.read(projectProvider).clipById('c1')!;
    expect(clip.end, const Duration(seconds: 5));
    expect(clip.start, const Duration(seconds: 1));
    expect(clip.sourceStart, Duration.zero);
    await _finish(tester);
  });

  testWidgets('dragging the left edge trims the start and advances the in-point', (tester) async {
    final c = await _pump(tester);
    final rect = _clipRect(tester, 'c1');
    await _drag(tester, Offset(rect.left + 4, rect.center.dy), const Offset(0.5 * _pps, 0));

    final clip = c.read(projectProvider).clipById('c1')!;
    expect(clip.start, const Duration(milliseconds: 1500));
    expect(clip.sourceStart, const Duration(milliseconds: 500));
    expect(clip.end, const Duration(seconds: 4), reason: 'right edge stays put');
    await _finish(tester);
  });

  testWidgets('dragging straight up moves the clip to the track above', (tester) async {
    final c = await _pump(tester);
    await _drag(tester, _clipRect(tester, 'c1').center, const Offset(0, -60)); // one lane up

    final p = c.read(projectProvider);
    expect(p.trackOfClip('c1')!.id, 'v2');
    expect(p.clipById('c1')!.start, const Duration(seconds: 1), reason: 'time is unchanged');
    await _finish(tester);
  });

  testWidgets('a video clip cannot be dragged onto an audio track', (tester) async {
    final c = await _pump(tester);
    await _drag(tester, _clipRect(tester, 'c1').center, const Offset(0, 60)); // audio lane
    expect(c.read(projectProvider).trackOfClip('c1')!.id, 'v1');
    await _finish(tester);
  });

  testWidgets('clips on a locked track cannot be dragged', (tester) async {
    final c = await _pump(tester);
    c.read(projectControllerProvider.notifier).updateTrack('v1', (t) => t.copyWith(isLocked: true));
    await tester.pumpAndSettle();

    await _drag(tester, _clipRect(tester, 'c1').center, const Offset(2 * _pps, 0));
    expect(c.read(projectProvider).clipById('c1')!.start, const Duration(seconds: 1));
    await _finish(tester);
  });

  testWidgets('dragging media from the bin onto a lane drops it at that time', (tester) async {
    final c = await _pump(tester);
    final tile = tester.getCenter(find.descendant(
      of: find.byType(MediaBin),
      matching: find.text('a.mp4'),
    ));
    final lane = tester.getRect(find.byType(TrackLane).at(2)); // v1
    final target = Offset(lane.left + 13 * _pps, lane.center.dy);

    await _drag(tester, tile, target - tile, steps: 30);

    final p = c.read(projectProvider);
    final added = p.tracks
        .firstWhere((t) => t.id == 'v1')
        .clips
        .where((clip) => clip.id != 'c1' && clip.id != 'c2')
        .toList();
    expect(added.length, 1, reason: 'one new clip on v1');
    expect((added.single.start - const Duration(seconds: 13)).abs() <
        const Duration(milliseconds: 60), isTrue,
        reason: 'dropped at 13s, was ${added.single.start}');
    await _finish(tester);
  });

  testWidgets('dragging on the ruler scrubs the playhead', (tester) async {
    final c = await _pump(tester);
    final ruler = tester.getTopLeft(find.byType(TimelineRuler));
    await _drag(tester, ruler + const Offset(0, 14), const Offset(2 * _pps, 0));

    final position = c.read(playbackProvider).position;
    expect((position - const Duration(seconds: 2)).abs() < const Duration(milliseconds: 150),
        isTrue,
        reason: 'playhead at $position');
    await _finish(tester);
  });

  testWidgets('tapping a clip selects it and shows it in the inspector', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('c2')));
    await tester.pumpAndSettle();
    expect(find.text('INSPECTOR'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    await _finish(tester);
  });

  test('fixture sanity: clips are where the tests assume', () {
    final p = _fixture();
    expect(p.clipById('c1')!.start, const Duration(seconds: 1));
    expect(p.clipById('c1')!.end, const Duration(seconds: 4));
    expect(p.clipById('c2')!.start, const Duration(seconds: 8));
    expect(ClipWidget, isNotNull);
  });
}

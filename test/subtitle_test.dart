import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/app.dart';
import 'package:tayang/application/project_controller.dart';
import 'package:tayang/domain/models/clip.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/subtitle_parser.dart';
import 'package:tayang/domain/services/timeline_editor.dart';
import 'package:tayang/presentation/pages/editor_page.dart';

import 'support/fakes.dart';

void main() {
  group('SubtitleParser', () {
    test('parses SRT with multi-line text and comma milliseconds', () {
      final cues = SubtitleParser.parse('''
1
00:00:01,000 --> 00:00:03,500
Hello there
second line

2
00:01:05,250 --> 00:01:07,000
Bye
''');
      expect(cues.length, 2);
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].end, const Duration(seconds: 3, milliseconds: 500));
      expect(cues[0].text, 'Hello there\nsecond line');
      expect(cues[1].start, const Duration(minutes: 1, seconds: 5, milliseconds: 250));
    });

    test('handles CRLF line endings and a BOM', () {
      final cues = SubtitleParser.parse(
          '\uFEFF1\r\n00:00:00,500 --> 00:00:01,500\r\nWindows file\r\n\r\n');
      expect(cues.single.text, 'Windows file');
      expect(cues.single.start, const Duration(milliseconds: 500));
    });

    test('parses WebVTT: header, cue ids, settings, short timestamps, notes', () {
      final cues = SubtitleParser.parse('''
WEBVTT

NOTE this is a comment

intro
00:01.000 --> 00:02.500 align:start position:10%
First

00:00:03.000 --> 00:00:04.000
Second
''');
      expect(cues.map((c) => c.text), ['First', 'Second']);
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].end, const Duration(seconds: 2, milliseconds: 500));
    });

    test('strips markup tags and ASS overrides', () {
      final cues = SubtitleParser.parse(
          '1\n00:00:01,000 --> 00:00:02,000\n<i>Italic</i> and <b>bold</b> {\\an8}top\n');
      expect(cues.single.text, 'Italic and bold top');
    });

    test('skips malformed blocks and keeps the good ones, sorted by time', () {
      final cues = SubtitleParser.parse('''
2
00:00:05,000 --> 00:00:06,000
Later

garbage without a time line

3
00:00:09,000 --> 00:00:08,000
Ends before it starts

1
00:00:01,000 --> 00:00:02,000
Earlier
''');
      expect(cues.map((c) => c.text), ['Earlier', 'Later']);
    });

    test('short fractions are padded (",5" means 500 ms)', () {
      final cues = SubtitleParser.parse('1\n00:00:01,5 --> 00:00:02,25\nx\n');
      expect(cues.single.start, const Duration(milliseconds: 1500));
      expect(cues.single.end, const Duration(seconds: 2, milliseconds: 250));
    });

    test('empty or cue-less input gives no cues', () {
      expect(SubtitleParser.parse(''), isEmpty);
      expect(SubtitleParser.parse('WEBVTT\n\n'), isEmpty);
    });
  });

  group('TimelineEditor.addSubtitles', () {
    const editor = TimelineEditor();
    var n = 0;
    String id() => 's${n++}';
    const base = Project(
      id: 'p', name: 'p',
      tracks: [Track(id: 'v', kind: TrackKind.video, name: 'V')],
    );

    test('creates a text track on top with one clip per cue', () {
      final p = editor.addSubtitles(
        base,
        const [
          SubtitleCue(Duration(seconds: 1), Duration(seconds: 3), 'One'),
          SubtitleCue(Duration(seconds: 4), Duration(seconds: 6), 'Two'),
        ],
        trackId: 'sub',
        clipIdFactory: id,
      );
      expect(p.tracks.first.id, 'sub');
      expect(p.tracks.first.kind, TrackKind.text);
      final clips = p.tracks.first.clips;
      expect(clips.map((c) => c.text!.content), ['One', 'Two']);
      expect(clips[0].start, const Duration(seconds: 1));
      expect(clips[0].duration, const Duration(seconds: 2));
      expect(clips.every((c) => c.kind == ClipKind.text), isTrue);
    });

    test('overlapping cues are shortened so the track stays valid', () {
      final p = editor.addSubtitles(
        base,
        const [
          SubtitleCue(Duration(seconds: 1), Duration(seconds: 5), 'A'),
          SubtitleCue(Duration(seconds: 3), Duration(seconds: 6), 'B'),
        ],
        trackId: 'sub',
        clipIdFactory: id,
      );
      final clips = p.tracks.first.clips;
      expect(clips[0].end, const Duration(seconds: 3), reason: 'A is cut where B starts');
      expect(clips[1].start, const Duration(seconds: 3));
    });

    test('an offset shifts every cue; negative starts clamp to zero', () {
      final p = editor.addSubtitles(
        base,
        const [SubtitleCue(Duration(seconds: 1), Duration(seconds: 3), 'A')],
        trackId: 'sub',
        clipIdFactory: id,
        offset: const Duration(seconds: -2),
      );
      expect(p.tracks.first.clips.single.start, Duration.zero);
    });

    test('no usable cues leaves the project untouched', () {
      final p = editor.addSubtitles(base, const [], trackId: 'sub', clipIdFactory: id);
      expect(identical(p, base), isTrue);
    });
  });

  testWidgets('importing a subtitle file adds a track and tells the user', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: fakeOverrides(
        subtitles: FakeSubtitleSource(const [
          SubtitleCue(Duration(seconds: 1), Duration(seconds: 2), 'Hi'),
          SubtitleCue(Duration(seconds: 3), Duration(seconds: 4), 'There'),
        ]),
      ),
      child: const TayangApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(EditorPage)));
    final tracksBefore = c.read(projectProvider).tracks.length;

    await tester.tap(find.byTooltip('Import subtitles (.srt / .vtt)'));
    await tester.pumpAndSettle();

    final project = c.read(projectProvider);
    expect(project.tracks.length, tracksBefore + 1);
    expect(project.tracks.first.name, 'Subtitles');
    expect(project.tracks.first.clips.length, 2);
    expect(find.text('Added 2 subtitles on a new track'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('an empty subtitle file reports an error instead of adding a track', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: fakeOverrides(subtitles: FakeSubtitleSource(const [])),
      child: const TayangApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(EditorPage)));
    final before = c.read(projectProvider).tracks.length;

    await tester.tap(find.byTooltip('Import subtitles (.srt / .vtt)'));
    await tester.pumpAndSettle();

    expect(c.read(projectProvider).tracks.length, before);
    expect(find.textContaining('No subtitles were found'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

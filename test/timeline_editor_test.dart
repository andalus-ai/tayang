import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/data/export/ffmpeg_command_builder.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/clip.dart';
import 'package:tayang/domain/models/history.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

void main() {
  const editor = TimelineEditor();
  const asset = MediaAsset(
    id: 'a',
    path: '/tmp/a.mp4',
    name: 'a.mp4',
    kind: MediaKind.video,
    duration: Duration(seconds: 10),
  );
  const empty = Project(
    id: 'p',
    name: 'p',
    assets: [asset],
    tracks: [Track(id: 'v', kind: TrackKind.video, name: 'V')],
  );

  Project withClip() =>
      editor.addClipFromAsset(empty, asset, clipId: 'c1', newTrackId: 't');

  test('adds clip at end of first accepting track', () {
    final p = editor.addClipFromAsset(withClip(), asset, clipId: 'c2', newTrackId: 't');
    expect(p.clipById('c2')!.start, const Duration(seconds: 10));
  });

  test('split yields contiguous clips with correct source offsets', () {
    final p = editor.splitClip(withClip(), 'c1', const Duration(seconds: 4), rightClipId: 'c2');
    expect(p.clipById('c1')!.duration, const Duration(seconds: 4));
    expect(p.clipById('c2')!.start, const Duration(seconds: 4));
    expect(p.clipById('c2')!.sourceStart, const Duration(seconds: 4));
  });

  test('move is rejected on overlap', () {
    var p = editor.splitClip(withClip(), 'c1', const Duration(seconds: 4), rightClipId: 'c2');
    final moved = editor.moveClip(p, 'c2', const Duration(seconds: 2));
    expect(identical(moved, p), isTrue);
  });

  test('trim end is capped by source duration', () {
    final p = editor.trimClipEnd(withClip(), 'c1', const Duration(seconds: 60));
    expect(p.clipById('c1')!.duration, const Duration(seconds: 10));
  });

  test('ripple delete shifts later clips left', () {
    var p = editor.splitClip(withClip(), 'c1', const Duration(seconds: 4), rightClipId: 'c2');
    p = editor.deleteClip(p, 'c1', ripple: true);
    expect(p.clipById('c2')!.start, Duration.zero);
  });

  test('history undo / redo', () {
    final h = const History<int>(present: 0).push(1).push(2);
    expect(h.undo().present, 1);
    expect(h.undo().redo().present, 2);
  });

  fadeTests();

  test('ffmpeg command maps video and audio', () {
    final args = const FfmpegCommandBuilder()
        .build(withClip(), const ExportSettings(), outputPath: '/tmp/out.mp4');
    expect(args, contains('-filter_complex'));
    expect(args, contains('[aout]'));
    expect(args.last, '/tmp/out.mp4');
  });
}

void fadeTests() {
  const editor = TimelineEditor();
  const asset = MediaAsset(
    id: 'a', path: '/tmp/a.mp4', name: 'a.mp4',
    kind: MediaKind.video, duration: Duration(seconds: 10),
  );
  const base = Project(
    id: 'p', name: 'p', assets: [asset],
    tracks: [Track(id: 'v', kind: TrackKind.video, name: 'V')],
  );

  group('fades', () {
    test('factor ramps in and out', () {
      final p = editor.addClipFromAsset(base, asset, clipId: 'c', newTrackId: 't');
      final c = p.clipById('c')!.copyWith(
        fadeIn: const Duration(seconds: 2),
        fadeOut: const Duration(seconds: 2),
      );
      expect(c.fadeFactorAt(const Duration(seconds: 1)), closeTo(0.5, 1e-6));
      expect(c.fadeFactorAt(const Duration(seconds: 5)), 1.0);
      expect(c.fadeFactorAt(const Duration(seconds: 9)), closeTo(0.5, 1e-6));
    });

    test('export graph contains fade and afade filters', () {
      var p = editor.addClipFromAsset(base, asset, clipId: 'c', newTrackId: 't');
      p = editor.updateClip(p, 'c', (c) => c.copyWith(fadeIn: const Duration(seconds: 1)));
      final graph = const FfmpegCommandBuilder()
          .build(p, const ExportSettings(), outputPath: 'o.mp4')
          .join(' ');
      expect(graph, contains('fade=t=in'));
      expect(graph, contains('afade=t=in'));
    });
  });
}

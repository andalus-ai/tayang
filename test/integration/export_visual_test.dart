import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/data/export/process_video_exporter.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/keyframes.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

/// Visual regression tests: export solid-colour clips through the real FFmpeg
/// pipeline and assert on actual pixel values, so effects that silently render
/// wrong (but still produce a valid file) are caught. Output is 320x180.
bool _hasFfmpeg() {
  try {
    return Process.runSync('ffmpeg', ['-version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}

const _w = 320;
const _h = 180;

void main() {
  final available = _hasFfmpeg();
  const editor = TimelineEditor();
  late Directory dir;
  late String redPath;
  late String bluePath;
  late String blackPath;

  Future<String> solid(String color) async {
    final path = '${dir.path}/$color.mp4';
    final r = await Process.run('ffmpeg', [
      '-loglevel', 'error', '-y',
      '-f', 'lavfi', '-i', 'color=c=$color:s=${_w}x$_h:r=15:d=8',
      '-c:v', 'libx264', '-crf', '14', '-pix_fmt', 'yuv420p',
      path,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return path;
  }

  setUpAll(() async {
    if (!available) return;
    dir = await Directory.systemTemp.createTemp('tayang_visual_');
    redPath = await solid('red');
    bluePath = await solid('blue');
    blackPath = await solid('black');
  });

  tearDownAll(() async {
    if (available) await dir.delete(recursive: true);
  });

  MediaAsset asset(String id, String path, int seconds) => MediaAsset(
        id: id, path: path, name: id, kind: MediaKind.video,
        duration: Duration(seconds: seconds), hasAudio: false,
      );

  Project base(List<Track> tracks, List<MediaAsset> assets) =>
      Project(id: 'p', name: 'v', tracks: tracks, assets: assets);

  Future<String> render(Project p, String name) async {
    final exporter = ProcessVideoExporter(
      fontProvider: () async => File('assets/fonts/DejaVuSans.ttf').absolute.path,
    );
    final out = '${dir.path}/$name.mp4';
    final events = await exporter
        .export(
          p,
          const ExportSettings(height: _h, fps: 15, quality: ExportQuality.draft),
          outputPath: out,
        )
        .toList();
    final last = events.last;
    expect(last, isA<ExportDone>(), reason: last is ExportFailed ? last.message : null);
    return out;
  }

  /// RGB of one pixel of the frame at [seconds].
  Future<List<int>> pixel(String video, double seconds, int x, int y) async {
    final r = await Process.run(
      'ffmpeg',
      [
        '-loglevel', 'error',
        '-ss', '$seconds', '-i', video,
        '-frames:v', '1',
        '-vf', 'crop=1:1:$x:$y,format=rgb24',
        '-f', 'rawvideo', '-',
      ],
      stdoutEncoding: null,
    );
    final bytes = r.stdout as List<int>;
    expect(bytes.length, 3, reason: 'no frame at ${seconds}s');
    return bytes;
  }

  /// Brightest luma value inside a rectangle of the frame at [seconds].
  Future<int> maxLuma(String video, double seconds, int x, int y, int w, int h) async {
    final r = await Process.run(
      'ffmpeg',
      [
        '-loglevel', 'error',
        '-ss', '$seconds', '-i', video,
        '-frames:v', '1',
        '-vf', 'crop=$w:$h:$x:$y,format=gray',
        '-f', 'rawvideo', '-',
      ],
      stdoutEncoding: null,
    );
    return (r.stdout as List<int>).reduce(math.max);
  }

  Project oneClip(String assetId, String path, int seconds,
      {Duration at = Duration.zero, String track = 'v1'}) {
    final a = asset(assetId, path, seconds);
    final p = base([const Track(id: 'v1', kind: TrackKind.video, name: 'V')], [a]);
    return editor.addClipFromAsset(p, a,
        clipId: 'c', newTrackId: 'x', at: at, trackId: track);
  }

  const skipReason = 'ffmpeg not installed';
  Object skip() => available ? false : skipReason;
  const timeout = Timeout(Duration(minutes: 3));

  test('keyframed opacity ramps the picture up from black', () async {
    var p = oneClip('r', redPath, 4);
    p = editor.setKeyframe(p, 'c', KeyframeProperty.opacity, Duration.zero, 0.0);
    p = editor.setKeyframe(p, 'c', KeyframeProperty.opacity, const Duration(seconds: 4), 1.0);
    final out = await render(p, 'opacity');

    for (final t in [1.0, 2.0, 3.0]) {
      final px = await pixel(out, t, _w ~/ 2, _h ~/ 2);
      expect(px[0], closeTo(255 * t / 4, 35), reason: 'red at ${t}s = ${px[0]}');
      expect(px[2], lessThan(40), reason: 'blue should stay ~0 at ${t}s');
    }
  }, skip: skip(), timeout: timeout);

  test('static opacity blends the clip with the black canvas', () async {
    var p = oneClip('r', redPath, 3);
    p = editor.updateClip(p, 'c', (c) => c.copyWith(opacity: 0.5));
    final out = await render(p, 'static_opacity');
    final px = await pixel(out, 1.0, _w ~/ 2, _h ~/ 2);
    expect(px[0], closeTo(128, 30));
  }, skip: skip(), timeout: timeout);

  test('crossfade goes red → mix → blue', () async {
    final r = asset('r', redPath, 4);
    final b = asset('b', bluePath, 4);
    var p = base([const Track(id: 'v1', kind: TrackKind.video, name: 'V')], [r, b]);
    p = editor.addClipFromAsset(p, r, clipId: 'a', newTrackId: 'x'); // 0–4s
    p = editor.addClipFromAsset(p, b, clipId: 'b', newTrackId: 'x'); // 4–8s
    p = editor.addCrossfade(p, 'a', const Duration(seconds: 2)); // b now 2–6s
    expect(p.clipById('b')!.start, const Duration(seconds: 2));
    final out = await render(p, 'crossfade');

    final before = await pixel(out, 1.0, 160, 90);
    expect(before[0], greaterThan(220), reason: 'pure red before the overlap');
    expect(before[2], lessThan(40));

    final mid = await pixel(out, 3.0, 160, 90); // halfway through the 2s fade
    expect(mid[0], closeTo(128, 40), reason: 'red fading out: ${mid[0]}');
    expect(mid[2], closeTo(128, 40), reason: 'blue fading in: ${mid[2]}');

    final after = await pixel(out, 5.0, 160, 90);
    expect(after[2], greaterThan(220), reason: 'pure blue after the overlap');
    expect(after[0], lessThan(40));
  }, skip: skip(), timeout: timeout);

  test('scale shrinks the picture around the centre', () async {
    var p = oneClip('r', redPath, 3);
    p = editor.updateClip(p, 'c', (c) => c.copyWith(scale: 0.5));
    final out = await render(p, 'scale');

    final center = await pixel(out, 1.0, 160, 90);
    final corner = await pixel(out, 1.0, 10, 10);
    expect(center[0], greaterThan(220), reason: 'centre still red');
    expect(corner[0], lessThan(30), reason: 'corner is now black canvas');
  }, skip: skip(), timeout: timeout);

  test('position offset moves the picture right', () async {
    var p = oneClip('r', redPath, 3);
    p = editor.updateClip(p, 'c', (c) => c.copyWith(scale: 0.5, offsetX: 0.25));
    final out = await render(p, 'offset');

    final moved = await pixel(out, 1.0, 240, 90); // inside the shifted region
    final vacated = await pixel(out, 1.0, 100, 90); // red used to be here
    expect(moved[0], greaterThan(220));
    expect(vacated[0], lessThan(30));
  }, skip: skip(), timeout: timeout);

  test('picture-in-picture draws the top track over the lower one', () async {
    final r = asset('r', redPath, 3);
    final b = asset('b', bluePath, 3);
    var p = base([
      const Track(id: 'top', kind: TrackKind.video, name: 'Top'),
      const Track(id: 'bottom', kind: TrackKind.video, name: 'Bottom'),
    ], [r, b]);
    p = editor.addClipFromAsset(p, r,
        clipId: 'bg', newTrackId: 'x', at: Duration.zero, trackId: 'bottom');
    p = editor.addClipFromAsset(p, b,
        clipId: 'pip', newTrackId: 'x', at: Duration.zero, trackId: 'top');
    p = editor.updateClip(p, 'pip', (c) => c.copyWith(scale: 0.4));
    final out = await render(p, 'pip');

    final center = await pixel(out, 1.0, 160, 90);
    final corner = await pixel(out, 1.0, 10, 10);
    expect(center[2], greaterThan(220), reason: 'small blue picture in the middle');
    expect(corner[0], greaterThan(220), reason: 'red background around it');
  }, skip: skip(), timeout: timeout);

  test('text appears only inside its time window', () async {
    final k = asset('k', blackPath, 5);
    var p = base([
      const Track(id: 'txt', kind: TrackKind.text, name: 'T'),
      const Track(id: 'v1', kind: TrackKind.video, name: 'V'),
    ], [k]);
    p = editor.addClipFromAsset(p, k,
        clipId: 'bg', newTrackId: 'x', at: Duration.zero, trackId: 'v1');
    p = editor.addTextClip(p,
        clipId: 't', newTrackId: 'x', at: const Duration(seconds: 2));
    p = editor.trimClipEnd(p, 't', const Duration(seconds: 4)); // visible 2–4s
    p = editor.updateClip(
      p,
      't',
      (c) => c.copyWith(text: c.text!.copyWith(content: 'HELLO', fontSize: 240, y: 0.5)),
    );
    final out = await render(p, 'text');

    final before = await maxLuma(out, 1.0, 100, 70, 120, 40);
    final during = await maxLuma(out, 3.0, 100, 70, 120, 40);
    expect(before, lessThan(25), reason: 'no text before 2s');
    expect(during, greaterThan(150), reason: 'white text visible at 3s');
  }, skip: skip(), timeout: timeout);

  test('fade in starts from black', () async {
    var p = oneClip('r', redPath, 4);
    p = editor.updateClip(p, 'c', (c) => c.copyWith(fadeIn: const Duration(seconds: 2)));
    final out = await render(p, 'fadein');

    final start = await pixel(out, 0.1, 160, 90);
    final end = await pixel(out, 3.0, 160, 90);
    expect(start[0], lessThan(40), reason: 'fade begins black');
    expect(end[0], greaterThan(220), reason: 'fade complete');
  }, skip: skip(), timeout: timeout);
}

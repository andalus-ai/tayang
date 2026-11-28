import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/data/export/process_video_exporter.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

/// Real FFmpeg, real pixels: colour adjustments, rotation, mirroring and
/// multi-line text (subtitles). Output is 320x180. Skipped without ffmpeg.
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
  late String halvesPath; // left half red, right half blue
  late String blackPath;

  Future<String> make(String name, List<String> inputsAndFilter) async {
    final path = '${dir.path}/$name.mp4';
    final r = await Process.run('ffmpeg', [
      '-loglevel', 'error', '-y',
      ...inputsAndFilter,
      '-c:v', 'libx264', '-crf', '14', '-pix_fmt', 'yuv420p', '-t', '6', path,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return path;
  }

  setUpAll(() async {
    if (!available) return;
    dir = await Directory.systemTemp.createTemp('tayang_fx_');
    redPath = await make('red', ['-f', 'lavfi', '-i', 'color=c=red:s=${_w}x$_h:r=15:d=6']);
    blackPath = await make('black', ['-f', 'lavfi', '-i', 'color=c=black:s=${_w}x$_h:r=15:d=6']);
    halvesPath = await make('halves', [
      '-f', 'lavfi', '-i', 'color=c=red:s=${_w ~/ 2}x$_h:r=15:d=6',
      '-f', 'lavfi', '-i', 'color=c=blue:s=${_w ~/ 2}x$_h:r=15:d=6',
      '-filter_complex', 'hstack',
    ]);
  });

  tearDownAll(() async {
    if (available) await dir.delete(recursive: true);
  });

  Project clipProject(String path, {String id = 'c'}) {
    final a = MediaAsset(
      id: 'a', path: path, name: 'a', kind: MediaKind.video,
      duration: const Duration(seconds: 3), hasAudio: false,
    );
    final p = Project(
      id: 'p', name: 'fx', assets: [a],
      tracks: const [
        Track(id: 'txt', kind: TrackKind.text, name: 'T'),
        Track(id: 'v1', kind: TrackKind.video, name: 'V'),
      ],
    );
    return editor.addClipFromAsset(p, a, clipId: id, newTrackId: 'x', trackId: 'v1');
  }

  Future<String> render(Project p, String name) async {
    final exporter = ProcessVideoExporter(
      fontProvider: () async => File('assets/fonts/DejaVuSans.ttf').absolute.path,
    );
    final out = '${dir.path}/$name.mp4';
    final events = await exporter
        .export(p, const ExportSettings(height: _h, fps: 15, quality: ExportQuality.draft),
            outputPath: out)
        .toList();
    final last = events.last;
    expect(last, isA<ExportDone>(), reason: last is ExportFailed ? last.message : null);
    return out;
  }

  Future<List<int>> pixel(String video, int x, int y, {double at = 1.0}) async {
    final r = await Process.run(
      'ffmpeg',
      ['-loglevel', 'error', '-ss', '$at', '-i', video, '-frames:v', '1',
       '-vf', 'crop=1:1:$x:$y,format=rgb24', '-f', 'rawvideo', '-'],
      stdoutEncoding: null,
    );
    final bytes = r.stdout as List<int>;
    expect(bytes.length, 3);
    return bytes;
  }

  /// First and last frame row that contains something bright.
  Future<(int, int)?> litRows(String video, {double at = 1.0}) async {
    final r = await Process.run(
      'ffmpeg',
      ['-loglevel', 'error', '-ss', '$at', '-i', video, '-frames:v', '1',
       '-vf', 'format=gray', '-f', 'rawvideo', '-'],
      stdoutEncoding: null,
    );
    final bytes = r.stdout as List<int>;
    final lit = [
      for (var y = 0; y < _h; y++)
        if (bytes.sublist(y * _w, (y + 1) * _w).reduce(math.max) > 128) y,
    ];
    return lit.isEmpty ? null : (lit.first, lit.last);
  }

  final skip = available ? false : 'ffmpeg not installed';
  const timeout = Timeout(Duration(minutes: 3));

  test('saturation 0 turns red into grey', () async {
    final p = editor.updateClip(clipProject(redPath), 'c', (c) => c.copyWith(saturation: 0.0));
    final px = await pixel(await render(p, 'sat0'), 160, 90);
    final spread = px.reduce(math.max) - px.reduce(math.min);
    expect(spread, lessThan(30), reason: 'R,G,B should be near-equal grey, got $px');
    expect(px[0], greaterThan(40), reason: 'still has the red\'s luma');
  }, skip: skip, timeout: timeout);

  test('brightness lifts the dark channels of red', () async {
    final base = await pixel(await render(clipProject(redPath), 'plain_red'), 160, 90);
    final p = editor.updateClip(clipProject(redPath), 'c', (c) => c.copyWith(brightness: 0.5));
    final bright = await pixel(await render(p, 'bright'), 160, 90);
    expect(bright[1], greaterThan(base[1] + 50), reason: 'green rises: $base -> $bright');
    expect(bright[2], greaterThan(base[2] + 50), reason: 'blue rises: $base -> $bright');
  }, skip: skip, timeout: timeout);

  test('rotating a left-red/right-blue picture 90° clockwise puts red on top', () async {
    final p = editor.updateClip(clipProject(halvesPath), 'c', (c) => c.copyWith(rotation: 1));
    final out = await render(p, 'rot90');
    final top = await pixel(out, 160, 45);
    final bottom = await pixel(out, 160, 135);
    expect(top[0], greaterThan(200), reason: 'top is red: $top');
    expect(bottom[2], greaterThan(200), reason: 'bottom is blue: $bottom');
  }, skip: skip, timeout: timeout);

  test('rotating 270° puts blue on top', () async {
    final p = editor.updateClip(clipProject(halvesPath), 'c', (c) => c.copyWith(rotation: 3));
    final out = await render(p, 'rot270');
    expect((await pixel(out, 160, 45))[2], greaterThan(200));
    expect((await pixel(out, 160, 135))[0], greaterThan(200));
  }, skip: skip, timeout: timeout);

  test('rotating 180° swaps left and right', () async {
    final p = editor.updateClip(clipProject(halvesPath), 'c', (c) => c.copyWith(rotation: 2));
    final out = await render(p, 'rot180');
    expect((await pixel(out, 80, 90))[2], greaterThan(200), reason: 'left is blue now');
    expect((await pixel(out, 240, 90))[0], greaterThan(200), reason: 'right is red now');
  }, skip: skip, timeout: timeout);

  test('flipH mirrors left and right; flipV after a rotation mirrors top and bottom', () async {
    var p = editor.updateClip(clipProject(halvesPath), 'c', (c) => c.copyWith(flipH: true));
    var out = await render(p, 'flipH');
    expect((await pixel(out, 80, 90))[2], greaterThan(200), reason: 'left is blue');
    expect((await pixel(out, 240, 90))[0], greaterThan(200), reason: 'right is red');

    p = editor.updateClip(clipProject(halvesPath), 'c',
        (c) => c.copyWith(rotation: 1, flipV: true));
    out = await render(p, 'rot_flipV');
    expect((await pixel(out, 160, 45))[2], greaterThan(200), reason: 'rotated (red on top) then flipped');
    expect((await pixel(out, 160, 135))[0], greaterThan(200));
  }, skip: skip, timeout: timeout);

  test('multi-line subtitle text renders on two lines', () async {
    Future<int> heightOf(String content, String name) async {
      var p = clipProject(blackPath);
      p = editor.addTextClip(p, clipId: 't', newTrackId: 'x', at: Duration.zero);
      p = editor.updateClip(p, 't', (c) => c.copyWith(
          text: c.text!.copyWith(content: content, fontSize: 150, y: 0.5)));
      final rows = await litRows(await render(p, name));
      expect(rows, isNotNull, reason: 'text drawn for "$content"');
      return rows!.$2 - rows.$1;
    }

    final one = await heightOf('AAA', 'text1');
    final two = await heightOf('AAA\nBBB', 'text2');
    expect(two, greaterThan(one * 1.6), reason: 'two lines ($two px) vs one ($one px)');
  }, skip: skip, timeout: timeout);
}

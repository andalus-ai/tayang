import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/data/export/process_video_exporter.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/keyframes.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

/// Export benchmarks with the real FFmpeg binary. Prints "PERF export ..." lines
/// with the real-time factor (seconds of work per second of output video; below
/// 1.0 is faster than real time). Skipped automatically without ffmpeg.
bool _hasFfmpeg() {
  try {
    return Process.runSync('ffmpeg', ['-version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}

void main() {
  final available = _hasFfmpeg();
  const editor = TimelineEditor();
  late Directory dir;
  late String hdPath;
  late String uhdPath;

  Future<String> source(String name, String size, int seconds) async {
    final path = '${dir.path}/$name.mp4';
    final r = await Process.run('ffmpeg', [
      '-loglevel', 'error', '-y',
      '-f', 'lavfi', '-i', 'testsrc2=size=$size:rate=30:duration=$seconds',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=$seconds',
      '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '20', '-pix_fmt', 'yuv420p',
      '-c:a', 'aac', path,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return path;
  }

  setUpAll(() async {
    if (!available) return;
    dir = await Directory.systemTemp.createTemp('tayang_perf_');
    hdPath = await source('hd', '1920x1080', 6);
    uhdPath = await source('uhd', '3840x2160', 4);
    debugPrint('PERF export env cpus=${Platform.numberOfProcessors}');
  });

  tearDownAll(() async {
    if (available) await dir.delete(recursive: true);
  });

  MediaAsset asset(String id, String path, int seconds) => MediaAsset(
        id: id, path: path, name: id, kind: MediaKind.video,
        duration: Duration(seconds: seconds), hasAudio: true,
      );

  Project empty(List<MediaAsset> assets, {int videoTracks = 1}) => Project(
        id: 'p',
        name: 'perf',
        assets: assets,
        tracks: [
          const Track(id: 'txt', kind: TrackKind.text, name: 'T'),
          for (var i = videoTracks - 1; i >= 0; i--)
            Track(id: 'v$i', kind: TrackKind.video, name: 'V$i'),
        ],
      );

  Future<void> bench(
    String name,
    Project p, {
    int height = 1080,
    ExportQuality quality = ExportQuality.standard,
    // Regression guard (CI runners vary ~1.6x run to run; typical 1080p is 0.3-0.8x).
    double maxRealtimeFactor = 2.0,
  }) async {
    final exporter = ProcessVideoExporter(
      fontProvider: () async => File('assets/fonts/DejaVuSans.ttf').absolute.path,
    );
    final out = '${dir.path}/${name.replaceAll(' ', '_')}.mp4';
    final sw = Stopwatch()..start();
    final events = await exporter
        .export(p, ExportSettings(height: height, fps: 30, quality: quality), outputPath: out)
        .toList();
    sw.stop();
    final last = events.last;
    expect(last, isA<ExportDone>(), reason: last is ExportFailed ? last.message : null);

    final outSeconds = p.duration.inMicroseconds / 1e6;
    final took = sw.elapsedMicroseconds / 1e6;
    final factor = took / outSeconds;
    debugPrint('PERF export scenario="$name" ${height}p out=${outSeconds.toStringAsFixed(1)}s '
        'took=${took.toStringAsFixed(1)}s realtime_factor=${factor.toStringAsFixed(2)}x');
    expect(factor, lessThan(maxRealtimeFactor),
        reason: '$name took ${took.toStringAsFixed(1)}s for ${outSeconds.toStringAsFixed(1)}s of video');
  }

  Project plain() {
    final a = asset('a', hdPath, 6);
    return editor.addClipFromAsset(empty([a]), a, clipId: 'c', newTrackId: 'x', trackId: 'v0');
  }

  final skip = available ? false : 'ffmpeg not installed';
  const timeout = Timeout(Duration(minutes: 10));

  test('1080p plain clip', () => bench('plain', plain()), skip: skip, timeout: timeout);

  test('1080p plain clip, draft quality', () =>
      bench('plain draft', plain(), quality: ExportQuality.draft), skip: skip, timeout: timeout);

  test('1080p fades + scale/offset', () {
    final p = editor.updateClip(plain(), 'c', (c) => c.copyWith(
          fadeIn: const Duration(seconds: 1),
          fadeOut: const Duration(seconds: 1),
          scale: 1.2,
          offsetX: 0.05,
        ));
    return bench('fades+transform', p);
  }, skip: skip, timeout: timeout);

  test('1080p keyframed opacity', () {
    var p = editor.setKeyframe(plain(), 'c', KeyframeProperty.opacity, Duration.zero, 0.0);
    p = editor.setKeyframe(p, 'c', KeyframeProperty.opacity, const Duration(seconds: 6), 1.0);
    return bench('keyframed opacity', p);
  }, skip: skip, timeout: timeout);

  test('1080p crossfade between two clips', () {
    final a = asset('a', hdPath, 4);
    final b = asset('b', hdPath, 4);
    var p = empty([a, b]);
    p = editor.addClipFromAsset(p, a, clipId: 'c1', newTrackId: 'x', trackId: 'v0');
    p = editor.addClipFromAsset(p, b, clipId: 'c2', newTrackId: 'x', trackId: 'v0');
    p = editor.addCrossfade(p, 'c1', const Duration(seconds: 1));
    return bench('crossfade', p);
  }, skip: skip, timeout: timeout);

  test('1080p text overlay', () {
    var p = editor.addTextClip(plain(), clipId: 't', newTrackId: 'x', at: const Duration(seconds: 1));
    p = editor.updateClip(p, 't', (c) => c.copyWith(text: c.text!.copyWith(content: 'Hello', fontSize: 120)));
    return bench('text', p);
  }, skip: skip, timeout: timeout);

  test('1080p speed 2x', () {
    final p = editor.setSpeed(plain(), 'c', 2.0);
    return bench('speed 2x', p);
  }, skip: skip, timeout: timeout);

  test('1080p picture-in-picture (2 layers)', () {
    final a = asset('a', hdPath, 6);
    final b = asset('b', hdPath, 6);
    var p = empty([a, b], videoTracks: 2);
    p = editor.addClipFromAsset(p, a, clipId: 'bg', newTrackId: 'x', trackId: 'v0', at: Duration.zero);
    p = editor.addClipFromAsset(p, b, clipId: 'pip', newTrackId: 'x', trackId: 'v1', at: Duration.zero);
    p = editor.updateClip(p, 'pip', (c) => c.copyWith(scale: 0.4, offsetX: 0.3, offsetY: -0.3));
    return bench('pip', p);
  }, skip: skip, timeout: timeout);

  test('1080p everything combined', () {
    final a = asset('a', hdPath, 4);
    final b = asset('b', hdPath, 4);
    final c = asset('c', hdPath, 6);
    var p = empty([a, b, c], videoTracks: 2);
    p = editor.addClipFromAsset(p, a, clipId: 'c1', newTrackId: 'x', trackId: 'v0');
    p = editor.addClipFromAsset(p, b, clipId: 'c2', newTrackId: 'x', trackId: 'v0');
    p = editor.addCrossfade(p, 'c1', const Duration(seconds: 1));
    p = editor.addClipFromAsset(p, c, clipId: 'pip', newTrackId: 'x', trackId: 'v1', at: Duration.zero);
    p = editor.updateClip(p, 'pip', (k) => k.copyWith(scale: 0.4, offsetX: 0.3, offsetY: -0.3));
    p = editor.setKeyframe(p, 'pip', KeyframeProperty.opacity, Duration.zero, 0.0);
    p = editor.setKeyframe(p, 'pip', KeyframeProperty.opacity, const Duration(seconds: 3), 1.0);
    p = editor.addTextClip(p, clipId: 't', newTrackId: 'x', at: const Duration(seconds: 1));
    return bench('combined', p);
  }, skip: skip, timeout: timeout);

  test('4K plain clip', () {
    final a = asset('a', uhdPath, 4);
    final p = editor.addClipFromAsset(empty([a]), a, clipId: 'c', newTrackId: 'x', trackId: 'v0');
    return bench('plain', p, height: 2160, quality: ExportQuality.draft, maxRealtimeFactor: 5);
  }, skip: skip, timeout: timeout);

  test('4K keyframed opacity + fades', () {
    final a = asset('a', uhdPath, 4);
    var p = editor.addClipFromAsset(empty([a]), a, clipId: 'c', newTrackId: 'x', trackId: 'v0');
    p = editor.updateClip(p, 'c', (c) => c.copyWith(fadeIn: const Duration(seconds: 1)));
    p = editor.setKeyframe(p, 'c', KeyframeProperty.opacity, Duration.zero, 0.2);
    p = editor.setKeyframe(p, 'c', KeyframeProperty.opacity, const Duration(seconds: 4), 1.0);
    return bench('keyframed opacity+fade', p, height: 2160, quality: ExportQuality.draft, maxRealtimeFactor: 5);
  }, skip: skip, timeout: timeout);
}

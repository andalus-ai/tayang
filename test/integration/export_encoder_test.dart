import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/data/export/encoder_planner.dart';
import 'package:tayang/data/export/process_video_exporter.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

/// Real FFmpeg: a hardware encoder that can't start must fall back to software.
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
  late Project project;

  setUpAll(() async {
    if (!available) return;
    dir = await Directory.systemTemp.createTemp('tayang_enc_');
    final src = '${dir.path}/src.mp4';
    final r = await Process.run('ffmpeg', [
      '-loglevel', 'error', '-y',
      '-f', 'lavfi', '-i', 'testsrc2=size=640x360:rate=30:duration=2',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=2',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac', src,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final asset = MediaAsset(
      id: 'a', path: src, name: 'a', kind: MediaKind.video,
      duration: const Duration(seconds: 2),
    );
    project = editor.addClipFromAsset(
      Project(
        id: 'p', name: 'p', assets: [asset],
        tracks: const [Track(id: 'v', kind: TrackKind.video, name: 'V')],
      ),
      asset, clipId: 'c', newTrackId: 't',
    );
  });

  tearDownAll(() async {
    if (available) await dir.delete(recursive: true);
  });

  Future<ExportProgress> run(String os, {required bool hardware, required String name}) async {
    final exporter = ProcessVideoExporter(planner: EncoderPlanner(os));
    final events = await exporter
        .export(
          project,
          ExportSettings(height: 360, fps: 30, quality: ExportQuality.draft, hardware: hardware),
          outputPath: '${dir.path}/$name.mp4',
        )
        .toList();
    return events.last;
  }

  Future<double> duration(String name) async {
    final r = await Process.run('ffprobe', [
      '-v', 'error', '-show_entries', 'format=duration', '-of', 'json',
      '${dir.path}/$name.mp4',
    ]);
    final info = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    return double.parse((info['format'] as Map)['duration'] as String);
  }

  final skip = available ? false : 'ffmpeg not installed';
  const timeout = Timeout(Duration(minutes: 3));

  test('unavailable hardware encoders fall back to software and still export', () async {
    // CI has no NVIDIA/Intel/AMD GPU, so every Windows candidate must fail to start.
    final last = await run('windows', hardware: true, name: 'fallback');
    expect(last, isA<ExportDone>(), reason: last is ExportFailed ? last.message : null);
    expect((last as ExportDone).encoder, 'Software (x264)');
    expect(await duration('fallback'), closeTo(2.0, 0.3));
  }, skip: skip, timeout: timeout);

  test('VideoToolbox / MediaCodec plans also fall back on a machine without them', () async {
    for (final os in ['macos', 'android']) {
      final last = await run(os, hardware: true, name: 'fb_$os');
      expect(last, isA<ExportDone>(), reason: '$os: ${last is ExportFailed ? last.message : ''}');
      expect((last as ExportDone).encoder, 'Software (x264)', reason: os);
    }
  }, skip: skip, timeout: timeout);

  test('hardware off goes straight to software', () async {
    final last = await run('windows', hardware: false, name: 'sw');
    expect(last, isA<ExportDone>());
    expect((last as ExportDone).encoder, 'Software (x264)');
  }, skip: skip, timeout: timeout);

  test('a project that cannot be exported reports a failure (no hang)', () async {
    final broken = project.copyWith(
      assets: [
        MediaAsset(
          id: 'a', path: '/does/not/exist.mp4', name: 'a', kind: MediaKind.video,
          duration: const Duration(seconds: 2),
        ),
      ],
    );
    final events = await ProcessVideoExporter(planner: EncoderPlanner('windows'))
        .export(broken, const ExportSettings(height: 360, quality: ExportQuality.draft),
            outputPath: '${dir.path}/broken.mp4')
        .toList();
    expect(events.last, isA<ExportFailed>());
  }, skip: skip, timeout: timeout);
}

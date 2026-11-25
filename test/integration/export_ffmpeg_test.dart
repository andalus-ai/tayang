import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/data/export/ffmpeg_command_builder.dart';
import 'package:tayang/data/export/process_video_exporter.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/keyframes.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

/// Runs the real FFmpeg binary. Skipped automatically when it isn't installed.
bool _hasFfmpeg() {
  try {
    return Process.runSync('ffmpeg', ['-version']).exitCode == 0 &&
        Process.runSync('ffprobe', ['-version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}

const _font = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';

Future<void> _ffmpeg(List<String> args) async {
  final r = await Process.run('ffmpeg', ['-loglevel', 'error', '-y', ...args]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
}

Future<Map<String, dynamic>> _probe(String path) async {
  final r = await Process.run('ffprobe', [
    '-v', 'error',
    '-show_entries', 'format=duration:stream=codec_type',
    '-of', 'json',
    path,
  ]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return jsonDecode(r.stdout as String) as Map<String, dynamic>;
}

void main() {
  final available = _hasFfmpeg();
  const editor = TimelineEditor();

  late Directory dir;
  late String videoPath;
  late String imagePath;
  late String audioPath;

  setUpAll(() async {
    if (!available) return;
    dir = await Directory.systemTemp.createTemp('tayang_it_');
    videoPath = '${dir.path}/v.mp4';
    imagePath = '${dir.path}/i.png';
    audioPath = '${dir.path}/a.wav';
    await _ffmpeg([
      '-f', 'lavfi', '-i', 'testsrc=size=640x360:rate=30:duration=4',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=4',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac', videoPath,
    ]);
    await _ffmpeg(['-f', 'lavfi', '-i', 'color=c=red:s=320x240', '-frames:v', '1', imagePath]);
    await _ffmpeg(['-f', 'lavfi', '-i', 'sine=frequency=220:duration=6', audioPath]);
  });

  tearDownAll(() async {
    if (available) await dir.delete(recursive: true);
  });

  Future<ExportProgress> run(Project project, String name) async {
    final exporter = ProcessVideoExporter(
      builder: FfmpegCommandBuilder(fontFile: File(_font).existsSync() ? _font : null),
    );
    final events = await exporter
        .export(
          project,
          const ExportSettings(height: 360, quality: ExportQuality.draft),
          outputPath: '${dir.path}/$name.mp4',
        )
        .toList();
    return events.last;
  }

  test(
    'multi-track export with fades, keyframes, transform, text and mixed audio',
    () async {
      MediaAsset asset(String id, String path, MediaKind kind, Duration d, bool audio) =>
          MediaAsset(
              id: id, path: path, name: id, kind: kind, duration: d, hasAudio: audio);

      final video = asset('v', videoPath, MediaKind.video, const Duration(seconds: 4), true);
      final image = asset('i', imagePath, MediaKind.image, Duration.zero, false);
      final audio = asset('a', audioPath, MediaKind.audio, const Duration(seconds: 6), true);

      var p = const Project(
        id: 'p',
        name: 'it',
        tracks: [
          Track(id: 'txt', kind: TrackKind.text, name: 'T'),
          Track(id: 'v2', kind: TrackKind.video, name: 'V2'),
          Track(id: 'v1', kind: TrackKind.video, name: 'V1'),
          Track(id: 'aud', kind: TrackKind.audio, name: 'A'),
        ],
      );
      p = editor.addAsset(editor.addAsset(editor.addAsset(p, video), image), audio);
      p = editor.addClipFromAsset(p, video,
          clipId: 'cv', newTrackId: 'x', at: const Duration(seconds: 1), trackId: 'v1');
      p = editor.addClipFromAsset(p, image,
          clipId: 'ci', newTrackId: 'x', at: const Duration(seconds: 2), trackId: 'v2');
      p = editor.addClipFromAsset(p, audio,
          clipId: 'ca', newTrackId: 'x', at: Duration.zero, trackId: 'aud');
      p = editor.addTextClip(p,
          clipId: 'ct', newTrackId: 'x', at: const Duration(seconds: 1));

      p = editor.updateClip(
        p,
        'cv',
        (c) => c.copyWith(
          fadeIn: const Duration(seconds: 1),
          fadeOut: const Duration(seconds: 1),
          scale: 1.5,
          offsetX: 0.1,
        ),
      );
      p = editor.setKeyframe(p, 'cv', KeyframeProperty.opacity, const Duration(seconds: 1), 0.0);
      p = editor.setKeyframe(p, 'cv', KeyframeProperty.opacity, const Duration(seconds: 3), 1.0);
      p = editor.setKeyframe(p, 'cv', KeyframeProperty.volume, const Duration(seconds: 1), 1.0);
      p = editor.setKeyframe(p, 'cv', KeyframeProperty.volume, const Duration(seconds: 3), 0.4);
      p = editor.updateClip(p, 'ci', (c) => c.copyWith(opacity: 0.6));
      p = editor.updateClip(
        p,
        'ct',
        (c) => c.copyWith(text: c.text!.copyWith(content: "50%: it's done")),
      );

      final result = await run(p, 'full');
      expect(result, isA<ExportDone>(), reason: result is ExportFailed ? result.message : null);

      final info = await _probe('${dir.path}/full.mp4');
      final types = [for (final s in info['streams'] as List) (s as Map)['codec_type']];
      expect(types, containsAll(['video', 'audio']));
      final duration = double.parse((info['format'] as Map)['duration'] as String);
      expect(duration, closeTo(6.0, 0.4));
    },
    skip: available ? false : 'ffmpeg/ffprobe not installed',
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'speed change and split export to the expected length',
    () async {
      final video = MediaAsset(
        id: 'v', path: videoPath, name: 'v',
        kind: MediaKind.video, duration: const Duration(seconds: 4),
      );
      var p = const Project(
        id: 'p', name: 'it2',
        tracks: [Track(id: 'v1', kind: TrackKind.video, name: 'V')],
      );
      p = editor.addAsset(p, video);
      p = editor.addClipFromAsset(p, video, clipId: 'c', newTrackId: 'x');
      p = editor.setSpeed(p, 'c', 2.0); // 4s source -> 2s on the timeline
      p = editor.splitClip(p, 'c', const Duration(seconds: 1), rightClipId: 'd');

      final result = await run(p, 'speed');
      expect(result, isA<ExportDone>(), reason: result is ExportFailed ? result.message : null);
      final info = await _probe('${dir.path}/speed.mp4');
      expect(double.parse((info['format'] as Map)['duration'] as String), closeTo(2.0, 0.3));
    },
    skip: available ? false : 'ffmpeg/ffprobe not installed',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

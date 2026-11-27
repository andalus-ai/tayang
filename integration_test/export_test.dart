import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tayang/data/export/ffmpeg_runners.dart';
import 'package:tayang/data/export/ffmpeg_video_exporter.dart';
import 'package:tayang/data/export/font_provisioner.dart';
import 'package:tayang/data/media/ffmpeg_thumbnail_service.dart';
import 'package:tayang/data/media/ffmpeg_waveform_service.dart';
import 'package:tayang/data/media/ffprobe_media_probe.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/keyframes.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

import 'fixtures.dart';

/// Runs on a real Android emulator/device: exercises the FFmpegKit engine that
/// the Android / iOS / macOS / Windows builds ship (probe, thumbnails,
/// waveforms, and a multi-effect export with text).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FFmpegKit probes, renders previews and exports a multi-effect project',
      (tester) async {
    final tmp = await getTemporaryDirectory();
    final root = await Directory('${tmp.path}/tayang_it').create(recursive: true);

    Future<String> write(String name, String b64) async {
      final file = File('${root.path}/$name');
      await file.writeAsBytes(base64Decode(b64));
      return file.path;
    }

    final videoPath = await write('v.mp4', videoBase64);
    final imagePath = await write('i.png', imageBase64);
    final audioPath = await write('a.wav', audioBase64);

    // ---- probe
    final probe = FfprobeMediaProbe();
    final video = await probe.probe(videoPath);
    final image = await probe.probe(imagePath);
    final audio = await probe.probe(audioPath);
    expect(video.kind, MediaKind.video);
    expect(video.hasAudio, isTrue);
    expect(video.width, 320);
    expect(video.duration.inMilliseconds, closeTo(2000, 400));
    expect(image.kind, MediaKind.image);
    expect(audio.kind, MediaKind.audio);
    expect(audio.duration.inMilliseconds, closeTo(3000, 400));

    // ---- thumbnails + waveform (filters: scale, showwavespic, colorkey)
    Future<Directory> cache() async => Directory('${root.path}/cache').create(recursive: true);
    final thumb = await FfmpegThumbnailService(run: runWithFfmpegKit, cacheDir: cache)
        .thumbnail(video);
    expect(thumb != null && File(thumb).existsSync(), isTrue, reason: 'thumbnail');
    final wave = await FfmpegWaveformService(run: runWithFfmpegKit, cacheDir: cache)
        .waveform(audio);
    expect(wave != null && File(wave).existsSync(), isTrue, reason: 'waveform');

    // ---- project using every export feature
    const editor = TimelineEditor();
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
    for (final a in [video, image, audio]) {
      p = editor.addAsset(p, a);
    }
    p = editor.addClipFromAsset(p, video,
        clipId: 'cv', newTrackId: 'x', at: const Duration(milliseconds: 500), trackId: 'v1');
    p = editor.addClipFromAsset(p, image,
        clipId: 'ci', newTrackId: 'x', at: const Duration(seconds: 1), trackId: 'v2');
    p = editor.trimClipEnd(p, 'ci', const Duration(milliseconds: 2500));
    p = editor.addClipFromAsset(p, audio,
        clipId: 'ca', newTrackId: 'x', at: Duration.zero, trackId: 'aud');
    p = editor.addTextClip(p,
        clipId: 'ct', newTrackId: 'x', at: const Duration(milliseconds: 500));
    p = editor.trimClipEnd(p, 'ct', const Duration(milliseconds: 2500));
    p = editor.updateClip(
      p,
      'cv',
      (c) => c.copyWith(
        fadeIn: const Duration(milliseconds: 400),
        fadeOut: const Duration(milliseconds: 400),
        scale: 1.4,
        offsetX: 0.1,
      ),
    );
    p = editor.setKeyframe(
        p, 'cv', KeyframeProperty.opacity, const Duration(milliseconds: 500), 0.2);
    p = editor.setKeyframe(
        p, 'cv', KeyframeProperty.opacity, const Duration(milliseconds: 2500), 1.0);
    p = editor.setKeyframe(
        p, 'cv', KeyframeProperty.volume, const Duration(milliseconds: 500), 1.0);
    p = editor.setKeyframe(
        p, 'cv', KeyframeProperty.volume, const Duration(milliseconds: 2500), 0.4);
    p = editor.updateClip(p, 'ci', (c) => c.copyWith(opacity: 0.6));
    p = editor.updateClip(
      p,
      'ct',
      (c) => c.copyWith(text: c.text!.copyWith(content: "50%: it's done")),
    );
    expect(p.duration, const Duration(seconds: 3));

    // ---- export through FFmpegKit
    final out = '${root.path}/out.mp4';
    final events = await FfmpegVideoExporter(fontProvider: FontProvisioner().ensureFont)
        .export(
          p,
          const ExportSettings(height: 180, fps: 15, quality: ExportQuality.draft),
          outputPath: out,
        )
        .toList();
    final last = events.last;
    expect(last, isA<ExportDone>(), reason: last is ExportFailed ? last.message : null);
    if (last is ExportDone) debugPrint('ENCODER used: ${last.encoder}');

    final result = await probe.probe(out);
    expect(result.hasAudio, isTrue);
    expect(result.duration.inMilliseconds, closeTo(3000, 500));
    expect(result.width, 320);
    expect(result.height, 180);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('FFmpegKit renders crossfade and opacity keyframes with correct pixels',
      (tester) async {
    final tmp = await getTemporaryDirectory();
    final root = await Directory('${tmp.path}/tayang_px').create(recursive: true);

    Future<String> write(String name, String b64) async {
      final file = File('${root.path}/$name');
      await file.writeAsBytes(base64Decode(b64));
      return file.path;
    }

    /// RGB of one pixel of [video] at [seconds], extracted with FFmpegKit itself.
    Future<List<int>> pixel(String video, double seconds, int x, int y) async {
      final raw = '${root.path}/px_${seconds}_${x}_$y.raw';
      final session = await FFmpegKit.executeWithArguments([
        '-y', '-ss', '$seconds', '-i', video,
        '-frames:v', '1',
        '-vf', 'crop=1:1:$x:$y,format=rgb24',
        '-f', 'rawvideo', raw,
      ]);
      expect(ReturnCode.isSuccess(await session.getReturnCode()), isTrue,
          reason: 'pixel extraction at ${seconds}s');
      final bytes = await File(raw).readAsBytes();
      expect(bytes.length, 3);
      return bytes;
    }

    final probe = FfprobeMediaProbe();
    final red = await probe.probe(await write('red.mp4', redVideoBase64));
    final blue = await probe.probe(await write('blue.mp4', blueVideoBase64));
    const settings = ExportSettings(height: 180, fps: 15, quality: ExportQuality.draft);
    const editor = TimelineEditor();

    Future<String> render(Project p, String name) async {
      final out = '${root.path}/$name.mp4';
      final events = await FfmpegVideoExporter(fontProvider: FontProvisioner().ensureFont)
          .export(p, settings, outputPath: out)
          .toList();
      final last = events.last;
      expect(last, isA<ExportDone>(), reason: last is ExportFailed ? last.message : null);
      return out;
    }

    Project start(List<dynamic> assets) {
      var p = const Project(
        id: 'p',
        name: 'px',
        tracks: [Track(id: 'v1', kind: TrackKind.video, name: 'V')],
      );
      for (final a in assets) {
        p = editor.addAsset(p, a as MediaAsset);
      }
      return p;
    }

    // ---- crossfade: red -> mix -> blue
    var p = start([red, blue]);
    p = editor.addClipFromAsset(p, red, clipId: 'a', newTrackId: 'x');
    p = editor.addClipFromAsset(p, blue, clipId: 'b', newTrackId: 'x');
    p = editor.addCrossfade(p, 'a', const Duration(seconds: 2));
    final xfade = await render(p, 'xfade');

    final before = await pixel(xfade, 1.0, 160, 90);
    expect(before[0], greaterThan(200), reason: 'red before overlap: $before');
    expect(before[2], lessThan(50));
    final mid = await pixel(xfade, 3.0, 160, 90);
    expect(mid[0], closeTo(128, 45), reason: 'red fading out: $mid');
    expect(mid[2], closeTo(128, 45), reason: 'blue fading in: $mid');
    final after = await pixel(xfade, 5.0, 160, 90);
    expect(after[2], greaterThan(200), reason: 'blue after overlap: $after');
    expect(after[0], lessThan(50));

    // ---- keyframed opacity ramp (mask + alphamerge path)
    p = start([red]);
    p = editor.addClipFromAsset(p, red, clipId: 'c', newTrackId: 'x');
    p = editor.setKeyframe(p, 'c', KeyframeProperty.opacity, Duration.zero, 0.0);
    p = editor.setKeyframe(p, 'c', KeyframeProperty.opacity, const Duration(seconds: 4), 1.0);
    final ramp = await render(p, 'ramp');
    for (final t in [1.0, 2.0, 3.0]) {
      final px = await pixel(ramp, t, 160, 90);
      expect(px[0], closeTo(255 * t / 4, 45), reason: 'ramp at ${t}s: $px');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

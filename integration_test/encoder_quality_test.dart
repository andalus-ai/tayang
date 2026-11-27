import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tayang/data/export/encoder_planner.dart';
import 'package:tayang/data/export/ffmpeg_video_exporter.dart';
import 'package:tayang/data/export/font_provisioner.dart';
import 'package:tayang/data/media/ffprobe_media_probe.dart';
import 'package:tayang/domain/export/video_encoder.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

import 'fixtures_quality.dart';

/// Forces a single encoder so each one can be measured on its own.
class _Only extends EncoderPlanner {
  const _Only(this.encoder) : super('test');
  final VideoEncoder encoder;

  @override
  List<VideoEncoder> candidates({required bool hardware}) => [encoder];
}

/// Compares the platform's hardware encoder(s) with x264 on speed, size and
/// quality (SSIM / PSNR against the source). Prints "QUALITY ..." lines; the
/// numbers are what the bitrate-per-pixel table in ExportSettings is tuned from.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hardware vs software encoders: speed, size and quality', (tester) async {
    final tmp = await getTemporaryDirectory();
    final root = await Directory('${tmp.path}/tayang_quality').create(recursive: true);
    final srcPath = '${root.path}/src.mp4';
    await File(srcPath).writeAsBytes(base64Decode(qualityVideoBase64));

    final probe = FfprobeMediaProbe();
    final source = await probe.probe(srcPath);

    // 6 back-to-back copies of the 2 s clip = 12 s of output.
    const editor = TimelineEditor();
    var project = editor.addAsset(
      const Project(
        id: 'p', name: 'q',
        tracks: [Track(id: 'v', kind: TrackKind.video, name: 'V')],
      ),
      source,
    );
    for (var i = 0; i < 6; i++) {
      project = editor.addClipFromAsset(project, source, clipId: 'c$i', newTrackId: 'x');
    }
    final outSeconds = project.duration.inMicroseconds / 1e6;

    Future<String> log(List<String> args) async {
      final session = await FFmpegKit.executeWithArguments(args);
      return await session.getOutput() ?? '';
    }

    /// SSIM and PSNR of the first 2 s of [out] against the source (scaled to match).
    Future<(double?, double?)> quality(String out, int height) async {
      final width = ((height * project.width / project.height) / 2).round() * 2;
      final graph = '[1:v]scale=$width:$height:flags=bicubic[r];[0:v][r]';
      final ssim = await log(['-t', '2', '-i', out, '-t', '2', '-i', srcPath,
        '-lavfi', '${graph}ssim', '-f', 'null', '-']);
      final psnr = await log(['-t', '2', '-i', out, '-t', '2', '-i', srcPath,
        '-lavfi', '${graph}psnr', '-f', 'null', '-']);
      return (
        double.tryParse(RegExp(r'All:([0-9.]+)').allMatches(ssim).lastOrNull?.group(1) ?? ''),
        double.tryParse(RegExp(r'average:([0-9.]+)').allMatches(psnr).lastOrNull?.group(1) ?? ''),
      );
    }

    final encoders = <VideoEncoder>{
      VideoEncoder.software,
      ...EncoderPlanner.current().candidates(hardware: true),
    };
    final lines = <String>[];
    const height = 720;

    Future<void> measure(VideoEncoder encoder, ExportSettings settings, String tag) async {
      final out = '${root.path}/${encoder.name}_${tag.replaceAll(RegExp(r'[^\w.]'), '_')}.mp4';
      final sw = Stopwatch()..start();
      final events = await FfmpegVideoExporter(
        fontProvider: FontProvisioner().ensureFont,
        planner: _Only(encoder),
        validator: probe,
      ).export(project, settings, outputPath: out).toList();
      sw.stop();

      final head = 'QUALITY enc="${encoder.label}" $tag ${height}p';
      if (events.last is! ExportDone) {
        lines.add('$head UNAVAILABLE');
        return;
      }
      final seconds = sw.elapsedMicroseconds / 1e6;
      final bytes = File(out).lengthSync();
      final (ssim, psnr) = await quality(out, height);
      lines.add('$head time=${seconds.toStringAsFixed(2)}s '
          'speed=${(outSeconds / seconds).toStringAsFixed(1)}x '
          'bitrate=${(bytes * 8 / outSeconds / 1000).round()}kbps '
          'ssim=${ssim?.toStringAsFixed(4)} psnr=${psnr?.toStringAsFixed(1)}dB');
      expect(ssim, isNotNull, reason: 'could not measure SSIM for $head');
      expect(ssim!, greaterThan(0.75), reason: '$head looks badly degraded');
    }

    final pixelsPerSecond = (height * project.width / project.height) * height * 30;
    for (final encoder in encoders) {
      for (final q in [ExportQuality.draft, ExportQuality.standard, ExportQuality.high]) {
        await measure(encoder, ExportSettings(height: height, fps: 30, quality: q), 'q=${q.name}');
      }
      if (encoder.isHardware) {
        // Sweep the bitrate to find how few bits the hardware encoder needs to
        // match x264's quality.
        for (final bpp in [0.02, 0.03, 0.045, 0.06]) {
          await measure(
            encoder,
            ExportSettings(
              height: height,
              fps: 30,
              bitrateOverride: (pixelsPerSecond * bpp).round(),
            ),
            'bpp=$bpp',
          );
        }
      }
    }

    for (final l in lines) {
      debugPrint(l);
    }
    expect(lines.any((l) => l.contains('Software') && !l.contains('UNAVAILABLE')), isTrue);
  }, timeout: const Timeout(Duration(minutes: 15)));
}

import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'fixtures_content.dart';

/// Rate-quality behaviour of x264 and VideoToolbox across very different content
/// (sharp screen text, flat animation, graded footage with grain). Encoders are
/// driven directly so settings can be compared independent of the app pipeline.
/// Prints compact "CONTENT ..." lines; encoders that don't exist on the platform
/// are reported UNAVAILABLE rather than failing.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rate-quality across content types', (tester) async {
    final tmp = await getTemporaryDirectory();
    final root = await Directory('${tmp.path}/tayang_content').create(recursive: true);

    Future<(bool, String)> ffmpeg(List<String> args) async {
      final session = await FFmpegKit.executeWithArguments(args);
      return (ReturnCode.isSuccess(await session.getReturnCode()),
          await session.getOutput() ?? '');
    }

    final classes = {
      'screen': screenBase64,
      'animation': animationBase64,
      'footage': footageBase64,
    };
    final lines = <String>[];
    var x264Worked = false;

    for (final entry in classes.entries) {
      final src = '${root.path}/${entry.key}.mp4';
      await File(src).writeAsBytes(base64Decode(entry.value));

      Future<void> measure(String tag, List<String> encoderArgs) async {
        final out = '${root.path}/${entry.key}_${tag.replaceAll(RegExp(r'[^\w]'), '_')}.mp4';
        final sw = Stopwatch()..start();
        // 6 loops of the 2 s clip = 12 s encoded, upscaled to 720p.
        final (ok, _) = await ffmpeg([
          '-y', '-stream_loop', '5', '-i', src,
          '-vf', 'scale=1280:720:flags=bicubic,format=yuv420p',
          ...encoderArgs, '-an', out,
        ]);
        sw.stop();
        final head = 'CONTENT ${entry.key.padRight(9)} ${tag.padRight(12)}';
        if (!ok || !File(out).existsSync()) {
          lines.add('$head UNAVAILABLE');
          return;
        }
        final kbps = (File(out).lengthSync() * 8 / 12 / 1000).round();
        const graph = '[1:v]scale=1280:720:flags=bicubic[r];[0:v][r]';
        final (_, ssimLog) = await ffmpeg(
            ['-t', '2', '-i', out, '-t', '2', '-i', src, '-lavfi', '${graph}ssim', '-f', 'null', '-']);
        final (_, psnrLog) = await ffmpeg(
            ['-t', '2', '-i', out, '-t', '2', '-i', src, '-lavfi', '${graph}psnr', '-f', 'null', '-']);
        final ssim = RegExp(r'All:([0-9.]+)').allMatches(ssimLog).lastOrNull?.group(1);
        final psnr = RegExp(r'average:([0-9.]+)').allMatches(psnrLog).lastOrNull?.group(1);
        lines.add('$head ${(12 / (sw.elapsedMicroseconds / 1e6)).toStringAsFixed(1).padLeft(5)}x '
            '${kbps.toString().padLeft(5)}kbps ssim=$ssim psnr=${psnr == null ? '?' : double.parse(psnr).toStringAsFixed(1)}');
        if (tag.startsWith('x264')) x264Worked = true;
      }

      // x264 constant quality (what software export uses).
      for (final crf in [18, 23, 28]) {
        await measure('x264 crf$crf',
            ['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '$crf']);
      }
      // Hardware, bitrate mode (what the app uses today), bits per pixel at 720p30.
      const pps = 1280 * 720 * 30;
      for (final bpp in [0.03, 0.06, 0.12]) {
        await measure('VT bpp$bpp',
            ['-c:v', 'h264_videotoolbox', '-b:v', '${(pps * bpp).round()}']);
      }
      // Hardware, constant-quality mode (content adaptive, like CRF).
      for (final q in [40, 55, 70, 85]) {
        await measure('VT q$q', ['-c:v', 'h264_videotoolbox', '-q:v', '$q']);
      }
    }

    for (final l in lines) {
      debugPrint(l);
    }
    expect(x264Worked, isTrue);
  }, timeout: const Timeout(Duration(minutes: 20)));
}

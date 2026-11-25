import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../media/ffmpeg_thumbnail_service.dart';

/// FFmpegKit-backed runner (Android / iOS / macOS / Windows).
Future<bool> runWithFfmpegKit(List<String> args) async {
  final session = await FFmpegKit.executeWithArguments(args);
  return ReturnCode.isSuccess(await session.getReturnCode());
}

/// System-`ffmpeg`-backed runner (Linux).
FfmpegRun processRunner([String executable = 'ffmpeg']) => (args) async {
      final result = await Process.run(executable, args);
      return result.exitCode == 0;
    };

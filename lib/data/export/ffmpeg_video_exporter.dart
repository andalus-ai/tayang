import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../../domain/export/video_exporter.dart';
import '../../domain/models/project.dart';
import 'ffmpeg_command_builder.dart';

class FfmpegVideoExporter implements VideoExporter {
  FfmpegVideoExporter({FfmpegCommandBuilder builder = const FfmpegCommandBuilder()})
      : _builder = builder;

  final FfmpegCommandBuilder _builder;

  @override
  Stream<ExportProgress> export(
    Project project,
    ExportSettings settings, {
    required String outputPath,
  }) {
    final controller = StreamController<ExportProgress>();
    final totalMs = project.duration.inMilliseconds;
    final args = _builder.build(project, settings, outputPath: outputPath);

    FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final code = await session.getReturnCode();
        if (controller.isClosed) return;
        if (ReturnCode.isSuccess(code)) {
          controller.add(ExportDone(outputPath));
        } else if (ReturnCode.isCancel(code)) {
          controller.add(const ExportFailed('Export cancelled'));
        } else {
          final log = await session.getOutput() ?? '';
          final tail = log.length > 700 ? log.substring(log.length - 700) : log;
          controller.add(ExportFailed(tail.isEmpty ? 'FFmpeg failed' : tail));
        }
        await controller.close();
      },
      null,
      (statistics) {
        if (controller.isClosed || totalMs <= 0) return;
        final fraction = (statistics.getTime() / totalMs).clamp(0.0, 1.0).toDouble();
        controller.add(ExportRunning(fraction.toDouble()));
      },
    );

    return controller.stream;
  }

  @override
  Future<void> cancel() => FFmpegKit.cancel();
}

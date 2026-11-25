import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/export/video_exporter.dart';
import '../../domain/models/project.dart';
import 'ffmpeg_command_builder.dart';

/// Exporter that shells out to a system `ffmpeg` binary (Linux / any desktop
/// where FFmpegKit isn't available). Same command builder, different runner.
class ProcessVideoExporter implements VideoExporter {
  ProcessVideoExporter({
    this.executable = 'ffmpeg',
    FfmpegCommandBuilder builder = const FfmpegCommandBuilder(),
  }) : _builder = builder;

  final String executable;
  final FfmpegCommandBuilder _builder;
  Process? _process;
  bool _cancelled = false;

  @override
  Stream<ExportProgress> export(
    Project project,
    ExportSettings settings, {
    required String outputPath,
  }) {
    final controller = StreamController<ExportProgress>();
    _cancelled = false;

    unawaited(() async {
      try {
        final args = _builder.build(project, settings, outputPath: outputPath);
        // `-progress` is an output option → must come before the output path.
        final withProgress = [
          ...args.take(args.length - 1),
          '-progress', 'pipe:1', '-nostats',
          args.last,
        ];
        final process = await Process.start(executable, withProgress);
        _process = process;

        final totalUs = project.duration.inMicroseconds;
        final stderrBuffer = StringBuffer();
        process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);
        final stdoutDone = process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .forEach((line) {
          if (!line.startsWith('out_time_us=') || totalUs <= 0) return;
          final us = int.tryParse(line.substring('out_time_us='.length));
          if (us != null && us >= 0) {
            controller.add(ExportRunning((us / totalUs).clamp(0.0, 1.0).toDouble()));
          }
        });

        final code = await process.exitCode;
        await stdoutDone;
        _process = null;

        if (code == 0) {
          controller.add(ExportDone(outputPath));
        } else if (_cancelled) {
          controller.add(const ExportFailed('Export cancelled'));
        } else {
          final log = stderrBuffer.toString();
          controller.add(ExportFailed(
              log.length > 700 ? log.substring(log.length - 700) : log));
        }
      } on ProcessException catch (e) {
        controller.add(ExportFailed(
            'Could not start "$executable". Install FFmpeg and add it to PATH.\n${e.message}'));
      } finally {
        await controller.close();
      }
    }());

    return controller.stream;
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    _process?.kill();
  }
}

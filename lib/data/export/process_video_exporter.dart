import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/export/video_exporter.dart';
import '../../domain/models/project.dart';
import 'encoder_planner.dart';
import 'ffmpeg_command_builder.dart';

/// Exporter that shells out to a system `ffmpeg` binary (Linux / any desktop
/// where FFmpegKit isn't available). Same command builder, different runner.
/// Tries hardware encoders first and falls back to software automatically.
class ProcessVideoExporter implements VideoExporter {
  ProcessVideoExporter({
    this.executable = 'ffmpeg',
    FfmpegCommandBuilder builder = const FfmpegCommandBuilder(),
    Future<String?> Function()? fontProvider,
    EncoderPlanner? planner,
  })  : _builder = builder,
        _fontProvider = fontProvider,
        _planner = planner ?? EncoderPlanner.current();

  final String executable;
  final FfmpegCommandBuilder _builder;
  final Future<String?> Function()? _fontProvider;
  final EncoderPlanner _planner;
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
        final font = await _fontProvider?.call();
        final builder = font == null ? _builder : FfmpegCommandBuilder(fontFile: font);
        var lastLog = '';

        for (final encoder in _planner.candidates(hardware: settings.hardware)) {
          final args = builder.build(project, settings,
              outputPath: outputPath, encoder: encoder);
          final result = await _run(args, project.duration.inMicroseconds, controller);
          if (result.code == 0) {
            controller.add(ExportDone(outputPath, encoder: encoder.label));
            return;
          }
          if (_cancelled) {
            controller.add(const ExportFailed('Export cancelled'));
            return;
          }
          lastLog = result.log; // try the next encoder (software is always last)
        }
        controller.add(ExportFailed(
            lastLog.length > 700 ? lastLog.substring(lastLog.length - 700) : lastLog));
      } on ProcessException catch (e) {
        controller.add(ExportFailed(
            'Could not start "$executable". Install FFmpeg and add it to PATH.\n${e.message}'));
      } finally {
        await controller.close();
      }
    }());

    return controller.stream;
  }

  Future<({int code, String log})> _run(
    List<String> args,
    int totalUs,
    StreamController<ExportProgress> controller,
  ) async {
    // `-progress` is an output option → must come before the output path.
    final withProgress = [
      ...args.take(args.length - 1),
      '-progress', 'pipe:1', '-nostats',
      args.last,
    ];
    final process = await Process.start(executable, withProgress);
    _process = process;

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
    return (code: code, log: stderrBuffer.toString());
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    _process?.kill();
  }
}

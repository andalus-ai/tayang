import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../../domain/export/video_exporter.dart';
import '../../domain/models/project.dart';
import '../../domain/repositories/media_repository.dart';
import 'encoder_planner.dart';
import 'export_validation.dart';
import 'ffmpeg_command_builder.dart';

/// FFmpegKit exporter (Android / iOS / macOS / Windows). Tries the platform's
/// hardware encoder first and falls back to software x264 automatically.
class FfmpegVideoExporter implements VideoExporter {
  FfmpegVideoExporter({
    FfmpegCommandBuilder builder = const FfmpegCommandBuilder(),
    Future<String?> Function()? fontProvider,
    EncoderPlanner? planner,
    MediaProbe? validator,
  })  : _builder = builder,
        _fontProvider = fontProvider,
        _planner = planner ?? EncoderPlanner.current(),
        _validator = validator;

  final FfmpegCommandBuilder _builder;
  final Future<String?> Function()? _fontProvider;
  final EncoderPlanner _planner;
  final MediaProbe? _validator;
  bool _cancelled = false;

  @override
  Stream<ExportProgress> export(
    Project project,
    ExportSettings settings, {
    required String outputPath,
  }) {
    final controller = StreamController<ExportProgress>();
    final totalMs = project.duration.inMilliseconds;
    _cancelled = false;

    unawaited(() async {
      try {
        final font = await _fontProvider?.call();
        final builder = font == null ? _builder : FfmpegCommandBuilder(fontFile: font);
        var lastLog = '';

        for (final encoder in _planner.candidates(hardware: settings.hardware)) {
          final args = builder.build(project, settings,
              outputPath: outputPath, encoder: encoder);
          final outcome = await _run(args, totalMs, controller);
          if (outcome.success) {
            if (await exportLooksValid(_validator, outputPath, project.duration)) {
              controller.add(ExportDone(outputPath, encoder: encoder.label));
              return;
            }
            lastLog = '${encoder.label} produced an unusable file.';
            continue; // e.g. a hardware encoder that "succeeded" with no video
          }
          if (outcome.cancelled || _cancelled) {
            controller.add(const ExportFailed('Export cancelled'));
            return;
          }
          lastLog = outcome.log; // try the next encoder (software is always last)
        }
        final tail = lastLog.length > 700 ? lastLog.substring(lastLog.length - 700) : lastLog;
        controller.add(ExportFailed(tail.isEmpty ? 'FFmpeg failed' : tail));
      } catch (e) {
        controller.add(ExportFailed('$e'));
      } finally {
        await controller.close();
      }
    }());

    return controller.stream;
  }

  Future<({bool success, bool cancelled, String log})> _run(
    List<String> args,
    int totalMs,
    StreamController<ExportProgress> controller,
  ) {
    final done = Completer<({bool success, bool cancelled, String log})>();
    FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final code = await session.getReturnCode();
        final success = ReturnCode.isSuccess(code);
        final cancelled = ReturnCode.isCancel(code);
        final log = success || cancelled ? '' : (await session.getOutput() ?? '');
        if (!done.isCompleted) {
          done.complete((success: success, cancelled: cancelled, log: log));
        }
      },
      null,
      (statistics) {
        if (controller.isClosed || totalMs <= 0) return;
        final fraction = (statistics.getTime() / totalMs).clamp(0.0, 1.0).toDouble();
        controller.add(ExportRunning(fraction));
      },
    ).catchError((Object e) {
      if (!done.isCompleted) done.complete((success: false, cancelled: false, log: '$e'));
      throw e;
    });
    return done.future;
  }

  @override
  Future<void> cancel() {
    _cancelled = true;
    return FFmpegKit.cancel();
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/export/video_exporter.dart';
import 'di.dart';
import 'playback_controller.dart';
import 'project_controller.dart';

enum ExportStatus { idle, running, done, failed }

class ExportState {
  const ExportState({
    this.status = ExportStatus.idle,
    this.progress = 0,
    this.outputPath,
    this.error,
  });

  final ExportStatus status;
  final double progress;
  final String? outputPath;
  final String? error;
}

class ExportController extends Notifier<ExportState> {
  StreamSubscription<ExportProgress>? _subscription;

  @override
  ExportState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const ExportState();
  }

  Future<void> start(ExportSettings settings) async {
    if (state.status == ExportStatus.running) return;

    final project = ref.read(projectProvider);
    if (project.duration == Duration.zero) {
      state = const ExportState(
        status: ExportStatus.failed,
        error: 'The timeline is empty — add some clips first.',
      );
      return;
    }

    ref.read(playbackProvider.notifier).pause();
    state = const ExportState(status: ExportStatus.running);

    final safeName = project.name.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final path = await ref
        .read(exportPathResolverProvider)('${safeName}_${DateTime.now().millisecondsSinceEpoch}.mp4');

    await _subscription?.cancel();
    _subscription = ref
        .read(videoExporterProvider)
        .export(project, settings, outputPath: path)
        .listen((event) {
      state = switch (event) {
        ExportRunning(:final fraction) =>
          ExportState(status: ExportStatus.running, progress: fraction),
        ExportDone(:final outputPath) => ExportState(
            status: ExportStatus.done, progress: 1, outputPath: outputPath),
        ExportFailed(:final message) =>
          ExportState(status: ExportStatus.failed, error: message),
      };
    });
  }

  Future<void> cancel() => ref.read(videoExporterProvider).cancel();

  void reset() {
    _subscription?.cancel();
    state = const ExportState();
  }
}

final exportControllerProvider =
    NotifierProvider<ExportController, ExportState>(ExportController.new);

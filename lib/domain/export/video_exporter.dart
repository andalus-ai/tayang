import '../models/project.dart';

enum ExportQuality {
  draft('Draft', 30, 'ultrafast'),
  standard('Standard', 23, 'veryfast'),
  high('High', 18, 'medium');

  const ExportQuality(this.label, this.crf, this.preset);
  final String label;
  final int crf;
  final String preset;
}

class ExportSettings {
  const ExportSettings({
    this.height = 1080,
    this.fps = 30,
    this.quality = ExportQuality.standard,
  });

  final int height;
  final int fps;
  final ExportQuality quality;

  /// Keeps the project's aspect ratio; H.264 needs even dimensions.
  int widthFor(Project p) => ((height * p.width / p.height) / 2).round() * 2;

  ExportSettings copyWith({int? height, int? fps, ExportQuality? quality}) =>
      ExportSettings(
        height: height ?? this.height,
        fps: fps ?? this.fps,
        quality: quality ?? this.quality,
      );
}

sealed class ExportProgress {
  const ExportProgress();
}

class ExportRunning extends ExportProgress {
  const ExportRunning(this.fraction);
  final double fraction;
}

class ExportDone extends ExportProgress {
  const ExportDone(this.outputPath);
  final String outputPath;
}

class ExportFailed extends ExportProgress {
  const ExportFailed(this.message);
  final String message;
}

/// Renders a [Project] to a video file. Implementations are swappable
/// (FFmpegKit on mobile, a native `ffmpeg` process on desktop, a fake in tests).
abstract interface class VideoExporter {
  Stream<ExportProgress> export(
    Project project,
    ExportSettings settings, {
    required String outputPath,
  });

  Future<void> cancel();
}

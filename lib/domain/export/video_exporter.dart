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
    this.hardware = true,
    this.bitrateOverride,
  });

  final int height;
  final int fps;
  final ExportQuality quality;

  /// Try the platform's hardware encoder first (falls back to software).
  final bool hardware;

  /// Explicit hardware-encoder bitrate (bits/s); null = derived from [quality].
  /// Used by the encoder-comparison benchmark.
  final int? bitrateOverride;

  /// Keeps the project's aspect ratio; H.264 needs even dimensions.
  int widthFor(Project p) => ((height * p.width / p.height) / 2).round() * 2;

  /// Target bitrate (bits/s) for hardware encoders: bits-per-pixel by quality.
  int bitrateFor(Project p) {
    final override = bitrateOverride;
    if (override != null) return override;
    final bitsPerPixel = switch (quality) {
      ExportQuality.draft => 0.05,
      ExportQuality.standard => 0.09,
      ExportQuality.high => 0.16,
    };
    final bps = (widthFor(p) * height * fps * bitsPerPixel).round();
    return bps < 500000 ? 500000 : (bps > 80000000 ? 80000000 : bps);
  }

  ExportSettings copyWith({
    int? height,
    int? fps,
    ExportQuality? quality,
    bool? hardware,
    int? bitrateOverride,
  }) =>
      ExportSettings(
        height: height ?? this.height,
        fps: fps ?? this.fps,
        quality: quality ?? this.quality,
        hardware: hardware ?? this.hardware,
        bitrateOverride: bitrateOverride ?? this.bitrateOverride,
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
  const ExportDone(this.outputPath, {this.encoder});
  final String outputPath;

  /// Label of the encoder that produced the file (e.g. "Software (x264)").
  final String? encoder;
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

import '../models/project.dart';

enum ExportQuality {
  // crf/preset drive x264. hardwareQuality is VideoToolbox's constant-quality
  // value (0-100), matched to x264's SSIM at crf 28 / 23 / 18 across screen text,
  // flat animation and graded footage (integration_test/encoder_content_test.dart).
  draft('Draft', 30, 'ultrafast', 45),
  standard('Standard', 23, 'veryfast', 60),
  high('High', 18, 'medium', 72);

  const ExportQuality(this.label, this.crf, this.preset, this.hardwareQuality);
  final String label;
  final int crf;
  final String preset;
  final int hardwareQuality;
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

  /// Target bitrate (bits/s) for hardware encoders: bits-per-pixel by quality
  /// (software x264 uses constant quality instead).
  int bitrateFor(Project p) {
    final override = bitrateOverride;
    if (override != null) return override;
    // Tuned from measurements (VideoToolbox vs x264, SSIM against the source,
    // see integration_test/encoder_quality_test.dart): 0.06 bits/pixel matches
    // x264 "standard" quality (SSIM 0.989); returns diminish above ~0.1.
    final bitsPerPixel = switch (quality) {
      ExportQuality.draft => 0.03,
      ExportQuality.standard => 0.06,
      ExportQuality.high => 0.12,
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

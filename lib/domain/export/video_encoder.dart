import 'video_exporter.dart';

/// H.264 encoders the exporter can use. Hardware ones are much faster on
/// supported devices but may be unavailable at runtime, so the exporter always
/// falls back to [software].
enum VideoEncoder {
  software('Software (x264)', 'libx264', false),
  /// Constant-quality mode (content adaptive, like x264's CRF). Apple Silicon only.
  videoToolboxQuality('Apple VideoToolbox', 'h264_videotoolbox', true),

  /// Bitrate mode: fallback where constant quality is unavailable (Intel Macs).
  videoToolbox('Apple VideoToolbox (bitrate)', 'h264_videotoolbox', true),
  mediaCodec('Android MediaCodec', 'h264_mediacodec', true),
  nvenc('NVIDIA NVENC', 'h264_nvenc', true),
  quickSync('Intel Quick Sync', 'h264_qsv', true),
  amf('AMD AMF', 'h264_amf', true);

  const VideoEncoder(this.label, this.ffmpegName, this.isHardware);

  final String label;
  final String ffmpegName;
  final bool isHardware;

  /// FFmpeg output arguments selecting this encoder. x264 and VideoToolbox's
  /// quality mode are constant-quality; other hardware encoders are bitrate driven.
  List<String> args(ExportSettings settings, {required int bitrate}) {
    if (this == videoToolboxQuality) {
      return ['-c:v', ffmpegName, '-q:v', '${settings.quality.hardwareQuality}'];
    }
    return isHardware
        ? ['-c:v', ffmpegName, '-b:v', '$bitrate']
        : [
          '-c:v', 'libx264',
          '-preset', settings.quality.preset,
          '-crf', '${settings.quality.crf}',
        ];
  }
}

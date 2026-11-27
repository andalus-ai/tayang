import 'video_exporter.dart';

/// H.264 encoders the exporter can use. Hardware ones are much faster on
/// supported devices but may be unavailable at runtime, so the exporter always
/// falls back to [software].
enum VideoEncoder {
  software('Software (x264)', 'libx264', false),
  videoToolbox('Apple VideoToolbox', 'h264_videotoolbox', true),
  mediaCodec('Android MediaCodec', 'h264_mediacodec', true),
  nvenc('NVIDIA NVENC', 'h264_nvenc', true),
  quickSync('Intel Quick Sync', 'h264_qsv', true),
  amf('AMD AMF', 'h264_amf', true);

  const VideoEncoder(this.label, this.ffmpegName, this.isHardware);

  final String label;
  final String ffmpegName;
  final bool isHardware;

  /// FFmpeg output arguments selecting this encoder. Hardware encoders are
  /// bitrate-driven; x264 uses constant quality (CRF).
  List<String> args(ExportSettings settings, {required int bitrate}) => isHardware
      ? ['-c:v', ffmpegName, '-b:v', '$bitrate']
      : [
          '-c:v', 'libx264',
          '-preset', settings.quality.preset,
          '-crf', '${settings.quality.crf}',
        ];
}

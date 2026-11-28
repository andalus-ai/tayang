import 'dart:io';

import '../../domain/export/video_encoder.dart';

/// Which encoders to try, in order, on a platform. The last entry is always
/// [VideoEncoder.software], so an export can always complete.
class EncoderPlanner {
  const EncoderPlanner(this.platform);

  /// Uses the running platform (`android`, `ios`, `macos`, `windows`, `linux`).
  factory EncoderPlanner.current() => EncoderPlanner(Platform.operatingSystem);

  final String platform;

  List<VideoEncoder> candidates({required bool hardware}) {
    if (!hardware) return const [VideoEncoder.software];
    return switch (platform) {
      'macos' || 'ios' => const [
          VideoEncoder.videoToolboxQuality,
          VideoEncoder.videoToolbox,
          VideoEncoder.software,
        ],
      'android' => const [VideoEncoder.mediaCodec, VideoEncoder.software],
      'windows' => const [
          VideoEncoder.nvenc,
          VideoEncoder.quickSync,
          VideoEncoder.amf,
          VideoEncoder.software,
        ],
      _ => const [VideoEncoder.software],
    };
  }
}

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/duration_x.dart';
import '../../core/utils/id.dart';
import '../../domain/models/media_asset.dart';
import '../../domain/repositories/media_repository.dart';

class FfprobeMediaProbe implements MediaProbe {
  @override
  Future<MediaAsset> probe(String path) async {
    final kind = MediaKinds.fromPath(path);
    if (kind == null) {
      throw MediaProbeException('Unsupported file type: ${p.basename(path)}');
    }

    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) {
      throw MediaProbeException('Could not read ${p.basename(path)}');
    }

    final streams = info.getStreams();
    final video = streams.where((s) => s.getType() == 'video').firstOrNull;
    final hasAudio = streams.any((s) => s.getType() == 'audio');
    final seconds = double.tryParse(info.getDuration() ?? '') ?? 0;

    return MediaAsset(
      id: newId('asset_'),
      path: path,
      name: p.basename(path),
      kind: kind,
      duration: kind == MediaKind.image ? Duration.zero : secondsToDuration(seconds),
      width: video?.getWidth(),
      height: video?.getHeight(),
      hasAudio: kind != MediaKind.image && hasAudio,
    );
  }
}

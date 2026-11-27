import '../../domain/repositories/media_repository.dart';

/// Checks that an exported file is actually usable: it can be probed, has a video
/// stream and is not drastically shorter than expected. Hardware encoders can
/// "succeed" (exit code 0) yet write an unusable file, so success codes alone
/// are not trusted. With no [probe] the file is assumed valid.
Future<bool> exportLooksValid(MediaProbe? probe, String path, Duration expected) async {
  if (probe == null) return true;
  try {
    final media = await probe.probe(path);
    if (media.width == null || media.height == null) return false;
    return media.duration >= expected * 0.8;
  } catch (_) {
    return false;
  }
}

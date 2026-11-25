import 'package:file_picker/file_picker.dart';

import '../../domain/models/media_asset.dart';
import '../../domain/repositories/media_repository.dart';

class FileMediaRepository implements MediaRepository {
  FileMediaRepository({required MediaProbe probe}) : _probe = probe;

  final MediaProbe _probe;

  @override
  Future<List<MediaAsset>> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: MediaKinds.allExtensions,
    );
    if (result == null) return const [];

    final assets = <MediaAsset>[];
    final failures = <String>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      try {
        assets.add(await _probe.probe(path));
      } on MediaProbeException catch (e) {
        failures.add(e.message);
      }
    }
    if (assets.isEmpty && failures.isNotEmpty) {
      throw MediaProbeException(failures.join('\n'));
    }
    return assets;
  }
}

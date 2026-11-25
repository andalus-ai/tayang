import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/media_asset.dart';
import '../domain/repositories/media_repository.dart';
import 'di.dart';
import 'project_controller.dart';

class MediaImportController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> importMedia() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final assets = await ref.read(mediaRepositoryProvider).pickAndImport();
      if (assets.isNotEmpty) {
        ref.read(projectControllerProvider.notifier).addAssets(assets);
      }
    });
  }

  /// Lets the user pick the moved/renamed file for [old] and re-points it.
  Future<void> relink(MediaAsset old) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final picked = await ref.read(mediaRepositoryProvider).pickAndImport();
      if (picked.isEmpty) return;
      final file = picked.first;
      if (file.kind != old.kind) {
        throw MediaProbeException('Please pick a ${old.kind.name} file.');
      }
      ref.read(projectControllerProvider.notifier).relinkAsset(
            MediaAsset(
              id: old.id,
              path: file.path,
              name: file.name,
              kind: file.kind,
              duration: file.duration,
              width: file.width,
              height: file.height,
              hasAudio: file.hasAudio,
            ),
          );
    });
  }
}

final mediaImportControllerProvider =
    AsyncNotifierProvider<MediaImportController, void>(MediaImportController.new);

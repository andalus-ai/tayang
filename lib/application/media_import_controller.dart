import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

final mediaImportControllerProvider =
    AsyncNotifierProvider<MediaImportController, void>(MediaImportController.new);

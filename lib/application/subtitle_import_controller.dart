import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'di.dart';
import 'project_controller.dart';

class SubtitleImportController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Lets the user pick a subtitle file and adds it as a text track.
  /// Returns the number of clips added, or null if cancelled / failed.
  Future<int?> importFile() async {
    state = const AsyncLoading();
    int? added;
    state = await AsyncValue.guard(() async {
      final cues = await ref.read(subtitleSourceProvider).pick();
      if (cues == null) return;
      if (cues.isEmpty) {
        throw const FormatException('No subtitles were found in that file.');
      }
      added = ref.read(projectControllerProvider.notifier).importSubtitles(cues);
    });
    return added;
  }
}

final subtitleImportProvider =
    AsyncNotifierProvider<SubtitleImportController, void>(SubtitleImportController.new);

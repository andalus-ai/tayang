import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/project_repository.dart';
import 'autosave.dart';
import 'di.dart';
import 'editor_actions.dart';
import 'playback_controller.dart';
import 'project_controller.dart';

/// The saved-projects browser: list, open, delete.
class ProjectLibraryController extends AutoDisposeAsyncNotifier<List<ProjectSummary>> {
  @override
  Future<List<ProjectSummary>> build() async {
    // Save the current project first so it shows up (and is current) in the list.
    await ref.read(autosaveFlushProvider)();
    return ref.read(projectRepositoryProvider).list();
  }

  Future<void> open(String id) async {
    await ref.read(autosaveFlushProvider)(); // never lose the project we leave
    final project = await ref.read(projectRepositoryProvider).load(id);
    if (project == null) return;
    ref.read(playbackProvider.notifier)
      ..pause()
      ..seek(Duration.zero);
    ref.read(projectControllerProvider.notifier).replaceProject(project);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final isCurrent = ref.read(projectProvider).id == id;
    await ref.read(projectRepositoryProvider).delete(id);
    if (isCurrent) ref.read(editorActionsProvider).newProject();
    ref.invalidateSelf();
  }
}

final projectLibraryProvider =
    AsyncNotifierProvider.autoDispose<ProjectLibraryController, List<ProjectSummary>>(
        ProjectLibraryController.new);

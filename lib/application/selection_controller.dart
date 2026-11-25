import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/project.dart';
import 'project_controller.dart';

/// Id of the selected clip. Clears itself when that clip disappears.
class SelectionController extends Notifier<String?> {
  @override
  String? build() {
    ref.listen<Project>(projectProvider, (_, next) {
      final id = state;
      if (id != null && next.clipById(id) == null) state = null;
    });
    return null;
  }

  void select(String? clipId) => state = clipId;
  void clear() => state = null;
}

final selectionProvider =
    NotifierProvider<SelectionController, String?>(SelectionController.new);

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/project.dart';
import 'di.dart';
import 'project_controller.dart';

/// Debounced autosave. Watch it once near the root to activate it.
final autosaveProvider = Provider<void>((ref) {
  Timer? debounce;
  ref.listen<Project>(projectProvider, (_, next) {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () {
      ref.read(projectRepositoryProvider).save(next);
    });
  });
  ref.onDispose(() => debounce?.cancel());
});

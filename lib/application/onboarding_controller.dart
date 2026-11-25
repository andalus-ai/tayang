import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/engine_check.dart';
import 'di.dart';

/// `true` while the first-run welcome dialog still has to be shown.
class WelcomeController extends Notifier<bool> {
  @override
  bool build() => !ref.read(initialWelcomeSeenProvider);

  void dismiss() {
    if (!state) return;
    state = false;
    ref.read(settingsRepositoryProvider).markWelcomeSeen();
  }
}

final welcomeProvider =
    NotifierProvider<WelcomeController, bool>(WelcomeController.new);

/// Result of the FFmpeg availability check (shown as a banner when not ready).
final engineStatusProvider = FutureProvider<EngineStatus>(
  (ref) => ref.watch(engineCheckProvider).check(),
);

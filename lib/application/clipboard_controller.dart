import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/clip.dart';

/// In-app clipboard holding one copied clip.
class ClipboardController extends Notifier<TimelineClip?> {
  @override
  TimelineClip? build() => null;

  void copy(TimelineClip clip) => state = clip;
}

final clipboardProvider =
    NotifierProvider<ClipboardController, TimelineClip?>(ClipboardController.new);

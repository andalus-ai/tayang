import 'dart:io';

import 'package:video_player/video_player.dart';

/// Small LRU cache of initialised [VideoPlayerController]s keyed by file path,
/// so cutting between clips doesn't pay the decoder start-up cost every time.
class PlayerPool {
  PlayerPool({this.maxSize = 4});

  final int maxSize;
  final _entries = <String, Future<VideoPlayerController>>{};

  Future<VideoPlayerController> acquire(String path) {
    final existing = _entries.remove(path);
    if (existing != null) {
      _entries[path] = existing; // mark most-recently used
      return existing;
    }
    final created = _create(path);
    _entries[path] = created;
    _evict();
    return created;
  }

  Future<VideoPlayerController> _create(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
    } catch (_) {
      _entries.remove(path);
      await controller.dispose();
      rethrow;
    }
    return controller;
  }

  void _evict() {
    while (_entries.length > maxSize) {
      final oldest = _entries.keys.first;
      _disposeEntry(_entries.remove(oldest)!);
    }
  }

  void _disposeEntry(Future<VideoPlayerController> entry) {
    entry.then((c) => c.dispose(), onError: (_) {});
  }

  void dispose() {
    for (final entry in _entries.values) {
      _disposeEntry(entry);
    }
    _entries.clear();
  }
}

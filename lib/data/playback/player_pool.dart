import 'dart:io';

import 'package:video_player/video_player.dart';

/// Pool of initialised [VideoPlayerController]s keyed by file path.
///
/// A controller is *leased* by one player at a time. Two overlapping clips
/// that use the same file (e.g. a split clip with a crossfade) therefore get
/// two independent controllers instead of fighting over one.
class PlayerPool {
  PlayerPool({this.maxSize = 6});

  final int maxSize;
  final List<_Entry> _entries = []; // least-recently-used first

  PlayerLease acquire(String path) {
    _Entry? entry;
    for (final e in _entries) {
      if (e.path == path && !e.leased) {
        entry = e;
        break;
      }
    }
    if (entry != null) {
      _entries.remove(entry);
    } else {
      entry = _Entry(path, _create(path));
    }
    entry.leased = true;
    _entries.add(entry);
    _evict();
    return PlayerLease._(entry);
  }

  Future<VideoPlayerController> _create(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
    } catch (_) {
      _entries.removeWhere((e) => e.path == path && !e.leased);
      await controller.dispose();
      rethrow;
    }
    return controller;
  }

  void _evict() {
    while (_entries.length > maxSize) {
      final index = _entries.indexWhere((e) => !e.leased);
      if (index < 0) return; // everything is in use
      final victim = _entries.removeAt(index);
      victim.controller.then((c) => c.dispose(), onError: (_) {});
    }
  }

  void dispose() {
    for (final e in _entries) {
      e.controller.then((c) => c.dispose(), onError: (_) {});
    }
    _entries.clear();
  }
}

class _Entry {
  _Entry(this.path, this.controller);

  final String path;
  final Future<VideoPlayerController> controller;
  bool leased = false;
}

class PlayerLease {
  PlayerLease._(this._entry);

  final _Entry _entry;

  Future<VideoPlayerController> get controller => _entry.controller;

  /// Returns the controller to the pool (and pauses it).
  void release() {
    _entry.leased = false;
    _entry.controller.then((c) => c.pause(), onError: (_) {});
  }
}

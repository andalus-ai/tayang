import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies the bundled font to disk once so FFmpeg's `drawtext` can open it.
/// (Android/iOS have no dependable system font path, and FFmpegKit can't read
/// Flutter assets directly.)
class FontProvisioner {
  String? _cached;

  Future<String?> ensureFont() async {
    final cached = _cached;
    if (cached != null && File(cached).existsSync()) return cached;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'fonts', 'DejaVuSans.ttf'));
      if (!await file.exists()) {
        final data = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
        await file.create(recursive: true);
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      return _cached = file.path;
    } catch (_) {
      return null; // exports still work, text clips just fall back to FFmpeg defaults
    }
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Appends unhandled errors to `<documents>/tayang/logs/error.log` (size-capped).
class FileErrorLogger {
  Future<void> log(Object error, StackTrace? stack) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = await Directory(p.join(docs.path, 'tayang', 'logs'))
          .create(recursive: true);
      final file = File(p.join(dir.path, 'error.log'));
      if (await file.exists() && await file.length() > 512 * 1024) {
        await file.delete();
      }
      await file.writeAsString(
        '${DateTime.now().toIso8601String()}\n$error\n$stack\n\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // Logging must never crash the app.
    }
  }
}

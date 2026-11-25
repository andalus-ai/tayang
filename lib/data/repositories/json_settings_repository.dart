import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/settings_repository.dart';

class JsonSettingsRepository implements SettingsRepository {
  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = await Directory(p.join(docs.path, 'tayang')).create(recursive: true);
    return File(p.join(dir.path, 'settings.json'));
  }

  Future<Map<String, dynamic>> _read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<bool> hasSeenWelcome() async => (await _read())['welcomeSeen'] == true;

  @override
  Future<void> markWelcomeSeen() async {
    try {
      final data = await _read();
      data['welcomeSeen'] = true;
      await (await _file()).writeAsString(jsonEncode(data));
    } catch (_) {
      // Not being able to remember this must never break the app.
    }
  }
}

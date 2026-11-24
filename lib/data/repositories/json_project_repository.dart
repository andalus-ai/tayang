import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/project.dart';
import '../../domain/repositories/project_repository.dart';

/// Stores each project as `<id>.json` plus a `latest` pointer file.
class JsonProjectRepository implements ProjectRepository {
  JsonProjectRepository({Future<Directory> Function()? rootProvider})
      : _root = rootProvider ?? _defaultRoot;

  final Future<Directory> Function() _root;

  static Future<Directory> _defaultRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'tayang', 'projects'))
        .create(recursive: true);
  }

  @override
  Future<void> save(Project project) async {
    final root = await _root();
    final target = File(p.join(root.path, '${project.id}.json'));
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(project.toJson()), flush: true);
    await temp.rename(target.path); // atomic replace → no half-written saves
    await File(p.join(root.path, 'latest')).writeAsString(project.id);
  }

  @override
  Future<Project?> loadLatest() async {
    try {
      final root = await _root();
      final pointer = File(p.join(root.path, 'latest'));
      if (!await pointer.exists()) return null;
      final id = (await pointer.readAsString()).trim();
      final file = File(p.join(root.path, '$id.json'));
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return Project.fromJson(json);
    } catch (_) {
      return null; // corrupt / old format → start fresh instead of crashing
    }
  }
}

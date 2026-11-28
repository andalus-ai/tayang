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

  File _projectFile(Directory root, String id) => File(p.join(root.path, '$id.json'));

  Future<Project?> _read(File file) async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return Project.fromJson(json);
    } catch (_) {
      return null; // corrupt / unknown format
    }
  }

  @override
  Future<List<ProjectSummary>> list() async {
    final root = await _root();
    final summaries = <ProjectSummary>[];
    await for (final entity in root.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final project = await _read(entity);
      if (project == null) continue;
      summaries.add(ProjectSummary(
        id: project.id,
        name: project.name,
        modified: (await entity.stat()).modified,
        duration: project.duration,
        clipCount: project.tracks.fold(0, (n, t) => n + t.clips.length),
        assetCount: project.assets.length,
      ));
    }
    summaries.sort((a, b) => b.modified.compareTo(a.modified));
    return summaries;
  }

  @override
  Future<Project?> load(String id) async {
    final root = await _root();
    final project = await _read(_projectFile(root, id));
    if (project != null) {
      await File(p.join(root.path, 'latest')).writeAsString(project.id);
    }
    return project;
  }

  @override
  Future<void> delete(String id) async {
    final root = await _root();
    final file = _projectFile(root, id);
    if (await file.exists()) await file.delete();
    final pointer = File(p.join(root.path, 'latest'));
    if (await pointer.exists() && (await pointer.readAsString()).trim() == id) {
      await pointer.delete();
    }
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

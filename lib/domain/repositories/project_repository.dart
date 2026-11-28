import '../models/project.dart';

/// What the project browser shows for one saved project.
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.modified,
    required this.duration,
    required this.clipCount,
    required this.assetCount,
  });

  final String id;
  final String name;
  final DateTime modified;
  final Duration duration;
  final int clipCount;
  final int assetCount;
}

abstract interface class ProjectRepository {
  Future<void> save(Project project);
  Future<Project?> loadLatest();

  /// All saved projects, most recently modified first.
  Future<List<ProjectSummary>> list();

  /// Loads a project and makes it the one reopened on next start.
  Future<Project?> load(String id);

  Future<void> delete(String id);
}

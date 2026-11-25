import '../models/project.dart';

abstract interface class ProjectRepository {
  Future<void> save(Project project);
  Future<Project?> loadLatest();
}

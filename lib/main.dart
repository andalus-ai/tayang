import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/di.dart';
import 'data/repositories/json_project_repository.dart';
import 'domain/models/project.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = JsonProjectRepository();
  final initial = await repository.loadLatest() ?? Project.empty();

  runApp(
    ProviderScope(
      overrides: [
        initialProjectProvider.overrideWithValue(initial),
        projectRepositoryProvider.overrideWithValue(repository),
      ],
      child: const TayangApp(),
    ),
  );
}

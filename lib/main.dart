import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/di.dart';
import 'data/logging/file_error_logger.dart';
import 'data/repositories/json_project_repository.dart';
import 'data/repositories/json_settings_repository.dart';
import 'domain/models/project.dart';

Future<void> main() async {
  final logger = FileErrorLogger();

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      logger.log(details.exception, details.stack);
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      logger.log(error, stack);
      return true;
    };

    final repository = JsonProjectRepository();
    final initial = await repository.loadLatest() ?? Project.empty();
    final settings = JsonSettingsRepository();
    final welcomeSeen = await settings.hasSeenWelcome();

    runApp(
      ProviderScope(
        overrides: [
          initialProjectProvider.overrideWithValue(initial),
          projectRepositoryProvider.overrideWithValue(repository),
          settingsRepositoryProvider.overrideWithValue(settings),
          initialWelcomeSeenProvider.overrideWithValue(welcomeSeen),
        ],
        child: const TayangApp(),
      ),
    );
  }, logger.log);
}

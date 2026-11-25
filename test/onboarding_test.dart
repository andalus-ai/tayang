import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/app.dart';
import 'package:tayang/domain/services/engine_check.dart';

import 'support/fakes.dart';

Future<void> _bigScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('first run shows the welcome dialog and remembers dismissal', (tester) async {
    await _bigScreen(tester);
    final settings = FakeSettings();

    await tester.pumpWidget(ProviderScope(
      overrides: fakeOverrides(welcomeSeen: false, settings: settings),
      child: const TayangApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Tayang'), findsOneWidget);
    expect(settings.seen, isFalse);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Tayang'), findsNothing);
    expect(settings.seen, isTrue);
  });

  testWidgets('returning users see no welcome dialog', (tester) async {
    await _bigScreen(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: fakeOverrides(), child: const TayangApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Tayang'), findsNothing);
  });

  testWidgets('help button opens the shortcut list', (tester) async {
    await _bigScreen(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: fakeOverrides(), child: const TayangApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Help & shortcuts'));
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Split at playhead'), findsOneWidget);
  });

  testWidgets('missing FFmpeg shows a dismissible banner', (tester) async {
    await _bigScreen(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: fakeOverrides(
        engine: const EngineStatus.missing('FFmpeg tools not found (ffmpeg).'),
      ),
      child: const TayangApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('FFmpeg tools not found'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.textContaining('FFmpeg tools not found'), findsNothing);
  });
}

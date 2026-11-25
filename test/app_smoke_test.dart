import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/app.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('add a text clip, then undo it', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(overrides: fakeOverrides(), child: const TayangApp()),
    );
    await tester.pump();

    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.text('Your text'), findsNothing);

    await tester.tap(find.byTooltip('Add text at playhead'));
    await tester.pump();
    expect(find.text('Your text'), findsWidgets);

    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pump();
    expect(find.text('Your text'), findsNothing);

    // Let the autosave debounce timer finish.
    await tester.pump(const Duration(seconds: 3));
  });
}

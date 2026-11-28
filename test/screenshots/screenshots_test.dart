@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/app.dart';
import 'package:tayang/application/di.dart';
import 'package:tayang/application/playback_controller.dart';
import 'package:tayang/application/selection_controller.dart';
import 'package:tayang/domain/models/keyframes.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';
import 'package:tayang/presentation/pages/editor_page.dart';

import '../support/fakes.dart';

/// Renders the real UI with a demo project to docs/screenshots/*.png.
/// Run with: flutter test --tags screenshots --update-goldens test/screenshots
Future<void> _loadFonts() async {
  // Real glyphs instead of the test font's boxes.
  final text = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  await text.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
  }
}

/// A soft two-colour gradient picture, written as a PNG.
Future<String> _picture(Directory dir, String name, Color a, Color b) async {
  const w = 1280.0, h = 720.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(w, h),
        [a, b],
      ),
  );
  canvas.drawCircle(
    const Offset(w * 0.72, h * 0.3),
    90,
    Paint()..color = Colors.white.withAlpha(200),
  );
  canvas.drawPath(
    Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.35, h * 0.55, w * 0.7, h * 0.8)
      ..quadraticBezierTo(w * 0.9, h * 0.9, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close(),
    Paint()..color = Colors.black.withAlpha(70),
  );
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('${dir.path}/$name.png')..writeAsBytesSync(data!.buffer.asUint8List());
  return file.path;
}

Project _demo(Map<String, String> pics) {
  const editor = TimelineEditor();
  MediaAsset image(String id, String name) => MediaAsset(
        id: id, path: pics[id]!, name: name, kind: MediaKind.image, hasAudio: false);
  final lisbon = image('lisbon', 'Lisbon.jpg');
  final sintra = image('sintra', 'Sintra.jpg');
  final coast = image('coast', 'Coast.jpg');
  final logo = image('logo', 'Logo.png');
  const drone = MediaAsset(
    id: 'drone', path: '/demo/Drone.mp4', name: 'Drone.mp4',
    kind: MediaKind.video, duration: Duration(seconds: 9),
  );
  const music = MediaAsset(
    id: 'music', path: '/demo/Soundtrack.mp3', name: 'Soundtrack.mp3',
    kind: MediaKind.audio, duration: Duration(seconds: 30),
  );

  var p = Project(
    id: 'demo',
    name: 'Summer in Lisbon',
    assets: [lisbon, sintra, coast, drone, logo, music],
    tracks: const [
      Track(id: 'txt', kind: TrackKind.text, name: 'Titles'),
      Track(id: 'v2', kind: TrackKind.video, name: 'Overlay'),
      Track(id: 'v1', kind: TrackKind.video, name: 'Main'),
      Track(id: 'a1', kind: TrackKind.audio, name: 'Music'),
    ],
  );
  p = editor.addClipFromAsset(p, lisbon, clipId: 'lisbon', newTrackId: 'x', trackId: 'v1');
  p = editor.addClipFromAsset(p, sintra, clipId: 'sintra', newTrackId: 'x', trackId: 'v1');
  p = editor.addClipFromAsset(p, coast, clipId: 'coast', newTrackId: 'x', trackId: 'v1');
  p = editor.addClipFromAsset(p, drone, clipId: 'drone', newTrackId: 'x', trackId: 'v1');
  p = editor.addCrossfade(p, 'lisbon', const Duration(seconds: 1));
  p = editor.addCrossfade(p, 'sintra', const Duration(seconds: 1));
  p = editor.addClipFromAsset(p, logo, clipId: 'logo', newTrackId: 'x',
      trackId: 'v2', at: const Duration(seconds: 1));
  p = editor.trimClipEnd(p, 'logo', const Duration(seconds: 7));
  p = editor.updateClip(p, 'logo', (c) => c.copyWith(scale: 0.22, offsetX: 0.36, offsetY: -0.34));
  p = editor.addClipFromAsset(p, music, clipId: 'music', newTrackId: 'x',
      trackId: 'a1', at: Duration.zero);
  p = editor.addTextClip(p, clipId: 'title', newTrackId: 'x', at: const Duration(seconds: 1));
  p = editor.updateClip(p, 'title', (c) => c.copyWith(
      text: c.text!.copyWith(content: 'Summer in Lisbon', fontSize: 110, y: 0.82)));
  // Keyframes so the inspector shows them.
  p = editor.setKeyframe(p, 'lisbon', KeyframeProperty.opacity, Duration.zero, 0.0);
  p = editor.setKeyframe(p, 'lisbon', KeyframeProperty.opacity, const Duration(seconds: 2), 1.0);
  return p;
}

Future<ProviderContainer> _launch(WidgetTester tester, Project project, Size size,
    {double pixelRatio = 1.0}) async {
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [...fakeOverrides(), initialProjectProvider.overrideWithValue(project)],
    child: const TayangApp(),
  ));
  await tester.pumpAndSettle();
  // Decode the pictures (real file IO needs real async).
  final context = tester.element(find.byType(EditorPage));
  await tester.runAsync(() async {
    for (final a in project.assets.where((a) => a.kind == MediaKind.image)) {
      await precacheImage(FileImage(File(a.path)), context);
    }
  });
  final container = ProviderScope.containerOf(context);
  container.read(playbackProvider.notifier).seek(const Duration(milliseconds: 2500));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  late Project demo;

  setUpAll(() async {
    await _loadFonts();
    final dir = await Directory.systemTemp.createTemp('tayang_shots_');
    final pics = {
      'lisbon': await _picture(dir, 'lisbon', const Color(0xFFFF8A5B), const Color(0xFF3E6BD6)),
      'sintra': await _picture(dir, 'sintra', const Color(0xFF2E9E78), const Color(0xFF1B2A41)),
      'coast': await _picture(dir, 'coast', const Color(0xFF6BD6FF), const Color(0xFF8A5BD1)),
      'logo': await _picture(dir, 'logo', const Color(0xFFFFD84D), const Color(0xFFFF5C6C)),
    };
    demo = _demo(pics);
  });

  const desktop = Size(1600, 1000);

  testWidgets('editor overview', (tester) async {
    final c = await _launch(tester, demo, desktop);
    c.read(selectionProvider.notifier).select('lisbon');
    await tester.pumpAndSettle();
    await expectLater(find.byType(TayangApp),
        matchesGoldenFile('../../docs/screenshots/editor.png'));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('export dialog', (tester) async {
    await _launch(tester, demo, desktop);
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(TayangApp),
        matchesGoldenFile('../../docs/screenshots/export.png'));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('welcome and shortcuts', (tester) async {
    await _launch(tester, demo, desktop);
    await tester.tap(find.byTooltip('Help & shortcuts'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(TayangApp),
        matchesGoldenFile('../../docs/screenshots/help.png'));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('phone layout', (tester) async {
    await _launch(tester, demo, const Size(412, 860), pixelRatio: 2.0);
    await expectLater(find.byType(TayangApp),
        matchesGoldenFile('../../docs/screenshots/mobile.png'));
    await tester.pump(const Duration(seconds: 3));
  });
}

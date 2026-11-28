@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

/// A two-colour gradient picture with a sun and a hill, written as a 24-bit BMP in
/// plain Dart (no GPU/raster dependency, so it can't stall a headless test).
String _picture(Directory dir, String name, int rgbA, int rgbB) {
  const w = 1280, h = 720;
  final data = ByteData(54 + w * h * 3);
  data
    ..setUint8(0, 0x42)
    ..setUint8(1, 0x4D)
    ..setUint32(2, 54 + w * h * 3, Endian.little)
    ..setUint32(10, 54, Endian.little)
    ..setUint32(14, 40, Endian.little)
    ..setInt32(18, w, Endian.little)
    ..setInt32(22, h, Endian.little) // positive height: rows stored bottom-up
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 24, Endian.little)
    ..setUint32(34, w * h * 3, Endian.little);

  int channel(int rgb, int shift) => (rgb >> shift) & 0xFF;
  var offset = 54;
  for (var row = 0; row < h; row++) {
    final y = h - 1 - row;
    for (var x = 0; x < w; x++) {
      final t = x / w * 0.5 + y / h * 0.5;
      final c = [
        for (final shift in [16, 8, 0])
          channel(rgbA, shift) + (channel(rgbB, shift) - channel(rgbA, shift)) * t,
      ];
      final sun = (x - w * 0.72) * (x - w * 0.72) + (y - h * 0.3) * (y - h * 0.3) < 90 * 90;
      final hill = y > h * 0.76 + math.sin(x / w * math.pi * 2) * h * 0.05;
      for (var i = 0; i < 3; i++) {
        var v = c[i];
        if (sun) v = v * 0.2 + 255 * 0.8;
        if (hill) v *= 0.62;
        c[i] = v;
      }
      data
        ..setUint8(offset++, c[2].round().clamp(0, 255)) // B
        ..setUint8(offset++, c[1].round().clamp(0, 255)) // G
        ..setUint8(offset++, c[0].round().clamp(0, 255)); // R
    }
  }
  final file = File('${dir.path}/$name.bmp')..writeAsBytesSync(data.buffer.asUint8List());
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
  debugPrint('STEP launch: pumpWidget');
  await tester.pumpWidget(ProviderScope(
    overrides: [...fakeOverrides(), initialProjectProvider.overrideWithValue(project)],
    child: const TayangApp(),
  ));
  await tester.pumpAndSettle();
  debugPrint('STEP launch: settled, precaching');
  final context = tester.element(find.byType(EditorPage));
  await tester.runAsync(() async {
    for (final a in project.assets.where((a) => a.kind == MediaKind.image)) {
      debugPrint('STEP precache ${a.name}');
      await precacheImage(FileImage(File(a.path)), context)
          .timeout(const Duration(seconds: 30), onTimeout: () => fail('decoding ${a.name} stalled'));
    }
  });
  debugPrint('STEP launch: precached');
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
      'lisbon': _picture(dir, 'lisbon', 0xFF8A5B, 0x3E6BD6),
      'sintra': _picture(dir, 'sintra', 0x2E9E78, 0x1B2A41),
      'coast': _picture(dir, 'coast', 0x6BD6FF, 0x8A5BD1),
      'logo': _picture(dir, 'logo', 0xFFD84D, 0xFF5C6C),
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
    debugPrint('STEP export: tapping');
    await tester.tap(find.text('Export'));
    debugPrint('STEP export: tapped, settling');
    await tester.pumpAndSettle();
    debugPrint('STEP export: settled');
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

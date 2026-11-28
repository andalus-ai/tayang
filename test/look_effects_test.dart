import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/data/export/ffmpeg_command_builder.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/clip.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';
import 'package:tayang/presentation/widgets/preview/clip_effects.dart';

void main() {
  const editor = TimelineEditor();
  const asset = MediaAsset(
    id: 'a', path: '/tmp/a.mp4', name: 'a.mp4',
    kind: MediaKind.video, duration: Duration(seconds: 4),
  );
  Project withClip(TimelineClip Function(TimelineClip) change) {
    final p = editor.addClipFromAsset(
      const Project(
        id: 'p', name: 'p', assets: [asset],
        tracks: [Track(id: 'v', kind: TrackKind.video, name: 'V')],
      ),
      asset, clipId: 'c', newTrackId: 't',
    );
    return editor.updateClip(p, 'c', change);
  }

  String graph(Project p) => const FfmpegCommandBuilder()
      .build(p, const ExportSettings(), outputPath: 'o.mp4')
      .join(' ');

  group('model', () {
    test('defaults are neutral', () {
      final c = withClip((c) => c).clipById('c')!;
      expect(c.hasLook, isFalse);
      expect(c.hasGeometry, isFalse);
    });

    test('survives a JSON round trip', () {
      final c = withClip((c) => c.copyWith(
            brightness: 0.2, contrast: 1.4, saturation: 0.5,
            rotation: 3, flipH: true, flipV: true,
          )).clipById('c')!;
      final back = TimelineClip.fromJson(c.toJson());
      expect(back, c);
      expect(back.rotation, 3);
      expect(back.flipV, isTrue);
      expect(back.hasLook && back.hasGeometry, isTrue);
    });

    test('projects saved before these fields existed still load with neutral values', () {
      final json = withClip((c) => c).clipById('c')!.toJson()
        ..remove('brightness')
        ..remove('contrast')
        ..remove('saturation')
        ..remove('rotation')
        ..remove('flipH')
        ..remove('flipV');
      final c = TimelineClip.fromJson(json);
      expect((c.brightness, c.contrast, c.saturation, c.rotation, c.flipH, c.flipV),
          (0.0, 1.0, 1.0, 0, false, false));
    });

    test('equality notices every new field', () {
      final base = withClip((c) => c).clipById('c')!;
      expect(base.copyWith(brightness: 0.1), isNot(base));
      expect(base.copyWith(rotation: 1), isNot(base));
      expect(base.copyWith(flipH: true), isNot(base));
      expect(base.copyWith(saturation: 0.0).hashCode, isNot(base.hashCode));
    });
  });

  group('export graph', () {
    test('neutral clips add no extra filters', () {
      final g = graph(withClip((c) => c));
      expect(g, isNot(contains('eq=')));
      expect(g, isNot(contains('transpose')));
      expect(g, isNot(contains('hflip')));
    });

    test('colour adjustments use eq with the clip values', () {
      final g = graph(withClip((c) => c.copyWith(brightness: 0.2, contrast: 1.5, saturation: 0.0)));
      expect(g, contains('eq=brightness=0.200:contrast=1.500:saturation=0.000'));
    });

    test('rotation maps to transpose / flips and happens BEFORE the fit scale', () {
      String filters(int rotation) => graph(withClip((c) => c.copyWith(rotation: rotation)));
      expect(filters(1), contains('transpose=1'));
      expect(filters(3), contains('transpose=2'));
      expect(filters(2), contains('hflip,vflip'));
      final g = filters(1);
      expect(g.indexOf('transpose=1'), lessThan(g.indexOf('force_original_aspect_ratio')),
          reason: 'the fit must use the rotated size');
    });

    test('mirroring adds hflip / vflip after the rotation', () {
      final g = graph(withClip((c) => c.copyWith(rotation: 1, flipH: true, flipV: true)));
      expect(g, contains('transpose=1,hflip,vflip'));
    });
  });

  group('preview colour matrix', () {
    TimelineClip clip({double b = 0, double c = 1, double s = 1}) =>
        withClip((k) => k.copyWith(brightness: b, contrast: c, saturation: s)).clipById('c')!;

    test('neutral settings give the identity matrix', () {
      final m = lookMatrix(clip());
      for (var i = 0; i < 20; i++) {
        final expected = const [
          1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0,
        ][i];
        expect(m[i], closeTo(expected, 1e-9), reason: 'entry $i');
      }
    });

    test('zero saturation makes all three colour rows identical (greyscale)', () {
      final m = lookMatrix(clip(s: 0));
      for (var col = 0; col < 3; col++) {
        expect(m[5 + col], closeTo(m[col], 1e-9));
        expect(m[10 + col], closeTo(m[col], 1e-9));
      }
    });

    test('brightness shifts the offset; contrast scales around mid-grey', () {
      expect(lookMatrix(clip(b: 0.2))[4], closeTo(51, 1e-6));
      final m = lookMatrix(clip(c: 2));
      expect(m[0], closeTo(2, 1e-9));
      expect(m[4], closeTo(-127.5, 1e-6)); // 0.5 * (1 - 2) * 255
    });
  });
}

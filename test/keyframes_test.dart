import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/data/export/ffmpeg_command_builder.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/clip.dart';
import 'package:tayang/domain/models/keyframes.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

void main() {
  const editor = TimelineEditor();
  const asset = MediaAsset(
    id: 'a', path: '/tmp/a.mp4', name: 'a.mp4',
    kind: MediaKind.video, duration: Duration(seconds: 10),
  );
  const base = Project(
    id: 'p', name: 'p', assets: [asset],
    tracks: [Track(id: 'v', kind: TrackKind.video, name: 'V')],
  );
  Project one() => editor.addClipFromAsset(base, asset, clipId: 'c', newTrackId: 't');

  test('keyframes interpolate linearly and hold at the ends', () {
    final k = const Keyframes()
        .set(const Duration(seconds: 2), 0.0)
        .set(const Duration(seconds: 4), 1.0);
    expect(k.valueAt(const Duration(seconds: 1), 0.5), 0.0);
    expect(k.valueAt(const Duration(seconds: 3), 0.5), closeTo(0.5, 1e-9));
    expect(k.valueAt(const Duration(seconds: 9), 0.5), 1.0);
  });

  test('setKeyframe ignores playhead outside the clip', () {
    final p = editor.setKeyframe(one(), 'c', KeyframeProperty.opacity,
        const Duration(seconds: 30), 0.5);
    expect(p.clipById('c')!.opacityKeys.isEmpty, isTrue);
  });

  test('split preserves the keyframe curve on both halves', () {
    var p = editor.setKeyframe(one(), 'c', KeyframeProperty.opacity, Duration.zero, 0.0);
    p = editor.setKeyframe(p, 'c', KeyframeProperty.opacity, const Duration(seconds: 10), 1.0);
    p = editor.splitClip(p, 'c', const Duration(seconds: 5), rightClipId: 'd');
    expect(p.clipById('c')!.opacityKeys.valueAt(const Duration(seconds: 5), 0), closeTo(0.5, 1e-6));
    expect(p.clipById('d')!.opacityKeys.valueAt(Duration.zero, 0), closeTo(0.5, 1e-6));
    expect(p.clipById('d')!.opacityKeys.valueAt(const Duration(seconds: 5), 0), closeTo(1.0, 1e-6));
  });

  test('dip transition fades both neighbours', () {
    var p = editor.splitClip(one(), 'c', const Duration(seconds: 5), rightClipId: 'd');
    p = editor.addTransition(p, 'c', const Duration(milliseconds: 500));
    expect(p.clipById('c')!.fadeOut, const Duration(milliseconds: 500));
    expect(p.clipById('d')!.fadeIn, const Duration(milliseconds: 500));
  });

  test('paste inserts a copy without overlapping', () {
    final p = editor.insertClip(one(), one().clipById('c')!,
        newClipId: 'n', newTrackId: 't2', at: Duration.zero);
    expect(p.clipById('n')!.start, const Duration(seconds: 10));
  });

  test('export graph includes keyframes and transform', () {
    var p = editor.setKeyframe(one(), 'c', KeyframeProperty.opacity, Duration.zero, 0.0);
    p = editor.setKeyframe(p, 'c', KeyframeProperty.volume, Duration.zero, 1.0);
    p = editor.updateClip(p, 'c', (c) => c.copyWith(scale: 1.5, offsetX: 0.1));
    final cmd = const FfmpegCommandBuilder()
        .build(p, const ExportSettings(), outputPath: 'o.mp4')
        .join(' ');
    expect(cmd, contains('geq='));
    expect(cmd, contains("volume='"));
    expect(cmd, contains('main_w'));
  });
}

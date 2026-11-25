import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/data/export/ffmpeg_command_builder.dart';
import 'package:tayang/domain/export/video_exporter.dart';
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

  /// Two clips: c = 0–5s, d = 5–10s.
  Project two() {
    var p = const Project(
      id: 'p', name: 'p', assets: [asset],
      tracks: [Track(id: 'v', kind: TrackKind.video, name: 'V')],
    );
    p = editor.addClipFromAsset(p, asset, clipId: 'c', newTrackId: 't');
    return editor.splitClip(p, 'c', const Duration(seconds: 5), rightClipId: 'd');
  }

  test('crossfade overlaps the clips and shortens the project', () {
    final p = editor.addCrossfade(two(), 'c', const Duration(seconds: 1));
    expect(p.clipById('d')!.start, const Duration(seconds: 4));
    expect(p.clipById('d')!.fadeIn, const Duration(seconds: 1));
    expect(p.duration, const Duration(seconds: 9));
    expect(p.hasCrossfadeIn('d'), isTrue);
    expect(p.crossfadeOutOf(p.clipById('c')!), const Duration(seconds: 1));
  });

  test('removing the crossfade restores the original layout', () {
    var p = editor.addCrossfade(two(), 'c', const Duration(seconds: 1));
    p = editor.removeCrossfade(p, 'd');
    expect(p.clipById('d')!.start, const Duration(seconds: 5));
    expect(p.clipById('d')!.fadeIn, Duration.zero);
    expect(p.hasCrossfadeIn('d'), isFalse);
    expect(p.duration, const Duration(seconds: 10));
  });

  test('crossfade length is capped at half the shorter clip', () {
    final p = editor.addCrossfade(two(), 'c', const Duration(seconds: 10));
    expect(p.clipById('d')!.fadeIn, const Duration(milliseconds: 2500));
  });

  test('crossfade is ignored when the clips are not adjacent', () {
    final p = editor.moveClip(two(), 'd', const Duration(seconds: 8));
    final same = editor.addCrossfade(p, 'c', const Duration(seconds: 1));
    expect(identical(same, p), isTrue);
  });

  test('export fades the outgoing clip audio over the overlap', () {
    final p = editor.addCrossfade(two(), 'c', const Duration(seconds: 1));
    final cmd = const FfmpegCommandBuilder()
        .build(p, const ExportSettings(), outputPath: 'o.mp4')
        .join(' ');
    expect(cmd, contains('afade=t=out:st=4.000:d=1.000')); // c: 5s - 1s overlap
    expect(cmd, contains('afade=t=in:st=0:d=1.000')); // d fades in
  });

  test('preview helpers report no crossfade without overlap', () {
    final p = two();
    expect(p.hasCrossfadeIn('d'), isFalse);
    expect(p.crossfadeOutOf(p.clipById('c')!), Duration.zero);
  });
}

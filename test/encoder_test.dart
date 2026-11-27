import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/data/export/encoder_planner.dart';
import 'package:tayang/data/export/ffmpeg_command_builder.dart';
import 'package:tayang/domain/export/video_encoder.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

void main() {
  const editor = TimelineEditor();
  const asset = MediaAsset(
    id: 'a', path: '/tmp/a.mp4', name: 'a.mp4',
    kind: MediaKind.video, duration: Duration(seconds: 4),
  );
  final project = editor.addClipFromAsset(
    const Project(
      id: 'p', name: 'p', assets: [asset],
      tracks: [Track(id: 'v', kind: TrackKind.video, name: 'V')],
    ),
    asset, clipId: 'c', newTrackId: 't',
  );

  group('EncoderPlanner', () {
    List<VideoEncoder> plan(String os, {bool hw = true}) =>
        EncoderPlanner(os).candidates(hardware: hw);

    test('Apple platforms try VideoToolbox then software', () {
      expect(plan('macos'), [VideoEncoder.videoToolbox, VideoEncoder.software]);
      expect(plan('ios'), [VideoEncoder.videoToolbox, VideoEncoder.software]);
    });

    test('Android tries MediaCodec then software', () {
      expect(plan('android'), [VideoEncoder.mediaCodec, VideoEncoder.software]);
    });

    test('Windows tries NVENC, Quick Sync, AMF then software', () {
      expect(plan('windows'), [
        VideoEncoder.nvenc,
        VideoEncoder.quickSync,
        VideoEncoder.amf,
        VideoEncoder.software,
      ]);
    });

    test('Linux and unknown platforms use software only', () {
      expect(plan('linux'), [VideoEncoder.software]);
      expect(plan('fuchsia'), [VideoEncoder.software]);
    });

    test('hardware off always means software only', () {
      for (final os in ['macos', 'ios', 'android', 'windows', 'linux']) {
        expect(plan(os, hw: false), [VideoEncoder.software], reason: os);
      }
    });

    test('software is always the last resort', () {
      for (final os in ['macos', 'ios', 'android', 'windows', 'linux']) {
        expect(plan(os).last, VideoEncoder.software, reason: os);
      }
    });
  });

  group('encoder arguments', () {
    String cmd(VideoEncoder e) => const FfmpegCommandBuilder()
        .build(project, const ExportSettings(), outputPath: 'o.mp4', encoder: e)
        .join(' ');

    test('software uses x264 with constant quality', () {
      final c = cmd(VideoEncoder.software);
      expect(c, contains('-c:v libx264'));
      expect(c, contains('-crf 23'));
      expect(c, isNot(contains('-b:v')));
    });

    test('hardware encoders are bitrate driven (no CRF / x264 preset)', () {
      for (final e in VideoEncoder.values.where((e) => e.isHardware)) {
        final c = cmd(e);
        expect(c, contains('-c:v ${e.ffmpegName}'), reason: e.name);
        expect(c, contains('-b:v'), reason: e.name);
        expect(c, isNot(contains('-crf')), reason: e.name);
        expect(c, isNot(contains('libx264')), reason: e.name);
      }
    });

    test('default builder encoder stays software', () {
      final c = const FfmpegCommandBuilder()
          .build(project, const ExportSettings(), outputPath: 'o.mp4')
          .join(' ');
      expect(c, contains('libx264'));
    });
  });

  group('bitrate', () {
    test('grows with quality and resolution, within sane limits', () {
      int br(ExportSettings s) => s.bitrateFor(project);
      expect(br(const ExportSettings(quality: ExportQuality.draft)),
          lessThan(br(const ExportSettings(quality: ExportQuality.standard))));
      expect(br(const ExportSettings(quality: ExportQuality.standard)),
          lessThan(br(const ExportSettings(quality: ExportQuality.high))));
      expect(br(const ExportSettings(height: 2160)),
          greaterThan(br(const ExportSettings(height: 1080))));
      // 1080p30 standard ≈ 3.7 Mbit/s
      expect(br(const ExportSettings()), inInclusiveRange(3000000, 5000000));
      expect(br(const ExportSettings(height: 144, fps: 24, quality: ExportQuality.draft)),
          greaterThanOrEqualTo(500000));
    });
  });
}

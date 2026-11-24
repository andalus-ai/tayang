import '../../domain/export/video_exporter.dart';
import '../../domain/models/clip.dart';
import '../../domain/models/media_asset.dart';
import '../../domain/models/project.dart';
import '../../domain/models/track.dart';

/// Pure translation of a [Project] into FFmpeg arguments (no I/O → unit-testable).
///
/// Strategy: one `-i` per clip (input-seeked with `-ss/-t`), a black canvas, and
/// each visual clip is time-shifted with `setpts` then overlaid bottom → top.
/// Audio clips are delayed with `adelay` and mixed with `amix`.
class FfmpegCommandBuilder {
  const FfmpegCommandBuilder({this.fontFile});

  /// Absolute path to a .ttf, required by `drawtext` on some platforms.
  final String? fontFile;

  List<String> build(
    Project project,
    ExportSettings settings, {
    required String outputPath,
  }) {
    final w = settings.widthFor(project);
    final h = settings.height;
    final fps = settings.fps;
    final total = project.duration;

    final inputs = <String>[];
    final filters = <String>['color=c=black:s=${w}x$h:r=$fps:d=${_s(total)}[base]'];
    final audioLabels = <String>[];
    var last = 'base';
    var inputCount = 0;
    var step = 0;

    for (final track in project.tracks.reversed) {
      for (final clip in track.clips) {
        if (clip.kind == ClipKind.text) {
          final text = clip.text;
          if (!track.isVisible || text == null) continue;
          final fontSize = (text.fontSize * h / project.height).round();
          final rgb = (text.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
          final font = fontFile == null ? '' : ":fontfile='${_escapePath(fontFile!)}'";
          final next = 'o${step++}';
          filters.add(
            "[$last]drawtext=text='${_escapeText(text.content)}'"
            ':fontsize=$fontSize'
            ':fontcolor=0x$rgb@${_n(clip.opacity)}'
            '$font'
            ':x=w*${_n(text.x)}-text_w/2'
            ':y=h*${_n(text.y)}-text_h/2'
            ":enable='between(t,${_s(clip.start)},${_s(clip.end)})'[$next]",
          );
          last = next;
          continue;
        }

        final asset = project.assetById(clip.assetId);
        if (asset == null) continue;

        final wantsVideo = clip.kind != ClipKind.audio && track.isVisible;
        final wantsAudio = clip.kind != ClipKind.image &&
            track.hasAudio &&
            !track.isMuted &&
            asset.hasAudio;
        if (!wantsVideo && !wantsAudio) continue;

        final index = inputCount++;
        inputs.addAll(_inputArgs(clip, asset));

        if (wantsVideo) {
          final chain = <String>[
            'setpts=(PTS-STARTPTS)/${_n(clip.speed)}+${_s(clip.start)}/TB',
            'scale=$w:$h:force_original_aspect_ratio=decrease',
            'format=rgba',
            'pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black@0',
            if (clip.opacity < 0.999) 'colorchannelmixer=aa=${_n(clip.opacity)}',
          ];
          final layer = 'v$index';
          final next = 'o${step++}';
          filters
            ..add('[$index:v]${chain.join(',')}[$layer]')
            ..add('[$last][$layer]overlay=eof_action=pass:format=auto[$next]');
          last = next;
        }

        if (wantsAudio) {
          final chain = <String>[
            'aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo',
            'asetpts=PTS-STARTPTS',
            ..._atempo(clip.speed),
            'volume=${_n(clip.volume)}',
            'adelay=${clip.start.inMilliseconds}:all=1',
          ];
          filters.add('[$index:a]${chain.join(',')}[a$index]');
          audioLabels.add('[a$index]');
        }
      }
    }

    final hasAudio = audioLabels.isNotEmpty;
    if (hasAudio) {
      filters.add(
        '${audioLabels.join()}amix=inputs=${audioLabels.length}:normalize=0[aout]',
      );
    }

    return [
      '-y',
      ...inputs,
      '-filter_complex', filters.join(';'),
      '-map', '[$last]',
      if (hasAudio) ...['-map', '[aout]'],
      '-c:v', 'libx264',
      '-preset', settings.quality.preset,
      '-crf', '${settings.quality.crf}',
      '-pix_fmt', 'yuv420p',
      '-r', '$fps',
      if (hasAudio) ...['-c:a', 'aac', '-b:a', '192k'] else '-an',
      '-t', _s(total),
      '-movflags', '+faststart',
      outputPath,
    ];
  }

  List<String> _inputArgs(TimelineClip clip, MediaAsset asset) {
    if (clip.kind == ClipKind.image) {
      return ['-loop', '1', '-t', _s(clip.duration), '-i', asset.path];
    }
    return [
      '-ss', _s(clip.sourceStart),
      '-t', _s(clip.sourceDuration),
      '-i', asset.path,
    ];
  }

  /// `atempo` only accepts 0.5–2.0, so chain it for extreme speeds.
  List<String> _atempo(double speed) {
    if ((speed - 1).abs() < 0.001) return const [];
    final out = <String>[];
    var rest = speed;
    while (rest > 2.0) {
      out.add('atempo=2.0');
      rest /= 2.0;
    }
    while (rest < 0.5) {
      out.add('atempo=0.5');
      rest /= 0.5;
    }
    out.add('atempo=${_n(rest)}');
    return out;
  }

  String _s(Duration d) => (d.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3);
  String _n(double v) => v.toStringAsFixed(3);

  /// Escapes for a single-quoted drawtext value inside a filtergraph.
  String _escapeText(String t) => t
      .replaceAll(r'\', r'\\')
      .replaceAll("'", '\u2019')
      .replaceAll(':', r'\:')
      .replaceAll('%', r'\%');

  String _escapePath(String path) =>
      path.replaceAll(r'\', '/').replaceAll(':', r'\:');
}

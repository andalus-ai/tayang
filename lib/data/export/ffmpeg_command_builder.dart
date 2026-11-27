import 'dart:math' as math;

import '../../core/utils/duration_x.dart';
import '../../domain/export/video_encoder.dart';
import '../../domain/export/video_exporter.dart';
import '../../domain/models/clip.dart';
import '../../domain/models/keyframes.dart';
import '../../domain/models/media_asset.dart';
import '../../domain/models/project.dart';

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
    VideoEncoder encoder = VideoEncoder.software,
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
          final keyed = clip.opacityKeys.isNotEmpty;
          // The picture is fitted into a box of canvas size x clip.scale in ONE
          // cheap YUV scale. (Zooming later on RGBA frames was the slowest step:
          // it doubled export time.)
          final boxW = math.max(2, (w * clip.scale / 2).floor() * 2);
          final boxH = math.max(2, (h * clip.scale / 2).floor() * 2);
          final pre = <String>[
            'setpts=(PTS-STARTPTS)/${_n(clip.speed)}+${_s(clip.start)}/TB',
            'scale=$boxW:$boxH:force_original_aspect_ratio=decrease',
            'format=rgba',
            // Only the animated-opacity mask needs a frame of exactly box size.
            if (keyed) 'pad=$boxW:$boxH:(ow-iw)/2:(oh-ih)/2:color=black@0',
          ];
          final post = <String>[
            if (clip.fadeIn > Duration.zero)
              'fade=t=in:st=${_s(clip.start)}:d=${_s(clip.fadeIn)}:alpha=1',
            if (clip.fadeOut > Duration.zero)
              'fade=t=out:st=${_s(clip.end - clip.fadeOut)}:d=${_s(clip.fadeOut)}:alpha=1',
            if (!keyed && clip.opacity < 0.999)
              'colorchannelmixer=aa=${_n(clip.opacity)}',
          ];
          final layer = 'v$index';
          // Always centred explicitly (frames are no longer padded to canvas size).
          final position = ':x=(main_w-overlay_w)/2+${_n(clip.offsetX)}*main_w'
              ':y=(main_h-overlay_h)/2+${_n(clip.offsetY)}*main_h';
          final next = 'o${step++}';

          if (keyed) {
            // Animated opacity: a tiny 2x2 gray mask whose brightness follows the
            // keyframes is scaled up and merged in as the alpha channel. This is
            // ~8x faster than a per-pixel `geq` on the picture itself.
            final mask = _lerp(clip.opacityKeys, Duration.zero, 'T');
            final tail = post.isEmpty ? '' : ',${post.join(',')}';
            filters
              ..add('[$index:v]${pre.join(',')},split[va$index][vb$index]')
              ..add('[va$index]alphaextract[al$index]')
              ..add(
                'color=c=white:s=2x2:r=$fps:d=${_s(clip.duration)},format=gray,'
                "geq=lum='clip(255*($mask),0,255)',"
                'scale=$boxW:$boxH:flags=neighbor,setpts=PTS+${_s(clip.start)}/TB[m$index]',
              )
              ..add('[al$index][m$index]blend=all_mode=multiply[am$index]')
              ..add('[vb$index][am$index]alphamerge$tail[$layer]');
          } else {
            filters.add('[$index:v]${[...pre, ...post].join(',')}[$layer]');
          }
          filters.add('[$last][$layer]overlay=eof_action=pass:format=auto$position[$next]');
          last = next;
        }

        if (wantsAudio) {
          // A clip crossfading into the next one also fades its audio out.
          final audioFadeOut = maxDuration(clip.fadeOut, project.crossfadeOutOf(clip));
          final chain = <String>[
            'aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo',
            'asetpts=PTS-STARTPTS',
            ..._atempo(clip.speed),
            if (clip.fadeIn > Duration.zero) 'afade=t=in:st=0:d=${_s(clip.fadeIn)}',
            if (audioFadeOut > Duration.zero)
              'afade=t=out:st=${_s(clip.duration - audioFadeOut)}:d=${_s(audioFadeOut)}',
            if (clip.volumeKeys.isNotEmpty)
              "volume='${_lerp(clip.volumeKeys, Duration.zero, 't')}':eval=frame"
            else
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
      ...encoder.args(settings, bitrate: settings.bitrateFor(project)),
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

  /// Piecewise-linear FFmpeg expression of [keys] over time variable [t].
  /// [origin] is added to each key time (absolute vs clip-local time).
  String _lerp(Keyframes keys, Duration origin, String t) {
    final pts = keys.points;
    if (pts.length == 1) return _n(pts.first.value);
    var expr = _n(pts.last.value);
    for (var i = pts.length - 2; i >= 0; i--) {
      final a = pts[i];
      final b = pts[i + 1];
      final span = b.time - a.time;
      final segment = span <= Duration.zero
          ? _n(b.value)
          : '(${_n(a.value)}+(${_n(b.value - a.value)})*($t-${_s(origin + a.time)})/${_s(span)})';
      expr = 'if(lt($t,${_s(origin + b.time)}),$segment,$expr)';
    }
    return 'if(lt($t,${_s(origin + pts.first.time)}),${_n(pts.first.value)},$expr)';
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

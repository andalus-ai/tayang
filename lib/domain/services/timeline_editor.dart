import '../../core/utils/duration_x.dart';
import '../models/clip.dart';
import '../models/keyframes.dart';
import '../models/media_asset.dart';
import '../models/project.dart';
import '../models/track.dart';

/// Pure, deterministic editing operations: `Project in → Project out`.
///
/// No state, no randomness (callers pass ids), no Flutter. Every method returns
/// the *same* [Project] instance when the operation is rejected or a no-op, so
/// callers can cheaply detect "nothing happened".
class TimelineEditor {
  const TimelineEditor({
    this.minClipDuration = const Duration(milliseconds: 100),
    this.defaultImageDuration = const Duration(seconds: 5),
    this.defaultTextDuration = const Duration(seconds: 3),
  });

  final Duration minClipDuration;
  final Duration defaultImageDuration;
  final Duration defaultTextDuration;

  // ------------------------------------------------------------------ assets

  Project addAsset(Project p, MediaAsset asset) =>
      p.copyWith(assets: [...p.assets, asset]);

  /// Points an existing asset id at a new file (clips keep referencing the id).
  Project relinkAsset(Project p, MediaAsset replacement) => p.copyWith(
        assets: [for (final a in p.assets) a.id == replacement.id ? replacement : a],
      );

  /// Removes the asset and every clip that references it.
  Project removeAsset(Project p, String assetId) => p.copyWith(
        assets: [for (final a in p.assets) if (a.id != assetId) a],
        tracks: [
          for (final t in p.tracks)
            t.copyWith(clips: [
              for (final c in t.clips) if (c.assetId != assetId) c,
            ]),
        ],
      );

  // ------------------------------------------------------------------ tracks

  Project addTrack(Project p, TrackKind kind, {required String trackId}) {
    final count = p.tracks.where((t) => t.kind == kind).length + 1;
    final track = Track(id: trackId, kind: kind, name: '${kind.label} $count');
    final tracks = [...p.tracks];
    final index = switch (kind) {
      TrackKind.text => 0,
      TrackKind.video => () {
          final i = tracks.indexWhere((t) => t.kind != TrackKind.text);
          return i < 0 ? tracks.length : i;
        }(),
      TrackKind.audio => tracks.length,
    };
    tracks.insert(index, track);
    return p.copyWith(tracks: tracks);
  }

  Project removeTrack(Project p, String trackId) =>
      p.copyWith(tracks: [for (final t in p.tracks) if (t.id != trackId) t]);

  Project updateTrack(Project p, String trackId, Track Function(Track) update) =>
      p.copyWith(tracks: [
        for (final t in p.tracks) t.id == trackId ? update(t) : t,
      ]);

  // ------------------------------------------------------------------- clips

  Project addClipFromAsset(
    Project project,
    MediaAsset asset, {
    required String clipId,
    required String newTrackId,
    Duration? at,
    String? trackId,
  }) {
    final kind = asset.kind.clipKind;
    var p = project;

    Track? track = trackId == null ? null : p.trackById(trackId);
    if (track == null || !track.kind.accepts(kind) || track.isLocked) {
      track = p.tracks
          .where((t) => t.kind.accepts(kind) && !t.isLocked)
          .firstOrNull;
    }
    if (track == null) {
      p = addTrack(p, TrackKind.forClip(kind), trackId: newTrackId);
      track = p.trackById(newTrackId)!;
    }

    final length = asset.isTimeBased && asset.duration > Duration.zero
        ? asset.duration
        : defaultImageDuration;
    final start = _firstFree(track, at ?? track.end, length);

    final clip = TimelineClip(
      id: clipId,
      kind: kind,
      assetId: asset.id,
      start: start,
      duration: length,
    );
    return _replaceTrack(p, track.copyWith(clips: _sorted([...track.clips, clip])));
  }

  Project addTextClip(
    Project project, {
    required String clipId,
    required String newTrackId,
    required Duration at,
    TextOverlay text = const TextOverlay(),
  }) {
    var p = project;
    Track? track = p.tracks
        .where((t) => t.kind == TrackKind.text && !t.isLocked)
        .firstOrNull;
    if (track == null) {
      p = addTrack(p, TrackKind.text, trackId: newTrackId);
      track = p.trackById(newTrackId)!;
    }
    final clip = TimelineClip(
      id: clipId,
      kind: ClipKind.text,
      start: _firstFree(track, at, defaultTextDuration),
      duration: defaultTextDuration,
      text: text,
    );
    return _replaceTrack(p, track.copyWith(clips: _sorted([...track.clips, clip])));
  }

  /// Moves a clip (optionally to another compatible track). Rejected — the
  /// original project is returned — if it would overlap another clip.
  Project moveClip(
    Project p,
    String clipId,
    Duration newStart, {
    String? toTrackId,
    Iterable<Duration> snapPoints = const [],
    Duration snapThreshold = Duration.zero,
  }) {
    final clip = p.clipById(clipId);
    final source = p.trackOfClip(clipId);
    if (clip == null || source == null || source.isLocked) return p;

    final target = toTrackId == null ? source : p.trackById(toTrackId);
    if (target == null || target.isLocked || !target.kind.accepts(clip.kind)) {
      return p;
    }

    var start = newStart < Duration.zero ? Duration.zero : newStart;
    start = _snap(start, clip.duration, snapPoints, snapThreshold);
    if (_overlaps(target, start, start + clip.duration, ignore: clipId)) return p;
    if (start == clip.start && target.id == source.id) return p;

    final moved = clip.copyWith(start: start);
    return p.copyWith(tracks: [
      for (final t in p.tracks)
        if (t.id == target.id)
          t.copyWith(clips: _sorted([
            for (final c in t.clips) if (c.id != clipId) c,
            moved,
          ]))
        else if (t.id == source.id)
          t.copyWith(clips: [for (final c in t.clips) if (c.id != clipId) c])
        else
          t,
    ]);
  }

  /// Drags the clip's left edge to [newStart] (changes in-point + duration).
  Project trimClipStart(Project p, String clipId, Duration newStart) {
    final clip = p.clipById(clipId);
    final track = p.trackOfClip(clipId);
    if (clip == null || track == null || track.isLocked) return p;

    var lowest = Duration.zero;
    for (final c in track.clips) {
      if (c.id != clipId && c.end <= clip.start) lowest = maxDuration(lowest, c.end);
    }
    if (clip.isTimeBased) {
      // The in-point can't go before the start of the source.
      final room = Duration(
          microseconds: (clip.sourceStart.inMicroseconds / clip.speed).round());
      lowest = maxDuration(lowest, clip.start - room);
    }
    final highest = clip.end - minClipDuration;
    final start = newStart.clampTo(lowest, highest);
    if (start == clip.start) return p;

    final delta = start - clip.start;
    final sourceDelta =
        Duration(microseconds: (delta.inMicroseconds * clip.speed).round());
    return _replaceClip(
      p,
      clip.copyWith(
        start: start,
        duration: clip.duration - delta,
        opacityKeys: clip.opacityKeys.slice(delta, clip.duration - delta),
        volumeKeys: clip.volumeKeys.slice(delta, clip.duration - delta),
        sourceStart:
            clip.isTimeBased ? clip.sourceStart + sourceDelta : clip.sourceStart,
      ),
    );
  }

  /// Drags the clip's right edge to [newEnd] (changes duration only).
  Project trimClipEnd(Project p, String clipId, Duration newEnd) {
    final clip = p.clipById(clipId);
    final track = p.trackOfClip(clipId);
    if (clip == null || track == null || track.isLocked) return p;

    final lowest = clip.start + minClipDuration;
    var highest = const Duration(hours: 10);
    for (final c in track.clips) {
      if (c.id != clipId && c.start >= clip.end) highest = minDuration(highest, c.start);
    }
    final asset = p.assetById(clip.assetId);
    if (clip.isTimeBased && asset != null && asset.duration > Duration.zero) {
      final room = Duration(
          microseconds:
              ((asset.duration - clip.sourceStart).inMicroseconds / clip.speed)
                  .round());
      highest = minDuration(highest, clip.start + room);
    }
    final end = newEnd.clampTo(lowest, highest);
    if (end == clip.end) return p;
    final length = end - clip.start;
    return _replaceClip(
      p,
      clip.copyWith(
        duration: length,
        opacityKeys: clip.opacityKeys.slice(Duration.zero, length),
        volumeKeys: clip.volumeKeys.slice(Duration.zero, length),
      ),
    );
  }

  /// Splits [clipId] at timeline time [at] into two contiguous clips.
  Project splitClip(
    Project p,
    String clipId,
    Duration at, {
    required String rightClipId,
  }) {
    final clip = p.clipById(clipId);
    final track = p.trackOfClip(clipId);
    if (clip == null || track == null || track.isLocked) return p;
    if (at <= clip.start + minClipDuration || at >= clip.end - minClipDuration) {
      return p;
    }
    final leftLength = at - clip.start;
    final rightLength = clip.end - at;
    final left = clip.copyWith(
      duration: leftLength,
      fadeOut: Duration.zero,
      opacityKeys: clip.opacityKeys.slice(Duration.zero, leftLength),
      volumeKeys: clip.volumeKeys.slice(Duration.zero, leftLength),
    );
    final right = clip.copyWith(
      id: rightClipId,
      fadeIn: Duration.zero,
      start: at,
      duration: rightLength,
      opacityKeys: clip.opacityKeys.slice(leftLength, rightLength),
      volumeKeys: clip.volumeKeys.slice(leftLength, rightLength),
      sourceStart: clip.isTimeBased ? clip.sourcePositionAt(at) : clip.sourceStart,
    );
    return updateTrack(
      p,
      track.id,
      (t) => t.copyWith(clips: _sorted([
        for (final c in t.clips)
          if (c.id != clipId) c,
        left,
        right,
      ])),
    );
  }

  Project deleteClip(Project p, String clipId, {bool ripple = false}) {
    final clip = p.clipById(clipId);
    final track = p.trackOfClip(clipId);
    if (clip == null || track == null || track.isLocked) return p;
    return updateTrack(
      p,
      track.id,
      (t) => t.copyWith(clips: [
        for (final c in t.clips)
          if (c.id != clipId)
            if (ripple && c.start >= clip.end)
              c.copyWith(start: c.start - clip.duration)
            else
              c,
      ]),
    );
  }

  Project duplicateClip(Project p, String clipId, {required String newClipId}) {
    final clip = p.clipById(clipId);
    final track = p.trackOfClip(clipId);
    if (clip == null || track == null || track.isLocked) return p;
    final copy = clip.copyWith(
      id: newClipId,
      start: _firstFree(track, clip.end, clip.duration),
    );
    return _replaceTrack(p, track.copyWith(clips: _sorted([...track.clips, copy])));
  }

  /// Changes playback speed while keeping the same slice of source media, so the
  /// timeline duration scales inversely. Rejected on overlap.
  Project setSpeed(Project p, String clipId, double speed) {
    final clip = p.clipById(clipId);
    final track = p.trackOfClip(clipId);
    if (clip == null || track == null || track.isLocked || !clip.isTimeBased) return p;
    final s = speed.clamp(0.25, 4.0).toDouble();
    final newDuration =
        Duration(microseconds: (clip.sourceDuration.inMicroseconds / s).round());
    if (newDuration < minClipDuration) return p;
    if (_overlaps(track, clip.start, clip.start + newDuration, ignore: clipId)) return p;
    final ratio = clip.duration.inMicroseconds == 0
        ? 1.0
        : newDuration.inMicroseconds / clip.duration.inMicroseconds;
    return _replaceClip(
      p,
      clip.copyWith(
        speed: s,
        duration: newDuration,
        opacityKeys: clip.opacityKeys.scaleTime(ratio),
        volumeKeys: clip.volumeKeys.scaleTime(ratio),
      ),
    );
  }

  Project updateClip(Project p, String clipId, TimelineClip Function(TimelineClip) update) {
    final clip = p.clipById(clipId);
    if (clip == null) return p;
    return _replaceClip(p, update(clip));
  }

  /// Pastes a copy of [clip] at [at] on [trackId] or the first compatible track.
  Project insertClip(
    Project project,
    TimelineClip clip, {
    required String newClipId,
    required String newTrackId,
    required Duration at,
    String? trackId,
  }) {
    var p = project;
    Track? track = trackId == null ? null : p.trackById(trackId);
    if (track == null || !track.kind.accepts(clip.kind) || track.isLocked) {
      track = p.tracks
          .where((t) => t.kind.accepts(clip.kind) && !t.isLocked)
          .firstOrNull;
    }
    if (track == null) {
      p = addTrack(p, TrackKind.forClip(clip.kind), trackId: newTrackId);
      track = p.trackById(newTrackId)!;
    }
    final copy = clip.copyWith(
      id: newClipId,
      start: _firstFree(track, at, clip.duration),
    );
    return _replaceTrack(p, track.copyWith(clips: _sorted([...track.clips, copy])));
  }

  /// "Dip" transition: fades [clipId] out and the clip that directly follows it
  /// on the same track in, by [length] (capped at half the shorter clip).
  Project addTransition(Project p, String clipId, Duration length) {
    final clip = p.clipById(clipId);
    final track = p.trackOfClip(clipId);
    if (clip == null || track == null || track.isLocked) return p;
    TimelineClip? next;
    for (final c in track.clips) {
      if (c.id != clipId && (c.start - clip.end).abs() < const Duration(milliseconds: 50)) {
        next = c;
      }
    }
    if (next == null) return p;
    final d = minDuration(length, minDuration(clip.duration, next.duration) ~/ 2);
    return _replaceClip(_replaceClip(p, clip.copyWith(fadeOut: d)), next.copyWith(fadeIn: d));
  }

  /// Crossfade from [clipId] into the clip that directly follows it: the next
  /// clip (and everything after it) slides earlier by [length] so the two
  /// overlap, and the next clip fades in over the outgoing one.
  Project addCrossfade(Project p, String clipId, Duration length) {
    final a = p.clipById(clipId);
    final track = p.trackOfClip(clipId);
    if (a == null || track == null || track.isLocked) return p;
    TimelineClip? b;
    for (final c in track.clips) {
      if (c.id != clipId && (c.start - a.end).abs() < const Duration(milliseconds: 50)) b = c;
    }
    if (b == null) return p;
    final d = minDuration(length, minDuration(a.duration, b.duration) ~/ 2);
    if (d <= Duration.zero) return p;
    final next = b;
    return updateTrack(
      p,
      track.id,
      (t) => t.copyWith(clips: [
        for (final c in t.clips)
          if (c.start >= next.start)
            c.copyWith(
              start: c.start - d,
              fadeIn: c.id == next.id ? d : c.fadeIn,
            )
          else
            c,
      ]),
    );
  }

  /// Undoes [addCrossfade] for the clip that fades in over its predecessor.
  Project removeCrossfade(Project p, String clipId) {
    final b = p.clipById(clipId);
    final track = p.trackOfClip(clipId);
    if (b == null || track == null || track.isLocked) return p;
    TimelineClip? a;
    for (final c in track.clips) {
      if (c.id != clipId && c.start < b.start && c.end > b.start) a = c;
    }
    if (a == null) return p;
    final overlap = a.end - b.start;
    return updateTrack(
      p,
      track.id,
      (t) => t.copyWith(clips: [
        for (final c in t.clips)
          if (c.start >= b.start)
            c.copyWith(
              start: c.start + overlap,
              fadeIn: c.id == clipId ? Duration.zero : c.fadeIn,
            )
          else
            c,
      ]),
    );
  }

  // --------------------------------------------------------------- keyframes

  Project setKeyframe(
    Project p,
    String clipId,
    KeyframeProperty property,
    Duration at,
    double value,
  ) {
    final clip = p.clipById(clipId);
    if (clip == null || at < clip.start || at > clip.end) return p;
    final time = at - clip.start;
    return _replaceClip(
      p,
      switch (property) {
        KeyframeProperty.opacity => clip.copyWith(
            opacityKeys: clip.opacityKeys.set(time, value.clamp(0.0, 1.0).toDouble())),
        KeyframeProperty.volume => clip.copyWith(
            volumeKeys: clip.volumeKeys.set(time, value.clamp(0.0, 2.0).toDouble())),
      },
    );
  }

  Project removeKeyframe(Project p, String clipId, KeyframeProperty property, int index) {
    final clip = p.clipById(clipId);
    if (clip == null) return p;
    return _replaceClip(
      p,
      switch (property) {
        KeyframeProperty.opacity => clip.copyWith(opacityKeys: clip.opacityKeys.removeAt(index)),
        KeyframeProperty.volume => clip.copyWith(volumeKeys: clip.volumeKeys.removeAt(index)),
      },
    );
  }

  Project clearKeyframes(Project p, String clipId, KeyframeProperty property) {
    final clip = p.clipById(clipId);
    if (clip == null) return p;
    return _replaceClip(
      p,
      switch (property) {
        KeyframeProperty.opacity => clip.copyWith(opacityKeys: const Keyframes()),
        KeyframeProperty.volume => clip.copyWith(volumeKeys: const Keyframes()),
      },
    );
  }

  /// Start/end times of every clip (except [exclude]) — magnetic snap targets.
  List<Duration> edgePoints(Project p, {String? exclude}) => [
        Duration.zero,
        for (final t in p.tracks)
          for (final c in t.clips)
            if (c.id != exclude) ...[c.start, c.end],
      ];

  // ----------------------------------------------------------------- helpers

  Project _replaceTrack(Project p, Track track) => p.copyWith(
        tracks: [for (final t in p.tracks) t.id == track.id ? track : t],
      );

  Project _replaceClip(Project p, TimelineClip clip) => p.copyWith(tracks: [
        for (final t in p.tracks)
          t.clips.any((c) => c.id == clip.id)
              ? t.copyWith(clips: [
                  for (final c in t.clips) c.id == clip.id ? clip : c,
                ])
              : t,
      ]);

  List<TimelineClip> _sorted(List<TimelineClip> clips) =>
      [...clips]..sort((a, b) => a.start.compareTo(b.start));

  bool _overlaps(Track t, Duration start, Duration end, {String? ignore}) {
    for (final c in t.clips) {
      if (c.id == ignore) continue;
      if (c.start < end && start < c.end) return true;
    }
    return false;
  }

  /// Earliest start ≥ [desired] where a clip of [length] fits on [t].
  Duration _firstFree(Track t, Duration desired, Duration length,
      {String? ignore}) {
    var start = desired;
    for (final c in _sorted([for (final c in t.clips) if (c.id != ignore) c])) {
      if (c.start < start + length && start < c.end) start = c.end;
    }
    return start;
  }

  Duration _snap(
    Duration start,
    Duration length,
    Iterable<Duration> points,
    Duration threshold,
  ) {
    if (threshold <= Duration.zero) return start;
    var best = start;
    var bestDelta = threshold.inMicroseconds + 1;
    for (final point in points) {
      final startDelta = (point - start).inMicroseconds.abs();
      if (startDelta < bestDelta) {
        bestDelta = startDelta;
        best = point;
      }
      final endDelta = (point - (start + length)).inMicroseconds.abs();
      if (endDelta < bestDelta) {
        bestDelta = endDelta;
        best = point - length;
      }
    }
    return best < Duration.zero ? start : best;
  }
}

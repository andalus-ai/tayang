import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/duration_x.dart';
import 'project_controller.dart';

class PlaybackState {
  const PlaybackState({this.position = Duration.zero, this.isPlaying = false});

  final Duration position;
  final bool isPlaying;

  PlaybackState copyWith({Duration? position, bool? isPlaying}) => PlaybackState(
        position: position ?? this.position,
        isPlaying: isPlaying ?? this.isPlaying,
      );
}

/// The timeline clock. Media players follow this, never the other way round.
class PlaybackController extends Notifier<PlaybackState> {
  static const _tick = Duration(milliseconds: 33);

  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  Duration _origin = Duration.zero;

  @override
  PlaybackState build() {
    ref.onDispose(() => _timer?.cancel());
    return const PlaybackState();
  }

  Duration get _end => ref.read(projectProvider).duration;

  void play() {
    if (state.isPlaying || _end == Duration.zero) return;
    if (state.position >= _end) state = state.copyWith(position: Duration.zero);
    _origin = state.position;
    _stopwatch
      ..reset()
      ..start();
    _timer = Timer.periodic(_tick, (_) => _onTick());
    state = state.copyWith(isPlaying: true);
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    if (state.isPlaying) state = state.copyWith(isPlaying: false);
  }

  void toggle() => state.isPlaying ? pause() : play();

  void seek(Duration to) {
    final target = to.clampTo(Duration.zero, _end);
    if (state.isPlaying) {
      _origin = target;
      _stopwatch
        ..reset()
        ..start();
    }
    state = state.copyWith(position: target);
  }

  void stepFrames(int frames) {
    pause();
    final fps = ref.read(projectProvider).fps;
    final frame = Duration(microseconds: (Duration.microsecondsPerSecond / fps).round());
    seek(state.position + frame * frames);
  }

  void _onTick() {
    final end = _end;
    final next = _origin + _stopwatch.elapsed;
    if (next >= end) {
      if (ref.read(loopProvider) && end > Duration.zero) {
        _origin = Duration.zero;
        _stopwatch
          ..reset()
          ..start();
        state = state.copyWith(position: Duration.zero);
        return;
      }
      pause();
      state = state.copyWith(position: end);
    } else {
      state = state.copyWith(position: next);
    }
  }
}

final playbackProvider =
    NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);

/// Whether playback restarts from the beginning when it reaches the end.
class LoopController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final loopProvider = NotifierProvider<LoopController, bool>(LoopController.new);

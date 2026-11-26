# Tayang

Timeline video editor in Flutter. State: `flutter_riverpod` (Notifier API, no codegen, no freezed).

See the [user guide](docs/USER_GUIDE.md) and [changelog](CHANGELOG.md).

## Setup
    flutter create . --project-name tayang --org ai.andalus --platforms=android,ios,macos,windows,linux
    flutter pub get && flutter analyze && flutter test && flutter run

Platform notes: Linux build needs `libmpv-dev`, `libjson-glib-dev` and FFmpeg dev libs (`libavcodec-dev` etc.) for the FFmpegKit plugin; at runtime Linux exports through the system `ffmpeg`. Android needs `minSdkVersion 24`; iOS/macOS need a recent deployment target (see the
`ffmpeg_kit_flutter_new` docs). Linux uses the system `ffmpeg` + `ffprobe` on PATH.

## Architecture (dependencies point inward)
- `domain/` pure Dart: immutable models, `TimelineEditor` (all edit maths), repository/exporter/thumbnail interfaces
- `application/` Riverpod controllers + `EditorActions` use-cases; `di.dart` is the only composition root
- `data/` FFmpeg exporters/probes (FFmpegKit or system process), thumbnails, JSON persistence, player pool
- `presentation/` widgets only; no business logic

## Engine
- Export / probe / thumbnails: FFmpeg (`ffmpeg_kit_flutter_new`, or a system binary on Linux). Both exporters share `FfmpegCommandBuilder`.
- Preview: `video_player`, slaved to the timeline clock.

## Features
Multi-track timeline, drag/trim/split/ripple/duplicate, magnetic snapping, text clips, speed, volume, opacity,
fade in/out, dip transitions + true crossfades, picture-in-picture (multi-layer preview), opacity + volume keyframes, scale/position transform, copy/cut/paste, snapping toggle, loop playback, fit-to-timeline, thumbnails, audio waveforms, undo/redo (gestures = one step), autosave, aspect presets, export (480p–4K), shortcuts
(Space, S, Del, Shift+Del, ←/→, Ctrl/Cmd+Z, Ctrl/Cmd+Shift+Z, Ctrl/Cmd+D/C/X/V, Ctrl+wheel zoom).

## Known limits
Keyframed opacity exports via `geq` (per-pixel, slow at 4K). Clips in a crossfade can't be dragged until the crossfade is removed. Text clips have no keyframes/fades in export.
Not yet compiled by the author, so run `flutter analyze` first (CI does it). Silent videos rely on the probe's audio
detection. Preview mixes via separate players (not sample-accurate). Text clips don't fade in export.

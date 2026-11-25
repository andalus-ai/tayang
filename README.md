# Tayang

Timeline video editor in Flutter. State: `flutter_riverpod` (Notifier API, no codegen, no freezed).

## Setup
    flutter create . --project-name tayang --org ai.andalus --platforms=android,ios,macos,windows,linux
    flutter pub get && flutter analyze && flutter test && flutter run

Platform notes: Android needs `minSdkVersion 24`; iOS/macOS need a recent deployment target (see the
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
fade in/out, thumbnails, undo/redo (gestures = one step), autosave, aspect presets, export (480p–4K), shortcuts
(Space, S, Del, Shift+Del, ←/→, Ctrl/Cmd+Z, Ctrl/Cmd+Shift+Z, Ctrl/Cmd+D, Ctrl+wheel zoom).

## Known limits
Not yet compiled by the author, so run `flutter analyze` first (CI does it). Silent videos rely on the probe's audio
detection. Preview mixes via separate players (not sample-accurate). Text clips don't fade in export.

# Tayang

Timeline video editor in Flutter. State: `flutter_riverpod` (Notifier API, no codegen, no freezed).

## Layers (dependencies point inward)
- `domain/` pure Dart: immutable models, `TimelineEditor` (all edit maths), repository/exporter interfaces
- `application/` Riverpod controllers + `EditorActions` use-cases; `di.dart` is the only composition root
- `data/` FFmpegKit exporter/prober, JSON persistence, player pool
- `presentation/` widgets only; no business logic

## Engine
- Export + probing: FFmpeg via `ffmpeg_kit_flutter_new` (Android, iOS, macOS, Windows). Swap by overriding `videoExporterProvider`.
- Preview: `video_player`, slaved to the timeline clock.

## Run
    flutter pub get && flutter test && flutter run

Not yet compiled/run by the author: run `flutter analyze` first.

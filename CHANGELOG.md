# Changelog

## Unreleased
- Performance: playback ticks on a 400-clip project 29 ms → 8.7 ms (debug, headless): per-clip state selection,
  structure-only clips layer, repaint boundaries, off-screen clip culling. Benchmarks in `test/perf_test.dart`.
- Gestures: clips follow the pointer exactly, trim handles are relative, vertical drags change track.
- Fixed inspector keyframe buttons overflowing the panel.

## 0.1.0-rc.1
- Multi-track timeline: move, trim, split, ripple delete, duplicate, copy/paste, snapping, undo/redo.
- Effects: speed, volume, opacity, fades, keyframes, scale/position, crossfades, dip transitions, picture-in-picture, text.
- Thumbnails and audio waveforms; media relinking; autosave and crash log.
- FFmpeg export (480p–4K) via FFmpegKit, or system FFmpeg on Linux.
- Release workflow for Android, Windows, macOS and Linux.

# Changelog

## Unreleased
- Performance: playback ticks on a 400-clip project 29 ms → 8.7 ms (debug, headless): per-clip state selection,
  structure-only clips layer, repaint boundaries, off-screen clip culling. Benchmarks in `test/perf_test.dart`.
- Export speed (1080p, 6 s, 4-core CI): fades+transform 9.9 s → 3.7 s, picture-in-picture 5.0 s → 3.1 s,
  combined project 6.7 s → 4.2 s; every 1080p scenario now renders faster than real time (0.3–0.75x).
  4K: plain 1.0x, keyframed opacity 2.0x real time. Benchmarks in `test/integration/export_perf_test.dart`.
- Gestures: clips follow the pointer exactly, trim handles are relative, vertical drags change track.
- Fixed inspector keyframe buttons overflowing the panel.

## 0.1.0-rc.1
- Multi-track timeline: move, trim, split, ripple delete, duplicate, copy/paste, snapping, undo/redo.
- Effects: speed, volume, opacity, fades, keyframes, scale/position, crossfades, dip transitions, picture-in-picture, text.
- Thumbnails and audio waveforms; media relinking; autosave and crash log.
- FFmpeg export (480p–4K) via FFmpegKit, or system FFmpeg on Linux.
- Release workflow for Android, Windows, macOS and Linux.

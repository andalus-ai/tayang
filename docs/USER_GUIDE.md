# Tayang user guide

## Quick start
1. **Import** media with the ➕ button in the *Media* panel (video, audio, images).
2. **Drag** a media item onto a timeline track, or press its ⊕ button to add it at the playhead.
3. **Edit** on the timeline: drag clips to move, drag clip edges to trim, press **S** to split at the playhead.
4. **Refine** the selected clip in the *Inspector* (speed, volume, opacity, fades, keyframes, transform).
5. **Export** with the *Export* button (480p–4K, 24/30/60 fps, three quality levels).

Projects autosave continuously and reopen where you left off. *New project* (top bar) starts a fresh one.

## Timeline
- **Tracks** are layered top to bottom: upper video tracks are drawn on top. Each track can be hidden, muted or locked.
- **Snapping** (magnet button) aligns clip edges to neighbours and the playhead.
- **Zoom** with the slider, *Fit* button, or **Ctrl/⌘ + scroll**.
- **Clips** show thumbnails (video/image) or a waveform (audio). Diamonds mark keyframes.

## Effects
| Feature | How |
|---|---|
| Speed (0.25×–4×) | Inspector → Speed |
| Volume / opacity | Inspector sliders |
| Keyframes | Move the playhead inside the clip, press **Keyframe at playhead**, then change the slider |
| Fade in / out | Inspector → Fade sliders |
| Dip to black | **Dip to next** fades one clip out and the next in |
| Crossfade | **Crossfade to next** overlaps two adjacent clips (remove it to move them again) |
| Picture-in-picture | Put a clip on a higher video track, then set Scale / Position |
| Text | **T** button adds a text clip; edit text, size, colour and position in the Inspector |

## Keyboard shortcuts
| Key | Action |
|---|---|
| Space | Play / pause |
| S | Split at playhead |
| Delete / Shift+Delete | Delete / ripple delete |
| ← / → | Step one frame |
| Home / End | Jump to start / end |
| Ctrl/⌘ + Z, Shift+Z (or Y) | Undo, redo |
| Ctrl/⌘ + C, X, V, D | Copy, cut, paste, duplicate |
| Ctrl/⌘ + scroll | Zoom timeline |

## Troubleshooting
- **"FFmpeg tools not found" (Linux):** install FFmpeg (`sudo apt install ffmpeg`) and restart. Windows, macOS, Android and iOS bundle their own.
- **Media shows a ⛓ icon:** the file moved. Click the icon in the Media panel to relink it; clips stay attached.
- **Export refuses to start:** relink missing media first; the message lists the files.
- **Silent or very slow export:** keyframed opacity and 4K are the heaviest options. Use *Draft* quality to preview.
- **Crash log:** `<Documents>/tayang/logs/error.log`.
- **Project files:** `<Documents>/tayang/projects/`. Exports: `<Documents>/tayang/exports/`.

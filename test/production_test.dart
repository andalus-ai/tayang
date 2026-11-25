import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayang/application/di.dart';
import 'package:tayang/application/export_controller.dart';
import 'package:tayang/core/utils/stable_key.dart';
import 'package:tayang/domain/export/video_exporter.dart';
import 'package:tayang/domain/models/media_asset.dart';
import 'package:tayang/domain/models/project.dart';
import 'package:tayang/domain/models/track.dart';
import 'package:tayang/domain/services/timeline_editor.dart';

void main() {
  const editor = TimelineEditor();
  const asset = MediaAsset(
    id: 'a', path: '/old/a.mp4', name: 'a.mp4',
    kind: MediaKind.video, duration: Duration(seconds: 5),
  );
  final project = editor.addClipFromAsset(
    const Project(
      id: 'p', name: 'My Cut', assets: [asset],
      tracks: [Track(id: 'v', kind: TrackKind.video, name: 'V')],
    ),
    asset, clipId: 'c', newTrackId: 't',
  );

  test('relink keeps the asset id so clips stay attached', () {
    final relinked = editor.relinkAsset(
      project,
      const MediaAsset(
        id: 'a', path: '/new/a.mp4', name: 'a.mp4',
        kind: MediaKind.video, duration: Duration(seconds: 5),
      ),
    );
    expect(relinked.assetById('a')!.path, '/new/a.mp4');
    expect(relinked.clipById('c')!.assetId, 'a');
  });

  test('stableKey is deterministic and path-sensitive', () {
    expect(stableKey('/x/y.mp4'), stableKey('/x/y.mp4'));
    expect(stableKey('/x/y.mp4'), isNot(stableKey('/x/z.mp4')));
  });

  test('export refuses to start when media files are missing', () async {
    final container = ProviderContainer(overrides: [
      initialProjectProvider.overrideWithValue(project),
      fileExistsProvider.overrideWithValue((_) => false),
    ]);
    addTearDown(container.dispose);

    await container.read(exportControllerProvider.notifier).start(const ExportSettings());
    final state = container.read(exportControllerProvider);
    expect(state.status, ExportStatus.failed);
    expect(state.error, contains('a.mp4'));
  });
}

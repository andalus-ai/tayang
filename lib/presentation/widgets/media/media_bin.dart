import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/editor_actions.dart';
import '../../../application/media_import_controller.dart';
import '../../../application/media_status.dart';
import '../../../application/project_controller.dart';
import '../../../application/subtitle_import_controller.dart';
import '../../../application/thumbnails.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/clip.dart';
import '../../../domain/models/media_asset.dart';
import '../common/icon_action_button.dart';
import '../common/panel_container.dart';
import '../common/timecode_text.dart';

class MediaBin extends ConsumerWidget {
  const MediaBin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(projectProvider.select((p) => p.assets));
    final importing = ref.watch(mediaImportControllerProvider).isLoading;
    final importer = ref.read(mediaImportControllerProvider.notifier);

    ref.listen(mediaImportControllerProvider, (_, state) {
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${state.error}')),
        );
      }
    });

    return PanelContainer(
      title: 'Media',
      actions: [
        IconActionButton(
          icon: Icons.subtitles_outlined,
          tooltip: 'Import subtitles (.srt / .vtt)',
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final added = await ref.read(subtitleImportProvider.notifier).importFile();
            final error = ref.read(subtitleImportProvider).error;
            if (error != null) {
              messenger.showSnackBar(SnackBar(content: Text('Subtitle import failed: $error')));
            } else if (added != null) {
              messenger.showSnackBar(
                SnackBar(content: Text('Added $added subtitle${added == 1 ? '' : 's'} on a new track')),
              );
            }
          },
        ),
        if (importing)
          const Padding(
            padding: EdgeInsets.all(10),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconActionButton(
            icon: Icons.add_photo_alternate_outlined,
            tooltip: 'Import media',
            onPressed: importer.importMedia,
          ),
      ],
      child: assets.isEmpty
          ? _EmptyState(onImport: importer.importMedia)
          : ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: assets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _MediaTile(asset: assets[i]),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined, size: 36, color: AppColors.mutedText),
            const SizedBox(height: 10),
            const Text('No media yet', style: TextStyle(color: AppColors.mutedText)),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('Import'),
            ),
          ],
        ),
      );
}

class _MediaTile extends ConsumerWidget {
  const _MediaTile({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tile = _TileContent(
      asset: asset,
      missing: ref.watch(assetMissingProvider(asset)),
      onRelink: () => ref.read(mediaImportControllerProvider.notifier).relink(asset),
      onAdd: () => ref.read(editorActionsProvider).addAsset(asset),
      onRemove: () =>
          ref.read(projectControllerProvider.notifier).removeAsset(asset.id),
    );

    return Draggable<MediaAsset>(
      data: asset,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Chip(
          avatar: Icon(_icon(asset.kind), size: 16),
          label: Text(asset.name),
          backgroundColor: AppColors.surfaceHigh,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: tile),
      child: tile,
    );
  }
}

IconData _icon(MediaKind kind) => switch (kind) {
      MediaKind.video => Icons.movie_outlined,
      MediaKind.audio => Icons.graphic_eq,
      MediaKind.image => Icons.image_outlined,
    };

class _TileContent extends ConsumerWidget {
  const _TileContent({
    required this.asset,
    required this.onAdd,
    required this.onRemove,
    required this.missing,
    required this.onRelink,
  });

  final bool missing;
  final VoidCallback onRelink;
  final MediaAsset asset;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppColors.forClip(asset.kind.clipKind);
    final thumbnail = ref.watch(thumbnailPathProvider(asset)).valueOrNull;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              height: 40,
              child: thumbnail != null
                  ? Image.file(
                      File(thumbnail),
                      fit: BoxFit.cover,
                      cacheWidth: 112,
                      errorBuilder: (_, __, ___) => _IconBox(asset.kind, color),
                    )
                  : _IconBox(asset.kind, color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                if (asset.isTimeBased)
                  TimecodeText(
                    asset.duration,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedText),
                  )
                else
                  Text(
                    'Image',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedText),
                  ),
              ],
            ),
          ),
          if (missing)
            IconActionButton(
              icon: Icons.link_off,
              tooltip: 'File not found — tap to relink',
              selected: true,
              onPressed: onRelink,
            )
          else
            IconActionButton(
              icon: Icons.add_circle_outline,
              tooltip: 'Add to timeline at playhead',
              onPressed: onAdd,
            ),
          IconActionButton(
            icon: Icons.delete_outline,
            tooltip: 'Remove from project',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.kind, this.color);

  final MediaKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: color.withAlpha(60),
        child: Icon(_icon(kind), color: color),
      );
}

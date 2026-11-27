import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/export_controller.dart';
import '../../../domain/export/video_exporter.dart';

class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  ExportSettings _settings = const ExportSettings();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exportControllerProvider);
    final controller = ref.read(exportControllerProvider.notifier);

    return AlertDialog(
      title: const Text('Export video'),
      content: SizedBox(
        width: 440,
        child: switch (state.status) {
          ExportStatus.idle => _form(),
          ExportStatus.running => _progress(state),
          ExportStatus.done => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Export finished. Saved to:'),
                const SizedBox(height: 8),
                SelectableText(state.outputPath ?? ''),
                if (state.encoder != null) ...[
                  const SizedBox(height: 10),
                  Text('Encoded with ${state.encoder}'),
                ],
              ],
            ),
          ExportStatus.failed => SingleChildScrollView(
              child: SelectableText(state.error ?? 'Export failed'),
            ),
        },
      ),
      actions: [
        if (state.status == ExportStatus.running)
          TextButton(onPressed: controller.cancel, child: const Text('Cancel export'))
        else ...[
          TextButton(
            onPressed: () {
              controller.reset();
              Navigator.pop(context);
            },
            child: Text(state.status == ExportStatus.idle ? 'Close' : 'Done'),
          ),
          if (state.status == ExportStatus.idle)
            FilledButton(
              onPressed: () => controller.start(_settings),
              child: const Text('Export'),
            ),
          if (state.status == ExportStatus.failed)
            FilledButton(onPressed: controller.reset, child: const Text('Back')),
        ],
      ],
    );
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resolution'),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 480, label: Text('480p')),
            ButtonSegment(value: 720, label: Text('720p')),
            ButtonSegment(value: 1080, label: Text('1080p')),
            ButtonSegment(value: 2160, label: Text('4K')),
          ],
          selected: {_settings.height},
          onSelectionChanged: (s) => setState(() => _settings = _settings.copyWith(height: s.first)),
        ),
        const SizedBox(height: 16),
        const Text('Frame rate'),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 24, label: Text('24')),
            ButtonSegment(value: 30, label: Text('30')),
            ButtonSegment(value: 60, label: Text('60')),
          ],
          selected: {_settings.fps},
          onSelectionChanged: (s) => setState(() => _settings = _settings.copyWith(fps: s.first)),
        ),
        const SizedBox(height: 16),
        const Text('Quality'),
        const SizedBox(height: 6),
        SegmentedButton<ExportQuality>(
          showSelectedIcon: false,
          segments: [
            for (final q in ExportQuality.values)
              ButtonSegment(value: q, label: Text(q.label)),
          ],
          selected: {_settings.quality},
          onSelectionChanged: (s) =>
              setState(() => _settings = _settings.copyWith(quality: s.first)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hardware acceleration'),
          subtitle: const Text('Faster on supported devices; falls back automatically'),
          value: _settings.hardware,
          onChanged: (v) => setState(() => _settings = _settings.copyWith(hardware: v)),
        ),
      ],
    );
  }

  Widget _progress(ExportState state) {
    final percent = (state.progress * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: state.progress > 0 ? state.progress : null),
        const SizedBox(height: 10),
        Text('Rendering… $percent%'),
      ],
    );
  }
}

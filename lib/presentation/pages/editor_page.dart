import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/autosave.dart';
import '../widgets/inspector/inspector_panel.dart';
import '../widgets/media/media_bin.dart';
import '../widgets/preview/preview_panel.dart';
import '../widgets/timeline/timeline_panel.dart';
import '../widgets/toolbar/editor_top_bar.dart';
import '../widgets/toolbar/transport_bar.dart';
import 'editor_shortcuts.dart';

class EditorPage extends ConsumerWidget {
  const EditorPage({super.key});

  static const _compactBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autosaveProvider);

    return EditorShortcuts(
      child: Scaffold(
        appBar: const EditorTopBar(),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < _compactBreakpoint;
            return Column(
              children: [
                Expanded(
                  flex: 5,
                  child: compact
                      ? const PreviewPanel()
                      : const Row(
                          children: [
                            SizedBox(width: 290, child: MediaBin()),
                            VerticalDivider(),
                            Expanded(child: PreviewPanel()),
                            VerticalDivider(),
                            SizedBox(width: 310, child: InspectorPanel()),
                          ],
                        ),
                ),
                TransportBar(
                  onOpenMedia: compact ? () => _openSheet(context, const MediaBin()) : null,
                  onOpenInspector:
                      compact ? () => _openSheet(context, const InspectorPanel()) : null,
                ),
                const Expanded(flex: 4, child: TimelinePanel()),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, Widget panel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: panel,
      ),
    );
  }
}

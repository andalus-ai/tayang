import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/autosave.dart';
import '../../application/onboarding_controller.dart';
import '../widgets/help/help_dialog.dart';
import '../widgets/inspector/inspector_panel.dart';
import '../widgets/media/media_bin.dart';
import '../widgets/preview/preview_panel.dart';
import '../widgets/timeline/timeline_panel.dart';
import '../widgets/toolbar/editor_top_bar.dart';
import '../widgets/toolbar/transport_bar.dart';
import 'editor_shortcuts.dart';

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  static const _compactBreakpoint = 900.0;

  late final AppLifecycleListener _lifecycle;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(welcomeProvider)) _showWelcome();
    });
    // Don't lose edits if the OS kills the app right after it's backgrounded.
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) {
          ref.read(autosaveFlushProvider)();
        }
      },
    );
  }

  Future<void> _showWelcome() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const HelpDialog(welcome: true),
    );
    if (mounted) ref.read(welcomeProvider.notifier).dismiss();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(autosaveProvider);

    return EditorShortcuts(
      child: Scaffold(
        appBar: const EditorTopBar(),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < _compactBreakpoint;
            final engine = ref.watch(engineStatusProvider).valueOrNull;
            return Column(
              children: [
                if (engine != null && !engine.ready && !_bannerDismissed)
                  MaterialBanner(
                    content: Text(engine.message ?? 'FFmpeg is not available.'),
                    leading: const Icon(Icons.warning_amber_rounded),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _bannerDismissed = true),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
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

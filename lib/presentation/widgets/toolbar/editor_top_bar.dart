import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/editor_actions.dart';
import '../../../application/project_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../common/icon_action_button.dart';
import '../export/export_dialog.dart';
import '../help/help_dialog.dart';

class EditorTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const EditorTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(editorActionsProvider);
    final canUndo = ref.watch(canUndoProvider);
    final canRedo = ref.watch(canRedoProvider);

    return AppBar(
      titleSpacing: 14,
      title: Row(
        children: [
          const Icon(Icons.movie_filter_outlined, color: AppColors.accent),
          const SizedBox(width: 8),
          Text('Tayang', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 16),
          const Flexible(child: _ProjectName()),
        ],
      ),
      actions: [
        IconActionButton(
          icon: Icons.help_outline,
          tooltip: 'Help & shortcuts',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const HelpDialog(welcome: false),
          ),
        ),
        IconActionButton(
          icon: Icons.note_add_outlined,
          tooltip: 'New project',
          onPressed: () => _confirmNew(context, actions.newProject),
        ),
        IconActionButton(
          icon: Icons.undo,
          tooltip: 'Undo (Ctrl+Z)',
          onPressed: canUndo ? actions.undo : null,
        ),
        IconActionButton(
          icon: Icons.redo,
          tooltip: 'Redo (Ctrl+Shift+Z)',
          onPressed: canRedo ? actions.redo : null,
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const ExportDialog(),
          ),
          icon: const Icon(Icons.ios_share, size: 18),
          label: const Text('Export'),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

Future<void> _confirmNew(BuildContext context, VoidCallback onConfirm) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Start a new project?'),
      content: const Text('The current project is autosaved, so you can keep working on it later.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('New project')),
      ],
    ),
  );
  if (ok == true) onConfirm();
}

class _ProjectName extends ConsumerWidget {
  const _ProjectName();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(projectProvider.select((p) => p.name));
    return TextButton.icon(
      onPressed: () async {
        final result = await showDialog<String>(
          context: context,
          builder: (_) => _RenameDialog(initial: name),
        );
        if (result != null) ref.read(projectControllerProvider.notifier).rename(result);
      },
      icon: const Icon(Icons.edit_outlined, size: 14),
      label: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename project'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

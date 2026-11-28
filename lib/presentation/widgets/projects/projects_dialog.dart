import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/project_controller.dart';
import '../../../application/project_library_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_x.dart';
import '../../../domain/repositories/project_repository.dart';

/// Browse, open and delete saved projects.
class ProjectsDialog extends ConsumerWidget {
  const ProjectsDialog({super.key});

  static String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(projectLibraryProvider);
    final currentId = ref.watch(projectProvider.select((p) => p.id));
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText);

    return AlertDialog(
      title: const Text('Projects'),
      content: SizedBox(
        width: 480,
        height: 360,
        child: library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load projects: $e')),
          data: (items) => items.isEmpty
              ? Center(child: Text('No saved projects yet.', style: muted))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = items[i];
                    final isCurrent = s.id == currentId;
                    return ListTile(
                      selected: isCurrent,
                      leading: const Icon(Icons.movie_outlined),
                      title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${_date(s.modified)} · ${s.duration.timecode} · ${s.clipCount} clips'
                        '${isCurrent ? ' · open now' : ''}',
                        style: muted,
                      ),
                      onTap: isCurrent
                          ? null
                          : () async {
                              await ref.read(projectLibraryProvider.notifier).open(s.id);
                              if (context.mounted) Navigator.pop(context);
                            },
                      trailing: IconButton(
                        tooltip: 'Delete project',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, ref, s),
                      ),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, ProjectSummary project) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${project.name}"?'),
        content: const Text('This removes the project file. Your media files are not touched.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.read(projectLibraryProvider.notifier).delete(project.id);
  }
}

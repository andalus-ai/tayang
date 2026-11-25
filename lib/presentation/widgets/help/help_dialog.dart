import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// First-run welcome (`welcome: true`) or the always-available shortcut help.
class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key, required this.welcome});

  final bool welcome;

  static const _steps = [
    ('1', 'Import', 'Add videos, images and audio from the Media panel.'),
    ('2', 'Arrange', 'Drag media onto the timeline, then drag, trim and split clips.'),
    ('3', 'Refine', 'Select a clip to set speed, volume, fades, keyframes and more.'),
    ('4', 'Export', 'Press Export to render an MP4 (480p–4K).'),
  ];

  static const _shortcuts = [
    ('Space', 'Play / pause'),
    ('S', 'Split at playhead'),
    ('Delete', 'Delete clip'),
    ('Shift + Delete', 'Ripple delete'),
    ('← / →', 'Step one frame'),
    ('Home / End', 'Jump to start / end'),
    ('Ctrl/⌘ + Z', 'Undo'),
    ('Ctrl/⌘ + Shift + Z', 'Redo'),
    ('Ctrl/⌘ + C / X / V', 'Copy / cut / paste clip'),
    ('Ctrl/⌘ + D', 'Duplicate clip'),
    ('Ctrl/⌘ + scroll', 'Zoom timeline'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedText);

    return AlertDialog(
      title: Text(welcome ? 'Welcome to Tayang' : 'Help & shortcuts'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (welcome) ...[
                for (final (number, title, text) in _steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: AppColors.accent,
                          child: Text(
                            number,
                            style: const TextStyle(fontSize: 12, color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: '$title  ',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(text: text),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 28),
              ],
              Text('Keyboard shortcuts', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final (keys, action) in _shortcuts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(width: 190, child: Text(keys, style: muted)),
                      Expanded(child: Text(action)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(welcome ? 'Get started' : 'Close'),
        ),
      ],
    );
  }
}

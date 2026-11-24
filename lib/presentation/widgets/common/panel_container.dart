import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Titled surface used by every dock panel.
class PanelContainer extends StatelessWidget {
  const PanelContainer({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: Row(
                children: [
                  Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          letterSpacing: 1,
                          color: AppColors.mutedText,
                        ),
                  ),
                  const Spacer(),
                  ...actions,
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

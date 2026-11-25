import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.size = 20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        foregroundColor: selected ? AppColors.accent : null,
      ),
    );
  }
}

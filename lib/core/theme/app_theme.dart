import 'package:flutter/material.dart';

import '../../domain/models/clip.dart';

abstract final class AppColors {
  static const background = Color(0xFF0E1015);
  static const surface = Color(0xFF161920);
  static const surfaceHigh = Color(0xFF1E222B);
  static const outline = Color(0xFF2A2F3A);
  static const accent = Color(0xFF7C9CFF);
  static const playhead = Color(0xFFFF5C6C);
  static const mutedText = Color(0xFF8B93A5);

  static Color forClip(ClipKind kind) => switch (kind) {
        ClipKind.video => const Color(0xFF3E6BD6),
        ClipKind.audio => const Color(0xFF2E9E78),
        ClipKind.image => const Color(0xFF8A5BD1),
        ClipKind.text => const Color(0xFFD28A2B),
      };
}

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accent,
      surface: AppColors.surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.outline,
      dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
    );
  }
}

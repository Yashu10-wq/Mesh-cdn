import 'package:flutter/material.dart';

class AppColors {
  // ── Neutral Zinc Foundation (like Linear/GitHub dark mode) ──────────────────
  static const bg0   = Color(0xFF09090B); // Almost black - terminal, deepest bg
  static const bg1   = Color(0xFF0F0F12); // True scaffold bg
  static const bg2   = Color(0xFF18181B); // Cards, sidebar panels
  static const bg3   = Color(0xFF1F1F23); // Hover / elevated surfaces
  static const bg4   = Color(0xFF27272A); // Active pressed, borders (dark)

  // ── Borders & Separators ────────────────────────────────────────────────────
  static const border1 = Color(0xFF27272A); // Default subtle border
  static const border2 = Color(0xFF3F3F46); // Focus / hover border

  // ── Typography ──────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFFFAFAFA); // Near-white for headings
  static const textSecondary = Color(0xFFA1A1AA); // Zinc-400 for body
  static const textMuted     = Color(0xFF71717A); // Zinc-500 for labels/captions
  static const textDisabled  = Color(0xFF52525B); // Zinc-600

  // ── Signature Accent: Electric Indigo (single primary accent) ───────────────
  static const accent        = Color(0xFF6366F1); // Indigo-500
  static const accentLight   = Color(0xFF818CF8); // Indigo-400 (on dark bg)
  static const accentFaint   = Color(0xFF1E1E38); // Indigo tint for backgrounds

  // ── Semantic Colors ─────────────────────────────────────────────────────────
  static const positive      = Color(0xFF22C55E); // Green-500
  static const positiveFaint = Color(0xFF14532D); // Green tint bg
  static const warning       = Color(0xFFF59E0B); // Amber-500
  static const warningFaint  = Color(0xFF422006); // Amber tint bg
  static const danger        = Color(0xFFEF4444); // Red-500
  static const dangerFaint   = Color(0xFF450A0A); // Red tint bg
  static const info          = Color(0xFF38BDF8); // Sky-400

  // ── Status Aliases ───────────────────────────────────────────────────────────
  static const online        = positive;
  static const degraded      = warning;
  static const offline       = textDisabled;
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg1,
    primaryColor: AppColors.accent,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(
      primary:   AppColors.accent,
      secondary: AppColors.accentLight,
      surface:   AppColors.bg2,
      error:     AppColors.danger,
      onPrimary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
    ),
    dividerColor: AppColors.border1,
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.bg4),
      trackColor: WidgetStateProperty.all(Colors.transparent),
      radius: const Radius.circular(4),
      thickness: WidgetStateProperty.all(4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? AppColors.accent : AppColors.textDisabled),
      trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
            ? AppColors.accent.withValues(alpha: 0.3)
            : AppColors.bg4),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../design/app_brand.dart';

/// Semantic colours for the new 7xPlay presentation layer.
///
/// Product identity and personal theme preferences are deliberately separate:
/// primary actions always use the committed 7xPlay amber, while userAccent
/// preserves the viewer's selected/custom/dynamic theme accent when it is
/// readable on the active page.
@immutable
class ExperiencePalette {
  const ExperiencePalette({
    required this.dark,
    required this.page,
    required this.surface,
    required this.raisedSurface,
    required this.foreground,
    required this.secondaryText,
    required this.mutedText,
    required this.hairline,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.secondaryAccent,
    required this.userAccent,
    required this.focusFill,
    required this.onFocus,
    required this.success,
    required this.warning,
    required this.error,
  });

  factory ExperiencePalette.fromTheme(ThemeData theme) {
    final dark = theme.colorScheme.brightness == Brightness.dark;
    final page = theme.scaffoldBackgroundColor;
    final ink = dark ? const Color(0xFFF8F3F8) : const Color(0xFF211923);

    Color lift(double alpha) =>
        Color.alphaBlend(ink.withValues(alpha: alpha), page);

    return ExperiencePalette(
      dark: dark,
      page: page,
      surface: lift(dark ? 0.055 : 0.035),
      raisedSurface: lift(dark ? 0.105 : 0.075),
      foreground: ink,
      secondaryText: _ensureContrast(
        dark ? const Color(0xFFDAD0DD) : const Color(0xFF514653),
        page,
        ink,
      ),
      mutedText: _ensureContrast(
        dark ? const Color(0xFFB8ADBC) : const Color(0xFF615764),
        page,
        ink,
      ),
      hairline: ink.withValues(alpha: dark ? 0.16 : 0.13),
      primaryAction: AppBrand.amber,
      onPrimaryAction: AppBrand.onAmber,
      secondaryAccent: AppBrand.hotPink,
      userAccent: _ensureContrast(theme.colorScheme.primary, page, ink),
      focusFill: ink,
      onFocus: dark ? page : const Color(0xFFFFFAFF),
      success: dark ? const Color(0xFF65D6A3) : const Color(0xFF176B49),
      warning: AppBrand.amber,
      error: _ensureContrast(theme.colorScheme.error, page, ink),
    );
  }

  /// Whether the active Material theme is dark, including AMOLED/ambient
  /// variants whose page colour is supplied by the app theme.
  final bool dark;

  /// Current page canvas. This deliberately comes from ThemeData so seasonal,
  /// ambient, dynamic and custom themes remain authoritative.
  final Color page;

  /// Standard content surface and its raised counterpart.
  final Color surface;
  final Color raisedSurface;

  /// Text roles with readable contrast against page.
  final Color foreground;
  final Color secondaryText;
  final Color mutedText;

  /// Subtle separators and outlines.
  final Color hairline;

  /// Stable 7xPlay brand roles.
  final Color primaryAction;
  final Color onPrimaryAction;
  final Color secondaryAccent;

  /// User-selected, custom, or dynamic theme accent, kept separate from the
  /// product's stable action colour.
  final Color userAccent;

  /// High-contrast focus surface used by touch and remote-control interfaces.
  final Color focusFill;
  final Color onFocus;

  /// Semantic status colours.
  final Color success;
  final Color warning;
  final Color error;

  /// page blended as an overlay at the requested opacity.
  Color scrim(double opacity) =>
      page.withValues(alpha: opacity.clamp(0.0, 1.0).toDouble());

  /// Interpolates semantic roles when Flutter animates between ThemeData
  /// instances (for example, switching between Dark and Light).
  ExperiencePalette lerp(ExperiencePalette other, double t) {
    Color mix(Color first, Color second) => Color.lerp(first, second, t)!;
    return ExperiencePalette(
      dark: t < 0.5 ? dark : other.dark,
      page: mix(page, other.page),
      surface: mix(surface, other.surface),
      raisedSurface: mix(raisedSurface, other.raisedSurface),
      foreground: mix(foreground, other.foreground),
      secondaryText: mix(secondaryText, other.secondaryText),
      mutedText: mix(mutedText, other.mutedText),
      hairline: mix(hairline, other.hairline),
      primaryAction: mix(primaryAction, other.primaryAction),
      onPrimaryAction: mix(onPrimaryAction, other.onPrimaryAction),
      secondaryAccent: mix(secondaryAccent, other.secondaryAccent),
      userAccent: mix(userAccent, other.userAccent),
      focusFill: mix(focusFill, other.focusFill),
      onFocus: mix(onFocus, other.onFocus),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
    );
  }

  static Color _ensureContrast(
    Color candidate,
    Color background,
    Color readableInk,
  ) {
    if (_contrastRatio(candidate, background) >= 4.5) return candidate;

    for (var step = 1; step <= 20; step++) {
      final adjusted = Color.lerp(candidate, readableInk, step / 20)!;
      if (_contrastRatio(adjusted, background) >= 4.5) return adjusted;
    }
    return readableInk;
  }

  static double _contrastRatio(Color foreground, Color background) {
    final first = foreground.computeLuminance();
    final second = background.computeLuminance();
    final lighter = first > second ? first : second;
    final darker = first > second ? second : first;
    return (lighter + 0.05) / (darker + 0.05);
  }
}

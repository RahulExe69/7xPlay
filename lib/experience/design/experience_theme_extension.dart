import 'package:flutter/material.dart';

import 'experience_palette.dart';

/// Makes the experience palette available throughout a themed subtree.
///
/// Existing Material themes remain the source of truth until this extension is
/// installed. That fallback also keeps legacy routes and overlays working
/// while the presentation migration is in progress.
@immutable
class ExperienceThemeExtension
    extends ThemeExtension<ExperienceThemeExtension> {
  const ExperienceThemeExtension({required this.palette});

  final ExperiencePalette palette;

  factory ExperienceThemeExtension.fromTheme(ThemeData theme) =>
      ExperienceThemeExtension(
        palette: ExperiencePalette.fromTheme(theme),
      );

  static ExperienceThemeExtension of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ExperienceThemeExtension>() ??
        ExperienceThemeExtension.fromTheme(theme);
  }

  @override
  ExperienceThemeExtension copyWith({ExperiencePalette? palette}) =>
      ExperienceThemeExtension(palette: palette ?? this.palette);

  @override
  ExperienceThemeExtension lerp(
    covariant ExperienceThemeExtension? other,
    double t,
  ) {
    if (other == null) return this;
    return ExperienceThemeExtension(
      palette: palette.lerp(other.palette, t),
    );
  }
}

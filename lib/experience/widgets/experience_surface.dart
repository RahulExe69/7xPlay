import 'package:flutter/material.dart';

import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';

enum ExperienceSurfaceTone {
  base,
  raised,
  outlined,
  transparent,
}

/// A small semantic container primitive for the new experience UI.
///
/// It owns material/surface semantics, not page layout. Feature screens remain
/// free to arrange their content in distinct compositions.
class ExperienceSurface extends StatelessWidget {
  const ExperienceSurface({
    required this.child,
    this.tone = ExperienceSurfaceTone.base,
    this.padding = const EdgeInsets.all(ExperienceTokens.space4),
    this.borderRadius = const BorderRadius.all(
      Radius.circular(ExperienceTokens.cardRadius),
    ),
    this.color,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final ExperienceSurfaceTone tone;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final Color background = color ??
        switch (tone) {
          ExperienceSurfaceTone.base => palette.surface,
          ExperienceSurfaceTone.raised => palette.raisedSurface,
          ExperienceSurfaceTone.outlined ||
          ExperienceSurfaceTone.transparent =>
            Colors.transparent,
        };
    final BorderSide side = tone == ExperienceSurfaceTone.outlined
        ? BorderSide(color: palette.hairline)
        : BorderSide.none;

    return Semantics(
      container: semanticLabel != null,
      excludeSemantics: semanticLabel != null,
      label: semanticLabel,
      button: onTap != null,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius.resolve(Directionality.of(context)),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

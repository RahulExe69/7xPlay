import 'package:flutter/material.dart';

import '../design/experience_palette.dart';
import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';

/// Artwork frame shared by posters, backdrops and editorial imagery.
class ExperienceArtwork extends StatelessWidget {
  const ExperienceArtwork({
    this.imageProvider,
    this.aspectRatio = 2 / 3,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(ExperienceTokens.compactRadius),
    ),
    this.placeholder,
    this.errorPlaceholder,
    super.key,
  });

  final ImageProvider<Object>? imageProvider;
  final double aspectRatio;
  final BoxFit fit;
  final String? semanticLabel;
  final BorderRadiusGeometry borderRadius;
  final Widget? placeholder;
  final Widget? errorPlaceholder;

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final fallback = _fallback(palette, error: false);
    final failed = _fallback(palette, error: true);

    Widget content;
    if (imageProvider == null) {
      content = placeholder ?? fallback;
    } else {
      content = Image(
        image: imageProvider!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        semanticLabel: semanticLabel,
        errorBuilder: (_, __, ___) => errorPlaceholder ?? failed,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return placeholder ?? fallback;
        },
      );
    }

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: aspectRatio > 0 ? aspectRatio : 2 / 3,
          child: ColoredBox(
            color: palette.raisedSurface,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _fallback(
    ExperiencePalette palette, {
    required bool error,
  }) {
    return Center(
      child: Icon(
        error ? Icons.image_not_supported_outlined : Icons.movie_outlined,
        color: palette.mutedText,
        size: 32,
      ),
    );
  }
}

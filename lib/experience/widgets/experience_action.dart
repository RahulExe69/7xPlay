import 'package:flutter/material.dart';

import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';

enum ExperienceActionTone {
  primary,
  secondary,
  quiet,
  destructive,
}

/// A consistent, accessible action control for experience-owned screens.
class ExperienceAction extends StatelessWidget {
  const ExperienceAction({
    required this.label,
    required this.onPressed,
    this.tone = ExperienceActionTone.primary,
    this.leading,
    this.isLoading = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ExperienceActionTone tone;
  final Widget? leading;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final (background, foreground, border) = switch (tone) {
      ExperienceActionTone.primary => (
          palette.primaryAction,
          palette.onPrimaryAction,
          BorderSide.none,
        ),
      ExperienceActionTone.secondary => (
          palette.raisedSurface,
          palette.foreground,
          BorderSide(color: palette.hairline),
        ),
      ExperienceActionTone.quiet => (
          Colors.transparent,
          palette.foreground,
          BorderSide.none,
        ),
      ExperienceActionTone.destructive => (
          palette.error,
          Colors.white,
          BorderSide.none,
        ),
    };

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.42),
        disabledForegroundColor: foreground.withValues(alpha: 0.68),
        elevation: 0,
        minimumSize: Size(expand ? double.infinity : 0, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: ExperienceTokens.space5,
          vertical: ExperienceTokens.space3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ExperienceTokens.compactRadius),
          side: border,
        ),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          else if (leading != null)
            leading!,
          if (isLoading || leading != null)
            const SizedBox(width: ExperienceTokens.space2),
          Text(label),
        ],
      ),
    );

    return expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

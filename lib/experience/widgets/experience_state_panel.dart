import 'package:flutter/material.dart';

import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';
import 'experience_action.dart';

enum ExperienceStateKind {
  loading,
  empty,
  error,
  offline,
}

/// Feature-level loading, empty, failure and offline presentation.
class ExperienceStatePanel extends StatelessWidget {
  const ExperienceStatePanel({
    required this.kind,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.compact = false,
    super.key,
  });

  final ExperienceStateKind kind;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final stateIcon = icon ?? switch (kind) {
      ExperienceStateKind.loading => null,
      ExperienceStateKind.empty => Icons.inbox_outlined,
      ExperienceStateKind.error => Icons.error_outline_rounded,
      ExperienceStateKind.offline => Icons.cloud_off_outlined,
    };

    return Semantics(
      liveRegion: kind == ExperienceStateKind.loading,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(
            compact ? ExperienceTokens.space4 : ExperienceTokens.space8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kind == ExperienceStateKind.loading)
                SizedBox.square(
                  dimension: compact ? 28 : 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.primaryAction,
                  ),
                )
              else
                Icon(
                  stateIcon,
                  size: compact ? 30 : 42,
                  color: kind == ExperienceStateKind.error
                      ? palette.error
                      : palette.mutedText,
                ),
              const SizedBox(height: ExperienceTokens.space4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: palette.foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: ExperienceTokens.space2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(
                    description!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.secondaryText,
                        ),
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: ExperienceTokens.space5),
                ExperienceAction(
                  label: actionLabel!,
                  onPressed: onAction,
                  tone: kind == ExperienceStateKind.error
                      ? ExperienceActionTone.primary
                      : ExperienceActionTone.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

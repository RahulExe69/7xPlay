import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/experience_theme_extension.dart';
import '../design/experience_tokens.dart';
import '../../mobile/app/mobile_tabs.dart';

/// New destination navigation for the clean-slate mobile presentation.
///
/// Unlike the legacy floating dock, this is a compact, persistent destination
/// system: a low-profile bottom strip on phones and a full-height rail on
/// wide layouts. Destination IDs remain owned by [MobileTab].
class ExperienceNavigation extends StatelessWidget {
  const ExperienceNavigation({
    required this.current,
    required this.onSelect,
    this.rail = false,
    super.key,
  });

  final MobileTab current;
  final ValueChanged<MobileTab> onSelect;
  final bool rail;

  static const double railWidth = 92;

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (rail) {
      return SizedBox(
        width: railWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            border: BorderDirectional(
              end: BorderSide(color: palette.hairline),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: ExperienceTokens.space4),
                Text(
                  '7x',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: palette.primaryAction,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                ),
                const SizedBox(height: ExperienceTokens.space5),
                Container(height: 1, color: palette.hairline),
                const SizedBox(height: ExperienceTokens.space4),
                for (final tab in MobileTab.values)
                  _DestinationItem(
                    tab: tab,
                    selected: tab == current,
                    rail: true,
                    reduceMotion: reduceMotion,
                    onTap: () => onSelect(tab),
                  ),
                const Spacer(),
                Text(
                  'PLAY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.mutedText,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: ExperienceTokens.space4),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        ExperienceTokens.space3,
        ExperienceTokens.space2,
        ExperienceTokens.space3,
        ExperienceTokens.space3,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(ExperienceTokens.heroRadius),
          border: Border.all(color: palette.hairline),
        ),
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (final tab in MobileTab.values)
                Expanded(
                  child: _DestinationItem(
                    tab: tab,
                    selected: tab == current,
                    rail: false,
                    reduceMotion: reduceMotion,
                    onTap: () => onSelect(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationItem extends StatelessWidget {
  const _DestinationItem({
    required this.tab,
    required this.selected,
    required this.rail,
    required this.reduceMotion,
    required this.onTap,
  });

  final MobileTab tab;
  final bool selected;
  final bool rail;
  final bool reduceMotion;
  final VoidCallback onTap;

  static const _labels = <MobileTab, String>{
    MobileTab.home: 'Home',
    MobileTab.newAndHot: 'New',
    MobileTab.discover: 'Explore',
    MobileTab.search: 'Search',
    MobileTab.mine: 'My space',
  };

  static const _icons = <MobileTab, IconData>{
    MobileTab.home: Icons.home_rounded,
    MobileTab.newAndHot: Icons.local_fire_department_rounded,
    MobileTab.discover: Icons.explore_rounded,
    MobileTab.search: Icons.search_rounded,
    MobileTab.mine: Icons.video_library_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final palette = ExperienceThemeExtension.of(context).palette;
    final label = _labels[tab]!;
    final icon = _icons[tab]!;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: rail ? label : '',
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(ExperienceTokens.heroRadius),
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.all(rail ? 6 : 4),
            padding: EdgeInsets.symmetric(
              horizontal: rail ? 4 : 2,
              vertical: rail ? 12 : 6,
            ),
            decoration: BoxDecoration(
              color: selected ? palette.raisedSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(ExperienceTokens.heroRadius),
              border: selected
                  ? Border.all(
                      color: palette.primaryAction.withValues(alpha: .34),
                    )
                  : null,
            ),
            child: rail
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 23,
                        color: selected
                            ? palette.primaryAction
                            : palette.mutedText,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: selected
                                  ? palette.foreground
                                  : palette.mutedText,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w500,
                            ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 21,
                        color: selected
                            ? palette.primaryAction
                            : palette.mutedText,
                      ),
                      if (selected) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: palette.foreground,
                                      fontWeight: FontWeight.w800,
                                    ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

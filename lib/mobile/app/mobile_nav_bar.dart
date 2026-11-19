import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import 'mobile_tabs.dart';

/// Edge-to-edge five-destination navigation. A restrained translucent surface
/// keeps the content and destination controls visually connected.
class MobileNavBar extends StatelessWidget {
  const MobileNavBar({
    required this.current,
    required this.onSelect,
    super.key,
  });

  final MobileTab current;
  final ValueChanged<MobileTab> onSelect;

  static const height = 68.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.page.withValues(alpha: .94),
            border: Border(
              top: BorderSide(color: palette.hairline),
            ),
          ),
          child: Padding(
            // Paint the same surface behind Android's gesture/navigation
            // inset while keeping the five destinations above that inset.
            padding: EdgeInsets.only(bottom: media.padding.bottom),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: media.padding.left,
                  end: media.padding.right,
                ),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.2,
                  child: Row(
                    children: <Widget>[
                      for (final tab in MobileTab.values)
                        Expanded(
                          child: _DockItem(
                            tab: tab,
                            selected: tab == current,
                            reduceMotion: reduceMotion,
                            onTap: () => onSelect(tab),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tablet rail uses the same destinations but a different composition.
class MobileNavRail extends StatelessWidget {
  const MobileNavRail({
    required this.current,
    required this.onSelect,
    super.key,
  });

  final MobileTab current;
  final ValueChanged<MobileTab> onSelect;

  static const width = 88.0;
  static const _itemHeight = 70.0;

  static double extentOf(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return width + (rtl ? padding.right : padding.left);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final padding = MediaQuery.paddingOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: extentOf(context),
      child: ColoredBox(
        color: palette.page,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: rtl ? padding.right : padding.left,
            top: padding.top + 14,
            bottom: padding.bottom + 12,
          ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Image.asset(
                    'assets/images/7xplay_wordmark.png',
                    width: 76,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      '7xPlay',
                      style: AppType.sectionHeader.copyWith(
                        color: palette.foreground,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(height: 1, color: palette.hairline),
                const SizedBox(height: 12),
                for (final tab in MobileTab.values)
                  SizedBox(
                    width: width,
                    height: _itemHeight,
                    child: _RailItem(
                      tab: tab,
                      selected: tab == current,
                      reduceMotion: reduceMotion,
                      onTap: () => onSelect(tab),
                    ),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '7X',
                    style: AppType.kicker.copyWith(
                      color: palette.mutedText.withValues(alpha: .7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

(IconData, IconData, String) _lookFor(MobileTab tab) => switch (tab) {
      MobileTab.home => (
          PhosphorIcons.house(),
          PhosphorIcons.house(PhosphorIconsStyle.fill),
          'home',
        ),
      MobileTab.newAndHot => (
          PhosphorIcons.fire(),
          PhosphorIcons.fire(PhosphorIconsStyle.fill),
          'new_and_hot',
        ),
      MobileTab.discover => (
          PhosphorIcons.compass(),
          PhosphorIcons.compass(PhosphorIconsStyle.fill),
          'discover',
        ),
      MobileTab.search => (
          PhosphorIcons.magnifyingGlass(),
          PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
          'search',
        ),
      MobileTab.mine => (
          PhosphorIcons.userCircle(),
          PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
          'my_flixquest',
        ),
    };

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.tab,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
  });

  final MobileTab tab;
  final bool selected;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (icon, selectedIcon, labelKey) = _lookFor(tab);
    return Semantics(
      button: true,
      selected: selected,
      label: tr(labelKey),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  selected ? selectedIcon : icon,
                  size: selected ? 24 : 22,
                  color: selected ? palette.foreground : palette.mutedText,
                ),
                const SizedBox(height: 3),
                Text(
                  tr(labelKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: selected ? AppType.semiBold : AppType.regular,
                    fontSize: 10.5,
                    height: 13 / 10.5,
                    color: selected ? palette.foreground : palette.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.tab,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
  });

  final MobileTab tab;
  final bool selected;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (icon, selectedIcon, labelKey) = _lookFor(tab);
    return Semantics(
      button: true,
      selected: selected,
      label: tr(labelKey),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          margin: const EdgeInsetsDirectional.fromSTEB(7, 5, 7, 5),
          decoration: BoxDecoration(
            color: selected
                ? palette.idleFillFaint
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                selected ? selectedIcon : icon,
                size: 23,
                color: selected ? palette.foreground : palette.mutedText,
              ),
              const SizedBox(height: 4),
              Text(
                tr(labelKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppType.semiBold,
                  fontSize: 10,
                  color: selected ? palette.accent : palette.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

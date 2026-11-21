import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../design/app_brand.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import 'mobile_tabs.dart';

/// A familiar browse-first order while preserving the enum's stable IDs.
const _navigationOrder = <MobileTab>[
  MobileTab.home,
  MobileTab.discover,
  MobileTab.newAndHot,
  MobileTab.search,
  MobileTab.mine,
];

/// The phone's edge-to-edge destination dock, retaining all stable navigation IDs.
class MobileNavBar extends StatelessWidget {
  const MobileNavBar({required this.current, required this.onSelect, super.key});
  final MobileTab current;
  final ValueChanged<MobileTab> onSelect;
  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final media = MediaQuery.of(context);
    return DecoratedBox(
      key: const ValueKey<String>('mobile-nav-surface'),
      decoration: BoxDecoration(
        color: palette.page,
        borderRadius: BorderRadius.zero,
        border: Border(
          top: BorderSide(color: palette.hairline, width: .7),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: media.padding.bottom),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: Row(
                children: <Widget>[
                  for (final tab in _navigationOrder)
                    Expanded(
                      child: _DockItem(
                        tab: tab,
                        selected: tab == current,
                        reduceMotion: media.disableAnimations,
                        onTap: () => onSelect(tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tablet navigation uses a vertical rail with the same product destinations.
class MobileNavRail extends StatelessWidget {
  const MobileNavRail({required this.current, required this.onSelect, super.key});
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
                      style: AppType.sectionHeader.copyWith(color: palette.foreground),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: palette.hairline,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
  MobileTab.home => (PhosphorIcons.house(), PhosphorIcons.house(PhosphorIconsStyle.fill), 'home'),
  MobileTab.newAndHot => (PhosphorIcons.fire(), PhosphorIcons.fire(PhosphorIconsStyle.fill), 'new_and_hot'),
  MobileTab.discover => (PhosphorIcons.compass(), PhosphorIcons.compass(PhosphorIconsStyle.fill), 'discover'),
  MobileTab.search => (PhosphorIcons.magnifyingGlass(), PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), 'search'),
  MobileTab.mine => (PhosphorIcons.userCircle(), PhosphorIcons.userCircle(PhosphorIconsStyle.fill), 'you'),
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
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
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
                  fontSize: 10,
                  height: 1.15,
                  color: selected ? palette.foreground : palette.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.tab, required this.selected, required this.reduceMotion, required this.onTap});
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
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsetsDirectional.fromSTEB(7, 5, 7, 5),
          decoration: BoxDecoration(
            color: selected ? palette.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: selected ? Border.all(color: palette.hairline) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(selected ? selectedIcon : icon,
                size: 23,
                color: selected ? palette.foreground : palette.mutedText),
              const SizedBox(height: 4),
              Text(
                tr(labelKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppType.semiBold,
                  fontSize: 10,
                  color: selected ? palette.foreground : palette.mutedText,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                width: selected ? 16 : 4,
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: selected ? AppBrand.amber : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

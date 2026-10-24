import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The verified-account tick an admin grants, after a name, in the app's
/// own colour (the theme's accent, or the colour the viewer picked). It pops
/// in once when it first appears.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({this.size = 18, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final colors = Theme.of(context).colorScheme;
    final badge = Tooltip(
      message: tr('verified_account'),
      child: Semantics(
        label: tr('verified_account'),
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // A disc behind the seal's cut-out tick, so the tick reads in
              // the colour made for text on the accent, on any page.
              Container(
                width: size * .5,
                height: size * .5,
                decoration: BoxDecoration(
                  color: colors.onPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                size: size,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
    if (still) return badge;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: .4, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: badge,
    );
  }
}

import 'dart:math' as math;

import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/design/app_brand.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) /
      (math.min(first, second) + 0.05);
}

void main() {
  test('default theme modes use the 7xCinema gold with readable ink', () {
    final colors = AppColorsList();
    final themes = <ThemeData>[
      darkThemeData(true, null, colors.appColors(true).first),
      lightThemeData(true, null, colors.appColors(false).first),
      lightsOutThemeData(true, null, colors.appColors(true).first),
    ];

    for (final theme in themes) {
      expect(theme.colorScheme.primary, AppBrand.cinemaGold);
      expect(theme.colorScheme.onPrimary, AppBrand.cinemaOnGold);
      expect(
        _contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(7),
      );
    }
  });
}

import 'package:flutter/material.dart';

/// 7xPlay's visual identity, taken from the committed product artwork in the
/// 7x Brand Hub. The artwork—not the draft directional token file—is the
/// source of truth: gold/orange/red for the 7 and play mark, hot pink/violet
/// for the X, all on a near-black cinematic canvas.
abstract final class AppBrand {
  static const amber = Color(0xFFFFB91D);
  static const onAmber = Color(0xFF2D1608);
  static const amberContainerDark = Color(0xFF63300B);
  static const onAmberContainerDark = Color(0xFFFFE8C0);
  static const amberContainerLight = Color(0xFFFFF0D7);
  static const onAmberContainerLight = Color(0xFF40200B);

  static const orange = Color(0xFFFF482E);
  static const deepOrange = Color(0xFFD92D35);
  static const hotPink = Color(0xFFEF2495);
  static const deepPink = Color(0xFFB80D72);
  static const violet = Color(0xFF8E2BFF);
  static const deepViolet = Color(0xFF5D18B5);

  static const background = Color(0xFF09050B);
  static const surface = Color(0xFF160B16);
  static const raisedSurface = Color(0xFF241222);
  static const surfaceContainerDark = Color(0xFF4B173B);
  static const onSurfaceContainerDark = Color(0xFFFFD9E7);
  static const surfaceContainerLight = Color(0xFFFFE5ED);
  static const onSurfaceContainerLight = Color(0xFF481326);

  // Compatibility names retained while existing screens migrate to semantic
  // names. They now resolve to the artwork-derived palette.
  static const cinemaGold = amber;
  static const cinemaOnGold = onAmber;
  static const cinemaGoldContainerDark = amberContainerDark;
  static const cinemaOnGoldContainerDark = onAmberContainerDark;
  static const cinemaGoldContainerLight = amberContainerLight;
  static const cinemaOnGoldContainerLight = onAmberContainerLight;
  static const cinemaSecondaryContainerLight = Color(0xFFFFE5DF);
  static const ember = orange;
  static const emberDeep = deepOrange;
  static const magenta = hotPink;
  static const magentaDeep = deepPink;
  static const wine = background;
  static const wineSurface = surface;
  static const wineRaised = raisedSurface;
  static const wineContainerDark = surfaceContainerDark;
  static const onWineContainerDark = onSurfaceContainerDark;
  static const wineContainerLight = surfaceContainerLight;
  static const onWineContainerLight = onSurfaceContainerLight;
}

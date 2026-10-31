import 'package:flutter/material.dart';

/// Product colours for 7xPlay, following the 7xCinema direction in the
/// shared 7x brand repository. Keep the amber identity as an accent; artwork
/// and neutral surfaces should carry the visual weight, not glowing panels.
abstract final class AppBrand {
  static const cinemaGold = Color(0xFFFFC247);
  static const cinemaOnGold = Color(0xFF2B1D08);
  static const cinemaGoldContainerDark = Color(0xFF5B3E12);
  static const cinemaOnGoldContainerDark = Color(0xFFFFE8B8);
  static const cinemaGoldContainerLight = Color(0xFFFFF0D0);
  static const cinemaOnGoldContainerLight = Color(0xFF3D290C);
  static const cinemaSecondaryContainerLight = Color(0xFFF7E8CE);
}

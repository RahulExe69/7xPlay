import 'package:flutter/material.dart';

/// Layout and motion constants for the new 7xPlay experience.
///
/// These are intentionally independent from the legacy AppSpace/AppRadii
/// values so new screen composition can evolve without inheriting old page
/// geometry.
abstract final class ExperienceTokens {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;

  static const double phoneGutter = 20;
  static const double tabletGutter = 32;
  static const double contentMaxWidth = 1440;

  static const double compactRadius = 10;
  static const double cardRadius = 18;
  static const double heroRadius = 26;
  static const double sheetRadius = 28;

  static const double tabletBreakpoint = 700;
  static const double wideBreakpoint = 1000;
  static const double tvBreakpoint = 1280;

  static const Duration motionFast = Duration(milliseconds: 140);
  static const Duration motionStandard = Duration(milliseconds: 220);
  static const Duration motionEmphasized = Duration(milliseconds: 340);

  static const Curve motionCurve = Curves.easeOutCubic;
  static const Curve enterCurve = Curves.easeOutQuart;
}

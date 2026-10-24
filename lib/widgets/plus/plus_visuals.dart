import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// FlixQuest Plus's own look. Like artwork, it keeps fixed colours in every
/// theme (a night sky with a warm aurora), so it never borrows the app's
/// accent and reads the same on Dark, AMOLED, Light and the TV.
abstract final class PlusColors {
  static const night = Color(0xFF0B0A12);
  static const dusk = Color(0xFF1B1430);
  static const gold = Color(0xFFFFC56B);
  static const amber = Color(0xFFFF9F43);
  static const coral = Color(0xFFFF6A5C);
  static const violet = Color(0xFF7C5CFF);
  static const teal = Color(0xFF34D1BF);
  static const ink = Color(0xFFF8F6FF);
  static const mutedInk = Color(0xB3F8F6FF);
  static const glass = Color(0x1FFFFFFF);
  static const glassStrong = Color(0x33FFFFFF);

  static const goldSheen = <Color>[
    Color(0xFFFFE3A8),
    gold,
    amber,
    Color(0xFFFFE3A8),
  ];
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A slowly drifting aurora behind [child]. [energy] above 1 brightens it
/// for a moment of celebration; reduced motion holds it still.
class PlusAurora extends StatefulWidget {
  const PlusAurora({
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.energy = 1,
    this.period = const Duration(seconds: 16),
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double energy;
  final Duration period;

  @override
  State<PlusAurora> createState() => _PlusAuroraState();
}

class _PlusAuroraState extends State<PlusAurora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: widget.borderRadius,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _AuroraPainter(_drift, widget.energy),
            child: widget.child,
          ),
        ),
      );
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.drift, this.energy) : super(repaint: drift);

  final Animation<double> drift;
  final double energy;

  static const _blobs = <(Color, double, double, double, double)>[
    // colour, x phase, y phase, radius share, alpha
    (PlusColors.amber, 0.0, 0.3, 0.78, 0.55),
    (PlusColors.violet, 1.7, 2.1, 0.9, 0.6),
    (PlusColors.coral, 3.4, 0.9, 0.6, 0.42),
    (PlusColors.teal, 5.1, 4.2, 0.55, 0.28),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[PlusColors.dusk, PlusColors.night],
        ).createShader(rect),
    );
    final t = drift.value * 2 * math.pi;
    final span = math.max(size.width, size.height);
    for (final (color, px, py, share, alpha) in _blobs) {
      final center = Offset(
        size.width * (0.5 + 0.42 * math.sin(t + px)),
        size.height * (0.5 + 0.38 * math.cos(t * 0.8 + py)),
      );
      final radius = span * share;
      final strength = (alpha * energy).clamp(0.0, 0.95);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: <Color>[
            color.withValues(alpha: strength),
            color.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    // A fine grain of stars keeps the gradient from banding.
    final stars = Paint()..color = Colors.white.withValues(alpha: .35);
    final random = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final twinkle = (math.sin(t * 2 + i) + 1) / 2;
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width,
            random.nextDouble() * size.height),
        0.6 + twinkle * 0.7,
        stars..color = Colors.white.withValues(alpha: .12 + twinkle * .3),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.energy != energy || oldDelegate.drift != drift;
}

/// A light sweep across [child] every few seconds, like foil catching light.
class PlusSheen extends StatefulWidget {
  const PlusSheen({
    required this.child,
    this.every = const Duration(milliseconds: 4800),
    this.colors = PlusColors.goldSheen,
    super.key,
  });

  final Widget child;
  final Duration every;
  final List<Color> colors;

  @override
  State<PlusSheen> createState() => _PlusSheenState();
}

class _PlusSheenState extends State<PlusSheen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: widget.every);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _sweep.value = 0;
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _sweep,
        child: widget.child,
        builder: (context, child) {
          // The sweep crosses in the first third, then the foil rests.
          final travel = Curves.easeInOut
              .transform((_sweep.value * 3).clamp(0.0, 1.0).toDouble());
          final shift = -1.2 + travel * 2.4;
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(shift - 1, -0.3),
              end: Alignment(shift + 1, 0.3),
              colors: <Color>[
                widget.colors[1],
                widget.colors[0],
                Colors.white,
                widget.colors[0],
                widget.colors[2],
              ],
              stops: const <double>[0, .38, .5, .62, 1],
            ).createShader(bounds),
            child: child,
          );
        },
      );
}

/// "FlixQuest PLUS", the PLUS in gold foil.
class PlusWordmark extends StatelessWidget {
  const PlusWordmark({this.size = 30, this.showName = true, super.key});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) => Directionality(
        // A brand mark; it reads the same way in Arabic.
        textDirection: TextDirection.ltr,
        // Shrinks rather than overflows beside a ring or on a narrow phone.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (showName) ...<Widget>[
                Text(
                  'FlixQuest',
                  style: TextStyle(
                    fontFamily: 'FigtreeBold',
                    fontSize: size * .62,
                    height: 1,
                    letterSpacing: -.4,
                    color: PlusColors.ink,
                  ),
                ),
                SizedBox(width: size * .22),
              ],
              PlusSheen(
                child: Text(
                  'PLUS',
                  style: TextStyle(
                    fontFamily: 'FigtreeBlack',
                    fontSize: size,
                    height: 1,
                    letterSpacing: size * .08,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// The FlixQuest outline mark with a plus beside its wedge: Plus's own
/// symbol. Takes the surrounding icon colour and size unless given them.
class PlusMark extends StatelessWidget {
  const PlusMark({this.size, this.color, super.key});

  static const asset = 'assets/images/fq_plus.svg';

  /// The mark's height; it is a little narrower than tall.
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icons = IconTheme.of(context);
    final height = size ?? icons.size ?? 24;
    return SizedBox.square(
      dimension: height,
      child: Center(
        child: SvgPicture.asset(
          asset,
          height: height,
          excludeFromSemantics: true,
          colorFilter: ColorFilter.mode(
              color ?? icons.color ?? const Color(0xFFFFFFFF), BlendMode.srcIn),
        ),
      ),
    );
  }
}

/// The round Plus emblem: the Plus mark in a gold ring that breathes.
class PlusEmblem extends StatefulWidget {
  const PlusEmblem({this.size = 56, super.key});

  final double size;

  @override
  State<PlusEmblem> createState() => _PlusEmblemState();
}

class _PlusEmblemState extends State<PlusEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _breath.value = .5;
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final glow = Curves.easeInOut.transform(_breath.value);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(colors: <Color>[
              PlusColors.gold,
              PlusColors.coral,
              PlusColors.violet,
              PlusColors.teal,
              PlusColors.gold,
            ]),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: PlusColors.amber.withValues(alpha: .25 + glow * .3),
                blurRadius: size * (.25 + glow * .25),
              ),
            ],
          ),
          padding: EdgeInsets.all(size * .06),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PlusColors.night,
            ),
            alignment: Alignment.center,
            child: PlusSheen(
              child: PlusMark(size: size * .54, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

/// How much of the paid stretch is left, as a gold arc around [child].
class PlusPeriodRing extends StatelessWidget {
  const PlusPeriodRing({
    required this.used,
    required this.child,
    this.size = 92,
    this.stroke = 6,
    super.key,
  });

  /// 0 when the period has just started, 1 when it ends.
  final double used;
  final Widget child;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: (1 - used).clamp(0.0, 1.0)),
        duration: _reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (context, left, child) => CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(left, stroke),
          child: SizedBox.square(
            dimension: size,
            child: Center(child: child),
          ),
        ),
        child: child,
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.left, this.stroke);

  final double left;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = PlusColors.glass,
    );
    if (left <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      2 * math.pi * left,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: <Color>[PlusColors.gold, PlusColors.coral, PlusColors.gold],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.left != left || oldDelegate.stroke != stroke;
}

/// A small glassy chip on Plus surfaces ("Auto-renew on", "$8.00").
class PlusChip extends StatelessWidget {
  const PlusChip({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: PlusColors.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PlusColors.glassStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: PlusColors.ink),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'FigtreeSB',
                  fontSize: 12,
                  height: 1.2,
                  color: PlusColors.ink,
                ),
              ),
            ),
          ],
        ),
      );
}

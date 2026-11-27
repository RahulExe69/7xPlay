import 'package:flutter/material.dart';

/// 7x AI's monogram: a geometric 7 with the same folded, outlined language
/// as the previous assistant mark, finished with two four-point sparks.
///
/// Its default ink follows the active theme: dark on light surfaces and
/// white on dark surfaces. Callers may provide an explicit semantic colour.
class SevenXAiMark extends StatefulWidget {
  const SevenXAiMark({
    required this.height,
    this.color,
    this.thinking = false,
    super.key,
  });

  final double height;
  final Color? color;
  final bool thinking;

  static const aspectRatio =
      SevenXAiMarkPainter.width / SevenXAiMarkPainter.height;

  @override
  State<SevenXAiMark> createState() => _SevenXAiMarkState();
}

class _SevenXAiMarkState extends State<SevenXAiMark>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SevenXAiMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.thinking) {
      _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    } else {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = widget.color ??
        (theme.colorScheme.brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF141516));
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.height * SevenXAiMark.aspectRatio,
        height: widget.height,
        child: CustomPaint(
          painter: SevenXAiMarkPainter(
            color: ink,
            pulse: _pulse,
            stroke: widget.height < 40 ? 30 : 24,
          ),
        ),
      ),
    );
  }
}

/// Exposed so the light/dark icon contract can be verified in widget tests.
class SevenXAiMarkPainter extends CustomPainter {
  SevenXAiMarkPainter({
    required this.color,
    required this.stroke,
    this.pulse,
  }) : super(repaint: pulse);

  final Color color;
  final double stroke;
  final Animation<double>? pulse;

  static const width = 383.0;
  static const height = 427.0;

  /// The upper cap and diagonal leg form a clear 7 from folded ribbon shapes.
  static final _mark = <Path>[
    Path()
      ..moveTo(34, 66)
      ..lineTo(302, 66)
      ..lineTo(350, 94)
      ..lineTo(323, 120)
      ..lineTo(34, 120)
      ..close(),
    Path()
      ..moveTo(289, 108)
      ..lineTo(344, 141)
      ..lineTo(185, 391)
      ..lineTo(121, 391)
      ..lineTo(100, 368)
      ..close(),
  ];

  static const _sparks = <(Offset, double)>[
    (Offset(333, 267), 62),
    (Offset(256, 357), 30),
  ];

  static Path _spark(Offset centre, double radius) => Path()
    ..moveTo(centre.dx, centre.dy - radius)
    ..quadraticBezierTo(centre.dx, centre.dy, centre.dx + radius, centre.dy)
    ..quadraticBezierTo(centre.dx, centre.dy, centre.dx, centre.dy + radius)
    ..quadraticBezierTo(centre.dx, centre.dy, centre.dx - radius, centre.dy)
    ..quadraticBezierTo(centre.dx, centre.dy, centre.dx, centre.dy - radius)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.height / height);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;
    for (final part in _mark) {
      canvas.drawPath(part, line);
    }

    final t = pulse?.value;
    for (var index = 0; index < _sparks.length; index++) {
      final (centre, reach) = _sparks[index];
      final strength = t == null
          ? 1.0
          : Curves.easeInOut.transform(
              1 - ((t - index * .5) % 1 - .5).abs() * 2,
            );
      canvas.drawPath(
        _spark(centre, reach * (t == null ? 1 : .7 + .3 * strength)),
        Paint()
          ..color = color.withValues(
            alpha: color.a * (t == null ? 1 : .35 + .65 * strength),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(SevenXAiMarkPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.stroke != stroke ||
      oldDelegate.pulse != pulse;
}

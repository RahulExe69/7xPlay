import 'package:flutter/widgets.dart';

/// FlixAI's mark: the FlixQuest outline mark, untouched, with two sparks
/// beside it. While [thinking], the sparks twinkle in turn.
///
/// Drawn in [color], or the ambient [IconTheme]'s, so it sits in an
/// [IconButton] like any icon.
class FlixAiMark extends StatefulWidget {
  const FlixAiMark({
    required this.height,
    this.color,
    this.thinking = false,
    super.key,
  });

  final double height;
  final Color? color;
  final bool thinking;

  static const aspectRatio = _MarkPainter.width / _MarkPainter.height;

  @override
  State<FlixAiMark> createState() => _FlixAiMarkState();
}

class _FlixAiMarkState extends State<FlixAiMark>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(FlixAiMark oldWidget) {
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
    final color =
        widget.color ?? IconTheme.of(context).color ?? const Color(0xFFFFFFFF);
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.height * FlixAiMark.aspectRatio,
        height: widget.height,
        child: CustomPaint(
          painter: _MarkPainter(
            color: color,
            pulse: _pulse,
            // Thin strokes vanish at icon sizes, so small marks draw bolder.
            stroke: widget.height < 40 ? 30 : 24,
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.color, required this.stroke, this.pulse})
      : super(repaint: pulse);

  final Color color;
  final double stroke;
  final Animation<double>? pulse;

  /// The drawing's box, in the outline mark's own units
  /// (assets/images/fq_svg.svg): the mark plus the sparks to its right.
  static const _origin = Offset(4, 5);
  static const width = 383.0;
  static const height = 427.0;

  static final _mark = <Path>[
    Path()
      ..moveTo(16, 123.8)
      ..lineTo(200, 17.5)
      ..lineTo(263.1, 54)
      ..lineTo(16, 196.7)
      ..close(),
    Path()
      ..moveTo(16, 255.8)
      ..lineTo(162, 171.5)
      ..lineTo(225.1, 207.9)
      ..lineTo(16, 328.7)
      ..close(),
    Path()
      ..moveTo(26, 380)
      ..lineTo(94, 340.7)
      ..lineTo(94, 419.3)
      ..close(),
  ];

  /// Centre and reach of each spark: a large one beside the lower band, a
  /// small one beside the wedge.
  static const _sparks = <(Offset, double)>[
    (Offset(325, 282), 62),
    (Offset(252, 357), 30),
  ];

  /// A four-pointed spark whose sides curve in to its centre.
  static Path _spark(Offset c, double r) => Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(size.height / height)
      ..translate(-_origin.dx, -_origin.dy);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;
    for (final part in _mark) {
      canvas.drawPath(part, line);
    }
    final t = pulse?.value;
    for (var i = 0; i < _sparks.length; i++) {
      final (centre, reach) = _sparks[i];
      // Each spark swells and brightens half a beat after the other.
      final strength = t == null
          ? 1.0
          : Curves.easeInOut.transform(1 - ((t - i * .5) % 1 - .5).abs() * 2);
      canvas.drawPath(
        _spark(centre, reach * (t == null ? 1 : .7 + .3 * strength)),
        Paint()
          ..color = color.withValues(
              alpha: color.a * (t == null ? 1 : .35 + .65 * strength)),
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.stroke != stroke ||
      oldDelegate.pulse != pulse;
}

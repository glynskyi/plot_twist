import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// The needle of a gauge: a pointer from the centre of a polar chart to a
/// [value] of its angle scale.
///
/// ```dart
/// PolarChart(
///   angle: const LinearScale(range: FixedRange(0, 240)),
///   startAngle: 0.75 * math.pi,
///   sweepAngle: 1.5 * math.pi,
///   children: [const ChartPolarAxis.angle(inside: true, tickLength: 6), ChartNeedle(value: speed)],
/// )
/// ```
///
/// A value beyond the scale points at its end. To let the needle swing to a
/// new value, build it in a `TweenAnimationBuilder<double>`.
class ChartNeedle extends StatelessWidget {
  /// Creates a needle that points at [value].
  const ChartNeedle({
    super.key,
    required this.value,
    this.length = 0.85,
    this.tail = 0,
    this.width = 6,
    this.color,
    this.hubRadius = 6,
    this.hubColor,
  });

  /// The value of the angle scale the needle points at.
  final double value;

  /// How far the needle reaches, as a fraction of the outer radius.
  final double length;

  /// How far the needle reaches behind the centre, as a fraction of the
  /// outer radius.
  final double tail;

  /// Width of the needle at the centre, in logical pixels. It tapers to a
  /// point.
  final double width;

  /// Colour of the needle. Defaults to the foreground of the chart theme.
  final Color? color;

  /// Radius of the cap over the centre, in logical pixels; zero draws none.
  final double hubRadius;

  /// Colour of the cap. Defaults to [color].
  final Color? hubColor;

  @override
  Widget build(BuildContext context) {
    final Color needle = color ?? ChartTheme.of(context).foreground;
    return ChartPaint(
      clip: false,
      painter: _NeedlePainter(
        polar: ChartPolarScope.of(context),
        value: value,
        length: length,
        tail: tail,
        width: width,
        color: needle,
        hubRadius: hubRadius,
        hubColor: hubColor ?? needle,
      ),
    );
  }
}

class _NeedlePainter extends ChartPainter {
  const _NeedlePainter({
    required this.polar,
    required this.value,
    required this.length,
    required this.tail,
    required this.width,
    required this.color,
    required this.hubRadius,
    required this.hubColor,
  });

  final ChartPolar polar;
  final double value;
  final double length;
  final double tail;
  final double width;
  final Color color;
  final double hubRadius;
  final Color hubColor;

  @override
  void paint(ChartPaintContext context) {
    final ChartPolarView circle = polar.resolve(context.view);
    if (!(circle.radius > 0) || !value.isFinite || circle.angleScale == null) return;
    final double angle =
        polar.startAngle + polar.sweepAngle * circle.angleFraction(value).clamp(0.0, 1.0);
    final Offset along = Offset(math.cos(angle), math.sin(angle));
    final Offset across = Offset(-along.dy, along.dx) * (width / 2);
    final Offset tip = circle.center + along * (circle.radius * length);
    final Offset back = circle.center - along * (circle.radius * tail);
    final ui.Path needle = ui.Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(circle.center.dx + across.dx, circle.center.dy + across.dy)
      ..lineTo(back.dx, back.dy)
      ..lineTo(circle.center.dx - across.dx, circle.center.dy - across.dy)
      ..close();
    context.canvas.drawPath(needle, Paint()..color = color);
    if (hubRadius > 0) {
      context.canvas.drawCircle(circle.center, hubRadius, Paint()..color = hubColor);
    }
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) =>
      oldDelegate.polar != polar ||
      oldDelegate.value != value ||
      oldDelegate.length != length ||
      oldDelegate.tail != tail ||
      oldDelegate.width != width ||
      oldDelegate.color != color ||
      oldDelegate.hubRadius != hubRadius ||
      oldDelegate.hubColor != hubColor;
}

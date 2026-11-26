import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// The shape of the rings of a [ChartPolarGrid].
enum ChartPolarGridShape {
  /// Circles, or arcs when the chart turns less than a whole circle.
  circle,

  /// Straight lines from spoke to spoke: the web of a radar chart. With
  /// fewer than three spokes the rings are drawn as circles.
  polygon,
}

/// The grid of a polar chart: a ring at every tick of the radius scale and a
/// spoke at every tick of the angle scale.
///
/// An ordinary layer: put it first in the children of a `PolarChart` to draw
/// it under the series. `ChartPolarAxis` writes the labels.
class ChartPolarGrid extends StatelessWidget {
  /// Creates a polar grid.
  const ChartPolarGrid({
    super.key,
    this.rings = true,
    this.spokes = true,
    this.shape = ChartPolarGridShape.circle,
    this.color,
    this.width = 1,
    this.dash,
  });

  /// Whether a ring is drawn at every tick of the radius scale.
  final bool rings;

  /// Whether a line from the inner to the outer radius is drawn at every
  /// tick of the angle scale.
  final bool spokes;

  /// Whether the rings are round or run straight from spoke to spoke.
  final ChartPolarGridShape shape;

  /// Line colour. Defaults to the chart theme.
  final Color? color;

  /// Line width.
  final double width;

  /// Dash pattern: lengths of alternating dashes and gaps. Null draws solid
  /// lines.
  final List<double>? dash;

  @override
  Widget build(BuildContext context) {
    return ChartPaint(
      clip: false,
      painter: _PolarGridPainter(
        polar: ChartPolarScope.of(context),
        rings: rings,
        spokes: spokes,
        shape: shape,
        color: color ?? ChartTheme.of(context).gridColor,
        width: width,
        dash: dash,
      ),
    );
  }
}

class _PolarGridPainter extends ChartPainter {
  const _PolarGridPainter({
    required this.polar,
    required this.rings,
    required this.spokes,
    required this.shape,
    required this.color,
    required this.width,
    required this.dash,
  });

  final ChartPolar polar;
  final bool rings;
  final bool spokes;
  final ChartPolarGridShape shape;
  final Color color;
  final double width;
  final List<double>? dash;

  @override
  void paint(ChartPaintContext context) {
    final ChartPolarView circle = polar.resolve(context.view);
    if (!(circle.radius > 0)) return;
    final List<double> pattern = dash ?? const <double>[];
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    final List<double> angles = <double>[
      for (final ChartTick tick in circle.angleTicks) circle.angleOf(tick.value),
    ];
    if (rings) {
      final bool straight = shape == ChartPolarGridShape.polygon && angles.length >= 3;
      final ui.Path path = ui.Path();
      for (final ChartTick tick in circle.radiusTicks) {
        final double r = circle.radiusOf(tick.value);
        // A ring of no size is the centre, which needs no line.
        if (!(r > 0.5) || r > circle.radius + 0.5) continue;
        if (straight) {
          for (int i = 0; i < angles.length; i++) {
            final Offset corner = circle.pointAt(angles[i], r);
            i == 0 ? path.moveTo(corner.dx, corner.dy) : path.lineTo(corner.dx, corner.dy);
          }
          if (circle.isFullCircle) path.close();
        } else if (circle.isFullCircle) {
          path.addOval(Rect.fromCircle(center: circle.center, radius: r));
        } else {
          path.addArc(
            Rect.fromCircle(center: circle.center, radius: r),
            polar.startAngle,
            polar.sweepAngle,
          );
        }
      }
      context.canvas.drawPath(ChartPainter.dashPath(path, pattern), line);
    }
    if (spokes) {
      final double from = math.max(0, circle.innerRadius);
      for (final double angle in angles) {
        ChartPainter.drawDashedLine(
          context.canvas,
          circle.pointAt(angle, from),
          circle.pointAt(angle, circle.radius),
          line,
          pattern,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PolarGridPainter oldDelegate) =>
      oldDelegate.polar != polar ||
      oldDelegate.rings != rings ||
      oldDelegate.spokes != spokes ||
      oldDelegate.shape != shape ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      !listEquals(oldDelegate.dash, dash);
}

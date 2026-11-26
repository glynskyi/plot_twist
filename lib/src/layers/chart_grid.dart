import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Grid lines at the ticks of the chart's scales.
///
/// An ordinary layer: put it first in `Chart.children` to draw it under the
/// series, or leave it out and paint your own with a [ChartPainter].
class ChartGrid extends StatelessWidget {
  /// Creates a grid.
  const ChartGrid({
    super.key,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.horizontal = true,
    this.vertical = true,
    this.color,
    this.width = 1,
    this.dash,
  });

  /// The scale whose ticks produce vertical lines.
  final Object xScale;

  /// The scale whose ticks produce horizontal lines.
  final Object yScale;

  /// Whether horizontal lines (at y ticks) are drawn.
  final bool horizontal;

  /// Whether vertical lines (at x ticks) are drawn.
  final bool vertical;

  /// Line colour. Defaults to the chart theme.
  final Color? color;

  /// Line width.
  final double width;

  /// Dash pattern: lengths of alternating dashes and gaps. Null draws solid
  /// lines. The dashes move with the data when the chart is panned.
  final List<double>? dash;

  @override
  Widget build(BuildContext context) => ChartPaint(
    painter: _GridPainter(
      xScale: xScale,
      yScale: yScale,
      horizontal: horizontal,
      vertical: vertical,
      color: color ?? ChartTheme.of(context).gridColor,
      width: width,
      dash: dash,
    ),
  );
}

class _GridPainter extends ChartPainter {
  const _GridPainter({
    required this.xScale,
    required this.yScale,
    required this.horizontal,
    required this.vertical,
    required this.color,
    required this.width,
    required this.dash,
  });

  final Object xScale;
  final Object yScale;
  final bool horizontal;
  final bool vertical;
  final Color color;
  final double width;
  final List<double>? dash;

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width;
    final ChartScaleView? xs = view.scales[xScale];
    final ChartScaleView? ys = view.scales[yScale];
    final List<double> pattern = dash ?? const <double>[];
    // Dashes are anchored to the scale they run along, so the whole grid
    // moves as one when the chart is panned.
    if (vertical && xs != null) {
      final double phase = pattern.isEmpty || ys == null ? 0 : -ys.scaledToPixel(0);
      for (final ChartTick tick in xs.ticks) {
        final double x = xs.toPixel(tick.value);
        ChartPainter.drawDashedLine(
          context.canvas,
          Offset(x, 0),
          Offset(x, view.size.height),
          paint,
          pattern,
          phase: phase,
        );
      }
    }
    if (horizontal && ys != null) {
      final double phase = pattern.isEmpty || xs == null ? 0 : -xs.scaledToPixel(0);
      for (final ChartTick tick in ys.ticks) {
        final double y = ys.toPixel(tick.value);
        ChartPainter.drawDashedLine(
          context.canvas,
          Offset(0, y),
          Offset(view.size.width, y),
          paint,
          pattern,
          phase: phase,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.xScale != xScale ||
      oldDelegate.yScale != yScale ||
      oldDelegate.horizontal != horizontal ||
      oldDelegate.vertical != vertical ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      !listEquals(oldDelegate.dash, dash);
}

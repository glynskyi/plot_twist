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

  @override
  Widget build(BuildContext context) => ChartPaint(
    painter: _GridPainter(
      xScale: xScale,
      yScale: yScale,
      horizontal: horizontal,
      vertical: vertical,
      color: color ?? ChartTheme.of(context).gridColor,
      width: width,
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
  });

  final Object xScale;
  final Object yScale;
  final bool horizontal;
  final bool vertical;
  final Color color;
  final double width;

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width;
    if (vertical && view.scales.containsKey(xScale)) {
      final ChartScaleView xs = view.scale(xScale);
      for (final ChartTick tick in xs.ticks) {
        final double x = xs.toPixel(tick.value);
        context.canvas.drawLine(Offset(x, 0), Offset(x, view.size.height), paint);
      }
    }
    if (horizontal && view.scales.containsKey(yScale)) {
      final ChartScaleView ys = view.scale(yScale);
      for (final ChartTick tick in ys.ticks) {
        final double y = ys.toPixel(tick.value);
        context.canvas.drawLine(Offset(0, y), Offset(view.size.width, y), paint);
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
      oldDelegate.width != width;
}

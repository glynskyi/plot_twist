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
    this.minor = false,
    this.minorColor,
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

  /// Whether lines are also drawn at the minor ticks of the scales. A scale
  /// has minor ticks when its ticks ask for them: see
  /// `LinearTicks.minorCount`.
  final bool minor;

  /// Colour of the lines at minor ticks. Defaults to [color] at half its
  /// opacity.
  final Color? minorColor;

  @override
  Widget build(BuildContext context) {
    final Color major = color ?? ChartTheme.of(context).gridColor;
    return ChartPaint(
      painter: _GridPainter(
        xScale: xScale,
        yScale: yScale,
        horizontal: horizontal,
        vertical: vertical,
        color: major,
        width: width,
        dash: dash,
        minorColor: minor ? minorColor ?? major.withValues(alpha: major.a / 2) : null,
      ),
    );
  }
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
    required this.minorColor,
  });

  final Object xScale;
  final Object yScale;
  final bool horizontal;
  final bool vertical;
  final Color color;
  final double width;
  final List<double>? dash;

  /// Colour of the lines at minor ticks; null draws none.
  final Color? minorColor;

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    final ChartScaleView? xs = view.scales[xScale];
    final ChartScaleView? ys = view.scales[yScale];
    final List<double> pattern = dash ?? const <double>[];
    // Dashes are anchored to the scale they run along, so the whole grid
    // moves as one when the chart is panned.
    final double phaseX = pattern.isEmpty || xs == null ? 0 : -xs.scaledToPixel(0);
    final double phaseY = pattern.isEmpty || ys == null ? 0 : -ys.scaledToPixel(0);
    final Paint paint = Paint()..strokeWidth = width;

    void lines(Iterable<double> xValues, Iterable<double> yValues) {
      if (vertical && xs != null) {
        for (final double value in xValues) {
          final double x = xs.toPixel(value);
          ChartPainter.drawDashedLine(
            context.canvas,
            Offset(x, 0),
            Offset(x, view.size.height),
            paint,
            pattern,
            phase: phaseY,
          );
        }
      }
      if (horizontal && ys != null) {
        for (final double value in yValues) {
          final double y = ys.toPixel(value);
          ChartPainter.drawDashedLine(
            context.canvas,
            Offset(0, y),
            Offset(view.size.width, y),
            paint,
            pattern,
            phase: phaseX,
          );
        }
      }
    }

    // Minor lines first, so the lines at the ticks lie on top of them.
    final Color? faint = minorColor;
    if (faint != null) {
      paint.color = faint;
      lines(xs?.minorTicks ?? const <double>[], ys?.minorTicks ?? const <double>[]);
    }
    paint.color = color;
    lines(
      xs?.ticks.map((ChartTick tick) => tick.value) ?? const <double>[],
      ys?.ticks.map((ChartTick tick) => tick.value) ?? const <double>[],
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.xScale != xScale ||
      oldDelegate.yScale != yScale ||
      oldDelegate.horizontal != horizontal ||
      oldDelegate.vertical != vertical ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      !listEquals(oldDelegate.dash, dash) ||
      oldDelegate.minorColor != minorColor;
}

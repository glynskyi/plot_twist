import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Picks the colour of one bar from its row.
typedef ChartBarColor = Color? Function(int index, double x, double y);

/// Vertical bars, one per row of a [ChartData].
///
/// Each bar is centred on its x value (plus [offset]) and is [width] × [step]
/// data units wide. It spans from [baseline] — or from the value in
/// [baseColumn], for floating and stacked bars — to its y value.
///
/// Several series side by side: give each the same [step] and a different
/// [offset]. Stacked: give the upper series a [baseColumn] holding the top of
/// the series below (see `ChartData.stacked`).
class BarSeries extends StatelessWidget {
  /// Creates a bar series.
  const BarSeries({
    super.key,
    required this.data,
    this.column = 0,
    this.baseColumn,
    this.baseline = 0,
    this.id,
    this.label,
    this.color,
    this.colorOf,
    this.width = 0.7,
    this.step,
    this.offset = 0,
    this.radius = 0,
    this.visible = true,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.isolate = true,
  });

  /// The data to plot.
  final ChartData data;

  /// The value column holding the top of each bar.
  final int column;

  /// The value column holding the bottom of each bar; null uses [baseline].
  final int? baseColumn;

  /// The value bars grow from when [baseColumn] is null.
  final double baseline;

  /// Identifier of the series.
  final Object? id;

  /// Name of the series, for legends and tooltips.
  final String? label;

  /// Bar colour. Defaults to the first palette colour of the chart theme.
  final Color? color;

  /// Per-bar colour; return null to use [color].
  final ChartBarColor? colorOf;

  /// Bar width as a fraction of [step].
  final double width;

  /// Distance between bars in data units. Defaults to the distance between
  /// the first two rows.
  final double? step;

  /// Shift of every bar in data units — use it to put series side by side.
  final double offset;

  /// Corner radius in logical pixels.
  final double radius;

  /// Whether the series is shown; a hidden series stays listed for legends.
  final bool visible;

  /// Id of the horizontal scale.
  final Object xScale;

  /// Id of the vertical scale.
  final Object yScale;

  /// Whether the series paints into its own compositing layer.
  final bool isolate;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = color ?? ChartTheme.of(context).seriesColor(0);
    return ChartPaint(
      id: id,
      label: label,
      color: effectiveColor,
      visible: visible,
      isolate: isolate,
      painter: BarSeriesPainter(
        data: data,
        column: column,
        baseColumn: baseColumn,
        baseline: baseline,
        color: effectiveColor,
        colorOf: colorOf,
        width: width,
        step: step,
        offset: offset,
        radius: radius,
        xScale: xScale,
        yScale: yScale,
      ),
    );
  }
}

/// Paints a [BarSeries]. Built entirely on the public [ChartSeriesPainter]
/// contract.
class BarSeriesPainter extends ChartSeriesPainter {
  /// Creates a bar painter.
  BarSeriesPainter({
    required this.data,
    this.column = 0,
    this.baseColumn,
    this.baseline = 0,
    required this.color,
    this.colorOf,
    this.width = 0.7,
    this.step,
    this.offset = 0,
    this.radius = 0,
    super.xScale,
    super.yScale,
  }) : super(data: data);

  /// The data to plot.
  final ChartData data;

  /// The value column holding the top of each bar.
  final int column;

  /// The value column holding the bottom of each bar.
  final int? baseColumn;

  /// The value bars grow from.
  final double baseline;

  /// Bar colour.
  final Color color;

  /// Per-bar colour.
  final ChartBarColor? colorOf;

  /// Bar width as a fraction of the step.
  final double width;

  /// Distance between bars in data units.
  final double? step;

  /// Shift of every bar in data units.
  final double offset;

  /// Corner radius.
  final double radius;

  double get _step {
    final double? s = step;
    if (s != null) return s;
    if (data.length >= 2 && data.isSorted) {
      final double d = data.x(1) - data.x(0);
      if (d > 0) return d;
    }
    return 1;
  }

  double get _half => _step * width / 2;

  double _base(int i) {
    final int? c = baseColumn;
    return c == null ? baseline : data.value(i, c);
  }

  @override
  bool shouldRepaint(BarSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate.column != column ||
      oldDelegate.baseColumn != baseColumn ||
      oldDelegate.baseline != baseline ||
      oldDelegate.color != color ||
      oldDelegate.colorOf != colorOf ||
      oldDelegate.width != width ||
      oldDelegate.step != step ||
      oldDelegate.offset != offset ||
      oldDelegate.radius != radius;

  @override
  bool shouldRescale(BarSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate.column != column ||
      oldDelegate.baseColumn != baseColumn ||
      oldDelegate.baseline != baseline ||
      oldDelegate.width != width ||
      oldDelegate.step != step ||
      oldDelegate.offset != offset;

  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) {
    if (data.isEmpty) return null;
    final double half = _half;
    int start = 0;
    int end = data.length;
    if (xWindow != null && data.isSorted) {
      (start, end) = data.indexRange(
        xWindow.min - offset - half,
        xWindow.max - offset + half,
        overscan: 0,
      );
    }
    ChartRange? y = data.valueExtent(column: column, start: start, end: end);
    final int? base = baseColumn;
    if (base == null) {
      y = y?.include(baseline);
    } else {
      y = ChartRange.merge(y, data.valueExtent(column: base, start: start, end: end));
    }
    final ChartRange? x = data.xExtent;
    return ChartDataBounds(
      x: x == null ? null : ChartRange(x.min + offset - half, x.max + offset + half),
      y: y,
    );
  }

  @override
  double? valueAt(double x) {
    final int i = data.nearestIndex(x - offset);
    if (i < 0) return null;
    final double centre = data.x(i) + offset;
    if ((x - centre).abs() > _half) return null;
    final double v = data.value(i, column);
    return v.isNaN ? null : v;
  }

  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    if (data.isEmpty) return;
    final ChartView view = query.view;
    if (!view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) return;
    final ChartScaleView xs = view.scale(xScale);
    final ChartScaleView ys = view.scale(yScale);
    final int i = data.nearestIndex(xs.toValue(query.position.dx) - offset);
    if (i < 0) return;
    final double y = data.value(i, column);
    if (y.isNaN) return;
    final double x = data.x(i) + offset;
    final Rect rect = Rect.fromPoints(
      Offset(xs.toPixel(x - _half), ys.toPixel(_base(i))),
      Offset(xs.toPixel(x + _half), ys.toPixel(y)),
    );
    final Offset position = Offset(xs.toPixel(x), ys.toPixel(y));
    final double distance = query.mode == ChartHitMode.nearestX
        ? math.max(0, (query.position.dx - rect.center.dx).abs() - rect.width / 2)
        : (rect.contains(query.position) ? 0 : (position - query.position).distance);
    if (distance > query.maxDistance) return;
    hits.add(
      ChartHit(x: data.x(i), y: y, position: position, distance: distance, index: i, rect: rect),
    );
  }

  @override
  bool hitTest(Offset position, ChartView view) => false;

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    if (data.isEmpty || !view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) {
      return;
    }
    final ChartScaleView xs = view.scale(xScale);
    final ChartScaleView ys = view.scale(yScale);
    if (xs.extent <= 0 || ys.extent <= 0) return;
    final double half = _half;
    final (int start, int end) = data.isSorted
        ? data.indexRange(xs.min - offset - half, xs.max - offset + half, overscan: 0)
        : (0, data.length);
    if (end <= start) return;

    final double barPixels = xs.lengthToPixels(half * 2, at: data.x(start));
    final Map<Color, ui.Path> paths = <Color, ui.Path>{};
    ui.Path pathFor(Color c) => paths[c] ??= ui.Path();

    if (barPixels < 1 && data.isSorted && colorOf == null && baseColumn == null) {
      // More bars than pixels: one column per pixel covering the extremes.
      final double base = ys.toPixel(baseline);
      final ui.Path path = pathFor(color);
      final bool ascending = xs.toPixel(xs.max) >= xs.toPixel(xs.min);
      int row = start;
      for (int k = 0; k < xs.extent.ceil() && row < end; k++) {
        final double edge = ascending ? xs.toValue(k + 1.0) : xs.toValue(xs.extent - (k + 1.0));
        final int rowEnd = math.min(end, math.max(row, data.lowerBound(edge - offset)));
        if (rowEnd <= row) continue;
        final (double lo, double hi) = data.minMax(row, rowEnd, column: column);
        if (lo <= hi) {
          final double left = ascending ? k.toDouble() : xs.extent - (k + 1.0);
          final double top = math.min(base, math.min(ys.toPixel(lo), ys.toPixel(hi)));
          final double bottom = math.max(base, math.max(ys.toPixel(lo), ys.toPixel(hi)));
          path.addRect(Rect.fromLTRB(left, top, left + 1, bottom));
        }
        row = rowEnd;
      }
    } else {
      final double r = math.min(radius, barPixels / 2);
      for (int i = start; i < end; i++) {
        final double y = data.value(i, column);
        if (y.isNaN) continue;
        final double x = data.x(i) + offset;
        final double baseValue = _base(i);
        if (baseValue.isNaN) continue;
        final Rect rect = Rect.fromPoints(
          Offset(xs.toPixel(x - half), ys.toPixel(baseValue)),
          Offset(xs.toPixel(x + half), ys.toPixel(y)),
        );
        final ui.Path path = pathFor(colorOf?.call(i, data.x(i), y) ?? color);
        if (r > 0) {
          // Round only the end that points away from the base.
          final bool up = ys.toPixel(y) <= ys.toPixel(baseValue);
          final Radius corner = Radius.circular(math.min(r, rect.height));
          path.addRRect(
            RRect.fromRectAndCorners(
              rect,
              topLeft: up ? corner : Radius.zero,
              topRight: up ? corner : Radius.zero,
              bottomLeft: up ? Radius.zero : corner,
              bottomRight: up ? Radius.zero : corner,
            ),
          );
        } else {
          path.addRect(rect);
        }
      }
    }
    final Paint paint = Paint()..style = PaintingStyle.fill;
    paths.forEach((Color c, ui.Path path) {
      paint.color = c;
      context.canvas.drawPath(path, paint);
    });
  }
}

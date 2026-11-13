import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// A dot per row of a [ChartData]. Rows need not be sorted.
///
/// Dots of one size are drawn in a single batch, so tens of thousands pan
/// smoothly.
class ScatterSeries extends StatelessWidget {
  /// Creates a scatter series.
  const ScatterSeries({
    super.key,
    required this.data,
    this.column = 0,
    this.sizeColumn,
    this.id,
    this.label,
    this.color,
    this.radius = 3,
    this.visible = true,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.isolate = true,
  });

  /// The data to plot.
  final ChartData data;

  /// The value column holding y.
  final int column;

  /// A value column holding each dot's radius in logical pixels; null uses
  /// [radius] for all.
  final int? sizeColumn;

  /// Identifier of the series.
  final Object? id;

  /// Name of the series, for legends and tooltips.
  final String? label;

  /// Dot colour. Defaults to the first palette colour of the chart theme.
  final Color? color;

  /// Dot radius in logical pixels.
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
      painter: ScatterSeriesPainter(
        data: data,
        column: column,
        sizeColumn: sizeColumn,
        color: effectiveColor,
        radius: radius,
        xScale: xScale,
        yScale: yScale,
      ),
    );
  }
}

/// Paints a [ScatterSeries]. Built entirely on the public
/// [ChartSeriesPainter] contract.
class ScatterSeriesPainter extends ChartSeriesPainter {
  /// Creates a scatter painter.
  ScatterSeriesPainter({
    required this.data,
    this.column = 0,
    this.sizeColumn,
    required this.color,
    this.radius = 3,
    super.xScale,
    super.yScale,
  }) : super(data: data);

  /// The data to plot.
  final ChartData data;

  /// The value column holding y.
  final int column;

  /// The value column holding per-dot radii.
  final int? sizeColumn;

  /// Dot colour.
  final Color color;

  /// Dot radius.
  final double radius;

  @override
  bool shouldRepaint(ScatterSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate.column != column ||
      oldDelegate.sizeColumn != sizeColumn ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius;

  @override
  bool shouldRescale(ScatterSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) || oldDelegate.column != column;

  (int, int) _rows(ChartRange? xWindow) => xWindow != null && data.isSorted
      ? data.indexRange(xWindow.min, xWindow.max, overscan: 0)
      : (0, data.length);

  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) {
    if (data.isEmpty) return null;
    if (data.isSorted || (xWindow == null && yWindow == null)) {
      final (int start, int end) = _rows(xWindow);
      return ChartDataBounds(
        x: data.xExtent,
        y: data.valueExtent(column: column, start: start, end: end),
      );
    }
    // Unsorted data with a window: only rows inside it count.
    double lo = double.infinity;
    double hi = double.negativeInfinity;
    double xLo = double.infinity;
    double xHi = double.negativeInfinity;
    for (int i = 0; i < data.length; i++) {
      final double x = data.x(i);
      final double y = data.value(i, column);
      if (xWindow == null || xWindow.contains(x)) {
        if (y < lo) lo = y;
        if (y > hi) hi = y;
      }
      if (yWindow == null || yWindow.contains(y)) {
        if (x < xLo) xLo = x;
        if (x > xHi) xHi = x;
      }
    }
    return ChartDataBounds(
      x: xLo <= xHi ? ChartRange(xLo, xHi) : null,
      y: lo <= hi ? ChartRange(lo, hi) : null,
    );
  }

  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    if (data.isEmpty) return;
    final ChartView view = query.view;
    if (!view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) return;
    final ChartScaleView xs = view.scale(xScale);
    final ChartScaleView ys = view.scale(yScale);
    final (int start, int end) = _rows(ChartRange.of(xs.min, xs.max));
    int best = -1;
    double bestDistance = query.maxDistance;
    Offset bestPosition = Offset.zero;
    for (int i = start; i < end; i++) {
      final double y = data.value(i, column);
      if (y.isNaN) continue;
      final Offset p = Offset(xs.toPixel(data.x(i)), ys.toPixel(y));
      final double d = query.mode == ChartHitMode.nearestX
          ? (p.dx - query.position.dx).abs()
          : (p - query.position).distance;
      if (d <= bestDistance) {
        bestDistance = d;
        best = i;
        bestPosition = p;
      }
    }
    if (best < 0) return;
    hits.add(
      ChartHit(
        x: data.x(best),
        y: data.value(best, column),
        position: bestPosition,
        distance: bestDistance,
        index: best,
      ),
    );
  }

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    if (data.isEmpty || !view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) {
      return;
    }
    final ChartScaleView xs = view.scale(xScale);
    final ChartScaleView ys = view.scale(yScale);
    final (int start, int end) = _rows(ChartRange.of(xs.min, xs.max));
    if (end <= start) return;
    final Canvas canvas = context.canvas;
    final double width = view.size.width;
    final double height = view.size.height;
    final int? sizes = sizeColumn;
    if (sizes != null) {
      final Paint paint = Paint()..color = color;
      for (int i = start; i < end; i++) {
        final double y = data.value(i, column);
        if (y.isNaN) continue;
        final double r = data.value(i, sizes);
        final double px = xs.toPixel(data.x(i));
        final double py = ys.toPixel(y);
        if (px < -r || px > width + r || py < -r || py > height + r) continue;
        canvas.drawCircle(Offset(px, py), r, paint);
      }
      return;
    }
    final Float32List points = Float32List((end - start) * 2);
    int n = 0;
    for (int i = start; i < end; i++) {
      final double y = data.value(i, column);
      if (y.isNaN) continue;
      final double px = xs.toPixel(data.x(i));
      final double py = ys.toPixel(y);
      if (px < -radius || px > width + radius || py < -radius || py > height + radius) continue;
      points[n++] = px;
      points[n++] = py;
    }
    if (n == 0) return;
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(points, 0, n),
      Paint()
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * 2,
    );
  }
}

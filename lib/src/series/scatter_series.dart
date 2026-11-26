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
    double? pointRadius,
    this.visible = true,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.clip = true,
    this.isolate = true,
    @Deprecated('Use pointRadius. Removed in 0.3.0.') double? radius,
  }) : pointRadius = pointRadius ?? radius ?? 3;

  /// The data to plot.
  final ChartData data;

  /// The value column holding y.
  final int column;

  /// A value column holding each dot's radius in logical pixels; null uses
  /// [pointRadius] for all.
  final int? sizeColumn;

  /// Identifier of the series.
  final Object? id;

  /// Name of the series, for legends and tooltips.
  final String? label;

  /// Dot colour. Defaults to the colour the palette of the chart theme has
  /// for the place of the series in the chart.
  final Color? color;

  /// Dot radius in logical pixels. Defaults to `3`.
  final double pointRadius;

  /// The old name of [pointRadius].
  @Deprecated('Use pointRadius. Removed in 0.3.0.')
  double get radius => pointRadius;

  /// Whether the series is shown; a hidden series stays listed for legends.
  final bool visible;

  /// Id of the horizontal scale.
  final Object xScale;

  /// Id of the vertical scale.
  final Object yScale;

  /// Whether the dots are clipped to the plot area.
  final bool clip;

  /// Whether the series paints into its own compositing layer.
  final bool isolate;

  @override
  Widget build(BuildContext context) {
    return ChartPaint(
      id: id,
      label: label,
      color: color,
      visible: visible,
      clip: clip,
      isolate: isolate,
      painter: ScatterSeriesPainter(
        data: data,
        column: column,
        sizeColumn: sizeColumn,
        color: color,
        pointRadius: pointRadius,
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
    this.color,
    double? pointRadius,
    super.xScale,
    super.yScale,
    @Deprecated('Use pointRadius. Removed in 0.3.0.') double? radius,
  }) : pointRadius = pointRadius ?? radius ?? 3,
       super(data: data);

  /// The data to plot.
  final ChartData data;

  /// The value column holding y.
  final int column;

  /// The value column holding per-dot radii.
  final int? sizeColumn;

  /// Dot colour; null uses `ChartPaintContext.seriesColor`.
  final Color? color;

  /// Dot radius in logical pixels.
  final double pointRadius;

  /// The old name of [pointRadius].
  @Deprecated('Use pointRadius. Removed in 0.3.0.')
  double get radius => pointRadius;

  @override
  bool shouldRepaint(ScatterSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate.column != column ||
      oldDelegate.sizeColumn != sizeColumn ||
      oldDelegate.color != color ||
      oldDelegate.pointRadius != pointRadius;

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
        x: xWindow == null ? data.xExtent : data.xExtentWithin(xWindow),
        y: data.valueExtent(column: column, start: start, end: end, within: yWindow),
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
      if (xWindow != null && !xWindow.contains(x)) continue;
      if (yWindow != null && !yWindow.contains(y)) continue;
      if (y < lo && y != double.negativeInfinity) lo = y;
      if (y > hi && y != double.infinity) hi = y;
      if (x < xLo) xLo = x;
      if (x > xHi) xHi = x;
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
      // A value the scale cannot show is not on the chart.
      if (!p.isFinite) continue;
      final double d = switch (query.mode) {
        ChartHitMode.nearestX => (p.dx - query.position.dx).abs(),
        ChartHitMode.nearestY => (p.dy - query.position.dy).abs(),
        ChartHitMode.nearest => (p - query.position).distance,
      };
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
  void visitMarks(ChartView view, bool Function(ChartHit mark) visit) {
    if (data.isEmpty || !view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) {
      return;
    }
    final ChartScaleView xs = view.scale(xScale);
    final ChartScaleView ys = view.scale(yScale);
    final (int start, int end) = _rows(ChartRange.of(xs.min, xs.max));
    for (int i = start; i < end; i++) {
      final double y = data.value(i, column);
      if (y.isNaN) continue;
      final Offset position = Offset(xs.toPixel(data.x(i)), ys.toPixel(y));
      if (!position.isFinite) continue;
      final ChartHit mark = ChartHit(x: data.x(i), y: y, position: position, distance: 0, index: i);
      if (!visit(mark)) return;
    }
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
    final double radius = pointRadius;
    final Color color = this.color ?? context.seriesColor;
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

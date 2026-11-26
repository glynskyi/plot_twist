import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Picks the colour of one bar from its row.
typedef ChartBarColor = Color? Function(int index, double x, double y);

/// Vertical bars, one per row of a [ChartData].
///
/// Each bar is centred on its x value (plus [offset]) and is [widthFactor] ×
/// [step] data units wide. It spans from [baseline] — or from the value in
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
    double? widthFactor,
    this.step,
    this.offset = 0,
    double? cornerRadius,
    this.visible = true,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.clip = true,
    this.isolate = true,
    @Deprecated('Use widthFactor. Removed in 0.3.0.') double? width,
    @Deprecated('Use cornerRadius. Removed in 0.3.0.') double? radius,
  }) : widthFactor = widthFactor ?? width ?? 0.7,
       cornerRadius = cornerRadius ?? radius ?? 0;

  /// The data to plot.
  final ChartData data;

  /// The value column holding the top of each bar.
  final int column;

  /// The value column holding the bottom of each bar; null uses [baseline].
  final int? baseColumn;

  /// The value bars grow from when [baseColumn] is null.
  ///
  /// On a scale that cannot show this value, such as zero on a logarithmic
  /// scale, bars grow from the edge of the plot.
  final double baseline;

  /// Identifier of the series.
  final Object? id;

  /// Name of the series, for legends and tooltips.
  final String? label;

  /// Bar colour. Defaults to the first palette colour of the chart theme.
  final Color? color;

  /// Per-bar colour; return null to use [color].
  final ChartBarColor? colorOf;

  /// Bar width as a fraction of [step]. Defaults to `0.7`.
  final double widthFactor;

  /// The old name of [widthFactor].
  @Deprecated('Use widthFactor. Removed in 0.3.0.')
  double get width => widthFactor;

  /// Distance between bars in data units. Defaults to the distance between
  /// the first two rows.
  final double? step;

  /// Shift of every bar in data units — use it to put series side by side.
  final double offset;

  /// Radius of the corners at the end of each bar that points away from its
  /// base, in logical pixels. Defaults to `0`.
  final double cornerRadius;

  /// The old name of [cornerRadius].
  @Deprecated('Use cornerRadius. Removed in 0.3.0.')
  double get radius => cornerRadius;

  /// Whether the series is shown; a hidden series stays listed for legends.
  final bool visible;

  /// Id of the horizontal scale.
  final Object xScale;

  /// Id of the vertical scale.
  final Object yScale;

  /// Whether the bars are clipped to the plot area.
  final bool clip;

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
      clip: clip,
      isolate: isolate,
      painter: BarSeriesPainter(
        data: data,
        column: column,
        baseColumn: baseColumn,
        baseline: baseline,
        color: effectiveColor,
        colorOf: colorOf,
        widthFactor: widthFactor,
        step: step,
        offset: offset,
        cornerRadius: cornerRadius,
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
    double? widthFactor,
    this.step,
    this.offset = 0,
    double? cornerRadius,
    super.xScale,
    super.yScale,
    @Deprecated('Use widthFactor. Removed in 0.3.0.') double? width,
    @Deprecated('Use cornerRadius. Removed in 0.3.0.') double? radius,
  }) : widthFactor = widthFactor ?? width ?? 0.7,
       cornerRadius = cornerRadius ?? radius ?? 0,
       super(data: data);

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
  final double widthFactor;

  /// The old name of [widthFactor].
  @Deprecated('Use widthFactor. Removed in 0.3.0.')
  double get width => widthFactor;

  /// Distance between bars in data units.
  final double? step;

  /// Shift of every bar in data units.
  final double offset;

  /// Corner radius in logical pixels.
  final double cornerRadius;

  /// The old name of [cornerRadius].
  @Deprecated('Use cornerRadius. Removed in 0.3.0.')
  double get radius => cornerRadius;

  double get _step {
    final double? s = step;
    if (s != null) return s;
    if (data.length >= 2 && data.isSorted) {
      final double d = data.x(1) - data.x(0);
      if (d > 0) return d;
    }
    return 1;
  }

  double get _half => _step * widthFactor / 2;

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
      oldDelegate.widthFactor != widthFactor ||
      oldDelegate.step != step ||
      oldDelegate.offset != offset ||
      oldDelegate.cornerRadius != cornerRadius;

  @override
  bool shouldRescale(BarSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate.column != column ||
      oldDelegate.baseColumn != baseColumn ||
      oldDelegate.baseline != baseline ||
      oldDelegate.widthFactor != widthFactor ||
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
    ChartRange? y = data.valueExtent(column: column, start: start, end: end, within: yWindow);
    final int? base = baseColumn;
    if (base == null) {
      // A baseline the scale cannot show (zero on a logarithmic scale) does
      // not count; the bars are then drawn from the edge of the plot.
      if (yWindow?.contains(baseline) ?? true) y = y?.include(baseline);
    } else {
      y = ChartRange.merge(
        y,
        data.valueExtent(column: base, start: start, end: end, within: yWindow),
      );
    }
    final ChartRange? x = xWindow == null
        ? data.xExtent
        : data.xExtentWithin(xWindow.shift(-offset));
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
    final Rect? rect = _rectOf(i, y, xs, ys, _half);
    if (rect == null) return;
    final double x = data.x(i) + offset;
    final Offset position = Offset(xs.toPixel(x), ys.toPixel(y));
    final double distance = query.mode == ChartHitMode.nearestX
        ? math.max(0, (query.position.dx - rect.center.dx).abs() - rect.width / 2)
        : (rect.contains(query.position) ? 0 : (position - query.position).distance);
    if (distance > query.maxDistance) return;
    hits.add(
      ChartHit(x: data.x(i), y: y, position: position, distance: distance, index: i, rect: rect),
    );
  }

  // A pixel coordinate kept within reach of the plot. A value the scale
  // cannot show, such as zero on a logarithmic scale, maps to infinity; it is
  // drawn at the edge it lies beyond.
  static double _near(double pixel, double extent) => pixel.clamp(-extent, extent * 2);

  // The rectangle of the bar in row [i] with the value [y], or null when the
  // row is a gap: a missing value or base, or a value the scale cannot show.
  Rect? _rectOf(int i, double y, ChartScaleView xs, ChartScaleView ys, double half) {
    final double top = ys.toPixel(y);
    final double base = _near(ys.toPixel(_base(i)), ys.extent);
    if (!top.isFinite || base.isNaN) return null;
    final double x = data.x(i) + offset;
    final double left = _near(xs.toPixel(x - half), xs.extent);
    final double right = _near(xs.toPixel(x + half), xs.extent);
    if (left.isNaN || right.isNaN) return null;
    return Rect.fromPoints(Offset(left, base), Offset(right, top));
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
      final double base = _near(ys.toPixel(baseline), ys.extent);
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
          final double low = _near(ys.toPixel(lo), ys.extent);
          final double high = _near(ys.toPixel(hi), ys.extent);
          final double top = math.min(base, math.min(low, high));
          final double bottom = math.max(base, math.max(low, high));
          path.addRect(Rect.fromLTRB(left, top, left + 1, bottom));
        }
        row = rowEnd;
      }
    } else {
      final double r = math.min(cornerRadius, barPixels / 2);
      for (int i = start; i < end; i++) {
        final double y = data.value(i, column);
        final Rect? rect = _rectOf(i, y, xs, ys, half);
        if (rect == null) continue;
        final ui.Path path = pathFor(colorOf?.call(i, data.x(i), y) ?? color);
        if (r > 0) {
          // Round only the end that points away from the base.
          final bool up = ys.toPixel(y) <= rect.center.dy;
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

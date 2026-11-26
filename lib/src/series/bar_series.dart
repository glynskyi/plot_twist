import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Picks the colour of one bar from its row: its [index], its [x] and its
/// value [y], whichever way the bars point.
typedef ChartBarColor = Color? Function(int index, double x, double y);

/// Bars, one per row of a [ChartData].
///
/// Each bar is centred on its x value (plus [offset]) and is [widthFactor] ×
/// [step] data units wide. It spans from [baseline] — or from the value in
/// [baseColumn], for floating and stacked bars — to its y value.
///
/// With [direction] set to `Axis.horizontal` the bars lie down: the rows run
/// along the vertical scale and the values along the horizontal one. The
/// data stays as it is; [xScale] is still the horizontal scale and [yScale]
/// the vertical one. Pair such a chart with
/// `ChartCrosshair(mode: ChartHitMode.nearestY)`.
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
    this.direction = Axis.vertical,
    this.id,
    this.label,
    this.color,
    this.colorOf,
    this.widthFactor = 0.7,
    this.step,
    this.offset = 0,
    this.cornerRadius = 0,
    this.visible = true,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.clip = true,
    this.isolate = true,
  });

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

  /// The direction the bars grow in: `Axis.vertical` for columns (the
  /// default), `Axis.horizontal` for bars that lie down.
  final Axis direction;

  /// Identifier of the series.
  final Object? id;

  /// Name of the series, for legends and tooltips.
  final String? label;

  /// Bar colour. Defaults to the colour the palette of the chart theme has
  /// for the place of the series in the chart.
  final Color? color;

  /// Per-bar colour; return null to use [color].
  final ChartBarColor? colorOf;

  /// Bar width as a fraction of [step]. Defaults to `0.7`.
  final double widthFactor;

  /// Distance between bars in data units. Defaults to the distance between
  /// the first two rows.
  final double? step;

  /// Shift of every bar in data units — use it to put series side by side.
  final double offset;

  /// Radius of the corners at the end of each bar that points away from its
  /// base, in logical pixels. Defaults to `0`.
  final double cornerRadius;

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
    return ChartPaint(
      id: id,
      label: label,
      color: color,
      visible: visible,
      clip: clip,
      isolate: isolate,
      painter: BarSeriesPainter(
        data: data,
        column: column,
        baseColumn: baseColumn,
        baseline: baseline,
        direction: direction,
        color: color,
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
    this.direction = Axis.vertical,
    this.color,
    this.colorOf,
    this.widthFactor = 0.7,
    this.step,
    this.offset = 0,
    this.cornerRadius = 0,
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

  /// The direction the bars grow in.
  final Axis direction;

  /// Bar colour; null uses `ChartPaintContext.seriesColor`.
  final Color? color;

  /// Per-bar colour.
  final ChartBarColor? colorOf;

  /// Bar width as a fraction of the step.
  final double widthFactor;

  /// Distance between bars in data units.
  final double? step;

  /// Shift of every bar in data units.
  final double offset;

  /// Corner radius in logical pixels.
  final double cornerRadius;

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

  bool get _horizontal => direction == Axis.horizontal;

  // The scale the rows run along, and the scale their values are on.
  Object get _argumentScale => _horizontal ? yScale : xScale;
  Object get _valueScale => _horizontal ? xScale : yScale;

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
      oldDelegate.direction != direction ||
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
      oldDelegate.direction != direction ||
      oldDelegate.widthFactor != widthFactor ||
      oldDelegate.step != step ||
      oldDelegate.offset != offset;

  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) {
    if (data.isEmpty) return null;
    final ChartRange? argumentWindow = _horizontal ? yWindow : xWindow;
    final ChartRange? valueWindow = _horizontal ? xWindow : yWindow;
    final double half = _half;
    int start = 0;
    int end = data.length;
    if (argumentWindow != null && data.isSorted) {
      (start, end) = data.indexRange(
        argumentWindow.min - offset - half,
        argumentWindow.max - offset + half,
        overscan: 0,
      );
    }
    ChartRange? value = data.valueExtent(
      column: column,
      start: start,
      end: end,
      within: valueWindow,
    );
    final int? base = baseColumn;
    if (base == null) {
      // A baseline the scale cannot show (zero on a logarithmic scale) does
      // not count; the bars are then drawn from the edge of the plot.
      if (valueWindow?.contains(baseline) ?? true) value = value?.include(baseline);
    } else {
      value = ChartRange.merge(
        value,
        data.valueExtent(column: base, start: start, end: end, within: valueWindow),
      );
    }
    final ChartRange? rows = argumentWindow == null
        ? data.xExtent
        : data.xExtentWithin(argumentWindow.shift(-offset));
    final ChartRange? argument = rows == null
        ? null
        : ChartRange(rows.min + offset - half, rows.max + offset + half);
    return _horizontal
        ? ChartDataBounds(x: value, y: argument)
        : ChartDataBounds(x: argument, y: value);
  }

  /// The value of the bar at [x], or null between two bars. Bars that lie
  /// down have no value at an x.
  @override
  double? valueAt(double x) {
    if (_horizontal) return null;
    final int i = data.nearestIndex(x - offset);
    if (i < 0) return null;
    final double centre = data.x(i) + offset;
    if ((x - centre).abs() > _half) return null;
    final double v = data.value(i, column);
    return v.isNaN ? null : v;
  }

  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    // The rows run along one scale, so none of them is the one at a position
    // on the other.
    final ChartHitMode other = _horizontal ? ChartHitMode.nearestX : ChartHitMode.nearestY;
    if (data.isEmpty || query.mode == other) return;
    final ChartView view = query.view;
    if (!view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) return;
    final ChartScaleView along = view.scale(_argumentScale);
    final ChartScaleView across = view.scale(_valueScale);
    final double pointer = _horizontal ? query.position.dy : query.position.dx;
    final int i = data.nearestIndex(along.toValue(pointer) - offset);
    if (i < 0) return;
    final Rect? rect = _rectOf(i, data.value(i, column), along, across, _half);
    if (rect == null) return;
    final Offset position = _tipOf(i, along, across);
    final double thickness = _horizontal ? rect.height : rect.width;
    final double middle = _horizontal ? rect.center.dy : rect.center.dx;
    final double distance = query.mode == ChartHitMode.nearest
        ? (rect.contains(query.position) ? 0 : (position - query.position).distance)
        : math.max(0, (pointer - middle).abs() - thickness / 2);
    if (distance > query.maxDistance) return;
    hits.add(_hitOf(i, rect, position, distance));
  }

  @override
  void visitMarks(ChartView view, bool Function(ChartHit mark) visit) {
    if (data.isEmpty || !view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) {
      return;
    }
    final ChartScaleView along = view.scale(_argumentScale);
    final ChartScaleView across = view.scale(_valueScale);
    final double half = _half;
    final (int start, int end) = data.isSorted
        ? data.indexRange(along.min - offset - half, along.max - offset + half, overscan: 0)
        : (0, data.length);
    for (int i = start; i < end; i++) {
      final Rect? rect = _rectOf(i, data.value(i, column), along, across, half);
      if (rect == null) continue;
      if (!visit(_hitOf(i, rect, _tipOf(i, along, across), 0))) return;
    }
  }

  // Where the value of row [i] is drawn: the middle of the end of its bar.
  Offset _tipOf(int i, ChartScaleView along, ChartScaleView across) {
    final double centre = along.toPixel(data.x(i) + offset);
    final double end = across.toPixel(data.value(i, column));
    return _horizontal ? Offset(end, centre) : Offset(centre, end);
  }

  ChartHit _hitOf(int i, Rect rect, Offset position, double distance) {
    final double value = data.value(i, column);
    return ChartHit(
      x: _horizontal ? value : data.x(i),
      y: _horizontal ? data.x(i) : value,
      position: position,
      distance: distance,
      index: i,
      rect: rect,
      base: _base(i),
      valueAxis: direction,
    );
  }

  // A pixel coordinate kept within reach of the plot. A value the scale
  // cannot show, such as zero on a logarithmic scale, maps to infinity; it is
  // drawn at the edge it lies beyond.
  static double _near(double pixel, double extent) => pixel.clamp(-extent, extent * 2);

  // The rectangle of the bar in row [i] with the value [value], or null when
  // the row is a gap: a missing value or base, or a value the scale cannot
  // show. [along] is the scale the rows run on, [across] the one of the
  // values.
  Rect? _rectOf(int i, double value, ChartScaleView along, ChartScaleView across, double half) {
    final double end = across.toPixel(value);
    final double base = _near(across.toPixel(_base(i)), across.extent);
    if (!end.isFinite || base.isNaN) return null;
    final double centre = data.x(i) + offset;
    final double from = _near(along.toPixel(centre - half), along.extent);
    final double to = _near(along.toPixel(centre + half), along.extent);
    if (from.isNaN || to.isNaN) return null;
    return _horizontal
        ? Rect.fromPoints(Offset(base, from), Offset(end, to))
        : Rect.fromPoints(Offset(from, base), Offset(to, end));
  }

  @override
  bool hitTest(Offset position, ChartView view) => false;

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    if (data.isEmpty || !view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) {
      return;
    }
    final ChartScaleView along = view.scale(_argumentScale);
    final ChartScaleView across = view.scale(_valueScale);
    if (along.extent <= 0 || across.extent <= 0) return;
    final double half = _half;
    final (int start, int end) = data.isSorted
        ? data.indexRange(along.min - offset - half, along.max - offset + half, overscan: 0)
        : (0, data.length);
    if (end <= start) return;
    final Color color = this.color ?? context.seriesColor;

    final double barPixels = along.lengthToPixels(half * 2, at: data.x(start));
    final Map<Color, ui.Path> paths = <Color, ui.Path>{};
    ui.Path pathFor(Color c) => paths[c] ??= ui.Path();

    if (barPixels < 1 && data.isSorted && colorOf == null && baseColumn == null) {
      // More bars than pixels: one bar per pixel that covers the extremes.
      final double base = _near(across.toPixel(baseline), across.extent);
      final ui.Path path = pathFor(color);
      final bool ascending = along.toPixel(along.max) >= along.toPixel(along.min);
      int row = start;
      for (int k = 0; k < along.extent.ceil() && row < end; k++) {
        final double edge = ascending
            ? along.toValue(k + 1.0)
            : along.toValue(along.extent - (k + 1.0));
        final int rowEnd = math.min(end, math.max(row, data.lowerBound(edge - offset)));
        if (rowEnd <= row) continue;
        final (double lo, double hi) = data.minMax(row, rowEnd, column: column);
        if (lo <= hi) {
          final double from = ascending ? k.toDouble() : along.extent - (k + 1.0);
          final double low = _near(across.toPixel(lo), across.extent);
          final double high = _near(across.toPixel(hi), across.extent);
          final double near = math.min(base, math.min(low, high));
          final double far = math.max(base, math.max(low, high));
          path.addRect(
            _horizontal
                ? Rect.fromLTRB(near, from, far, from + 1)
                : Rect.fromLTRB(from, near, from + 1, far),
          );
        }
        row = rowEnd;
      }
    } else {
      final double r = math.min(cornerRadius, barPixels / 2);
      for (int i = start; i < end; i++) {
        final double value = data.value(i, column);
        final Rect? rect = _rectOf(i, value, along, across, half);
        if (rect == null) continue;
        final ui.Path path = pathFor(colorOf?.call(i, data.x(i), value) ?? color);
        if (r > 0) {
          // Round only the end that points away from the base.
          final double tip = across.toPixel(value);
          final Radius corner = Radius.circular(
            math.min(r, _horizontal ? rect.width : rect.height),
          );
          final bool up = !_horizontal && tip <= rect.center.dy;
          final bool down = !_horizontal && !up;
          final bool right = _horizontal && tip >= rect.center.dx;
          final bool left = _horizontal && !right;
          path.addRRect(
            RRect.fromRectAndCorners(
              rect,
              topLeft: up || left ? corner : Radius.zero,
              topRight: up || right ? corner : Radius.zero,
              bottomLeft: down || left ? corner : Radius.zero,
              bottomRight: down || right ? corner : Radius.zero,
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

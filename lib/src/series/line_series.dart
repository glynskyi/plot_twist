import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// How consecutive points of a [LineSeries] are joined.
enum LineCurve {
  /// Straight segments.
  linear,

  /// Horizontal then vertical: the value holds until the next point.
  step,

  /// A smooth curve that never overshoots the data (monotone cubic).
  smooth,
}

/// Creates a shader for a series from the current view — for example a
/// gradient whose stops sit at data values.
typedef ChartShaderBuilder = ui.Shader Function(ChartView view);

/// A line (and optionally an area under it) through the rows of a [ChartData].
///
/// Only the visible part is processed, and when there are far more points than
/// pixels the line is reduced to the min/max of each pixel column, so a
/// million points pan smoothly while looking identical.
class LineSeries extends StatelessWidget {
  /// Creates a line series.
  const LineSeries({
    super.key,
    required this.data,
    this.column = 0,
    this.id,
    this.label,
    this.color,
    this.width = 2,
    this.curve = LineCurve.linear,
    this.dash,
    this.shader,
    this.fillColor,
    this.fillGradient,
    this.baseline,
    this.baseColumn,
    this.pointRadius = 0,
    this.visible = true,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.decimate = true,
    this.clip = true,
    this.isolate = true,
  });

  /// The data to plot.
  final ChartData data;

  /// Which value column of [data] to plot.
  final int column;

  /// Identifier of the series.
  final Object? id;

  /// Name of the series, for legends and tooltips.
  final String? label;

  /// Stroke colour. Defaults to the colour the palette of the chart theme
  /// has for the place of the series in the chart.
  final Color? color;

  /// Stroke width in logical pixels. `0` draws no line.
  final double width;

  /// How points are joined.
  final LineCurve curve;

  /// Dash pattern: lengths of alternating dashes and gaps.
  final List<double>? dash;

  /// Builds a shader for the stroke, replacing [color].
  final ChartShaderBuilder? shader;

  /// Fills the area between the line and [baseline] with a colour.
  final Color? fillColor;

  /// Fills the area between the line and [baseline] with a gradient spanning
  /// the plot.
  final Gradient? fillGradient;

  /// The data value the fill extends to. Null fills to the bottom of the plot.
  final double? baseline;

  /// A value column holding the lower edge of the area, instead of
  /// [baseline]: the area between two lines. With the layers of
  /// `ChartData.stacked` this draws a stacked area chart.
  ///
  /// The area is then filled also without a [fillColor] or [fillGradient],
  /// with the colour of the line at half its opacity. A row with a missing
  /// value in either column is a gap. Such a series is never reduced to the
  /// extremes of each pixel column, so it draws every visible row.
  final int? baseColumn;

  /// Radius of the dots drawn on data points when they are far enough apart.
  /// `0` draws none.
  final double pointRadius;

  /// Whether the series is shown; a hidden series stays listed for legends.
  final bool visible;

  /// Id of the horizontal scale.
  final Object xScale;

  /// Id of the vertical scale.
  final Object yScale;

  /// Whether dense data is reduced to per-pixel-column extremes.
  final bool decimate;

  /// Whether the line is clipped to the plot area.
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
      painter: LineSeriesPainter(
        data: data,
        column: column,
        color: color,
        width: width,
        curve: curve,
        dash: dash,
        shader: shader,
        fillColor: fillColor,
        fillGradient: fillGradient,
        baseline: baseline,
        baseColumn: baseColumn,
        pointRadius: pointRadius,
        xScale: xScale,
        yScale: yScale,
        decimate: decimate,
      ),
    );
  }
}

/// Paints a [LineSeries]. Built entirely on the public [ChartSeriesPainter]
/// contract.
class LineSeriesPainter extends ChartSeriesPainter {
  /// Creates a line painter.
  LineSeriesPainter({
    required this.data,
    this.column = 0,
    this.color,
    this.width = 2,
    this.curve = LineCurve.linear,
    this.dash,
    this.shader,
    this.fillColor,
    this.fillGradient,
    this.baseline,
    this.baseColumn,
    this.pointRadius = 0,
    this.decimate = true,
    super.xScale,
    super.yScale,
  }) : super(data: data);

  /// The data to plot.
  final ChartData data;

  /// Which value column to plot.
  final int column;

  /// Stroke colour; null uses `ChartPaintContext.seriesColor`.
  final Color? color;

  /// Stroke width.
  final double width;

  /// How points are joined.
  final LineCurve curve;

  /// Dash pattern.
  final List<double>? dash;

  /// Stroke shader builder.
  final ChartShaderBuilder? shader;

  /// Area fill colour.
  final Color? fillColor;

  /// Area fill gradient.
  final Gradient? fillGradient;

  /// Data value the fill extends to.
  final double? baseline;

  /// Radius of point dots.
  final double pointRadius;

  /// Whether dense data is decimated.
  final bool decimate;

  /// The value column holding the lower edge of the area, instead of
  /// [baseline].
  final int? baseColumn;

  bool get _hasFill => fillColor != null || fillGradient != null || baseColumn != null;

  @override
  bool shouldRepaint(LineSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate.column != column ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.curve != curve ||
      !listEquals(oldDelegate.dash, dash) ||
      oldDelegate.shader != shader ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.fillGradient != fillGradient ||
      oldDelegate.baseline != baseline ||
      oldDelegate.baseColumn != baseColumn ||
      oldDelegate.pointRadius != pointRadius ||
      oldDelegate.decimate != decimate;

  @override
  bool shouldRescale(LineSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate.column != column ||
      oldDelegate.baseline != baseline ||
      oldDelegate.baseColumn != baseColumn ||
      oldDelegate._hasFill != _hasFill;

  // ---------------------------------------------------------------- data

  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) {
    if (data.isEmpty) return null;
    ChartRange? y;
    if (xWindow != null && data.isSorted) {
      final (int start, int end) = data.indexRange(xWindow.min, xWindow.max, overscan: 0);
      y = data.valueExtent(column: column, start: start, end: end, within: yWindow);
      // The line also shows where it crosses the edges of the window.
      for (final double edge in <double>[xWindow.min, xWindow.max]) {
        final double? v = valueAt(edge);
        if (v != null && v.isFinite && (yWindow?.contains(v) ?? true)) {
          y = y == null ? ChartRange(v, v) : y.include(v);
        }
      }
    } else {
      y = data.valueExtent(column: column, within: yWindow);
    }
    final int? lower = baseColumn;
    final double? base = baseline;
    if (lower != null) {
      // The area reaches down to its base column, whatever the baseline is.
      int start = 0;
      int end = data.length;
      if (xWindow != null && data.isSorted) {
        (start, end) = data.indexRange(xWindow.min, xWindow.max, overscan: 0);
      }
      y = ChartRange.merge(
        y,
        data.valueExtent(column: lower, start: start, end: end, within: yWindow),
      );
    } else if (y != null && _hasFill && base != null && (yWindow?.contains(base) ?? true)) {
      y = y.include(base);
    }
    return ChartDataBounds(x: xWindow == null ? data.xExtent : data.xExtentWithin(xWindow), y: y);
  }

  /// The value of the drawn line at [x], or null outside the data, next to a
  /// gap, or when the rows are not sorted.
  ///
  /// A [LineCurve.smooth] line is shaped on screen. On a scale that is not
  /// linear, such as a logarithmic one, the result between two rows is close
  /// to the drawn curve but not exactly on it.
  @override
  double? valueAt(double x) {
    if (data.isEmpty || !data.isSorted) return null;
    switch (curve) {
      case LineCurve.linear:
        return data.interpolate(x, column: column);
      case LineCurve.step:
        final int i = data.upperBound(x) - 1;
        if (i < 0 || (i == data.length - 1 && x > data.x(i))) return null;
        final double v = data.value(i, column);
        return v.isNaN ? null : v;
      case LineCurve.smooth:
        return _smoothAt(x);
    }
  }

  double? _smoothAt(double x) {
    final int hi = data.lowerBound(x);
    if (hi >= data.length) return null;
    if (data.x(hi) == x) {
      final double v = data.value(hi, column);
      return v.isNaN ? null : v;
    }
    if (hi == 0) return null;
    final int lo = hi - 1;
    final double x0 = data.x(lo);
    final double x1 = data.x(hi);
    final double y0 = data.value(lo, column);
    final double y1 = data.value(hi, column);
    if (y0.isNaN || y1.isNaN || x1 == x0) return null;
    double tangent(int i, int before, int after) {
      final bool hasBefore = before >= 0 && !data.value(before, column).isNaN;
      final bool hasAfter = after < data.length && !data.value(after, column).isNaN;
      final double slope = (y1 - y0) / (x1 - x0);
      // At an end of the line, or next to a gap, the curve leaves along the
      // straight line to its only neighbour.
      if (!hasBefore || !hasAfter) return slope;
      return _steffen(
        data.x(before),
        data.value(before, column), //
        data.x(i),
        data.value(i, column),
        data.x(after),
        data.value(after, column),
      );
    }

    final double m0 = tangent(lo, lo - 1, hi);
    final double m1 = tangent(hi, lo, hi + 1);
    final double h = x1 - x0;
    final double t = (x - x0) / h;
    final double t2 = t * t;
    final double t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * y0 +
        (t3 - 2 * t2 + t) * h * m0 +
        (-2 * t3 + 3 * t2) * y1 +
        (t3 - t2) * h * m1;
  }

  // Steffen's monotone tangent at the middle of three points.
  static double _steffen(double x0, double y0, double x1, double y1, double x2, double y2) {
    final double h0 = x1 - x0;
    final double h1 = x2 - x1;
    if (h0 == 0 || h1 == 0) return 0;
    final double s0 = (y1 - y0) / h0;
    final double s1 = (y2 - y1) / h1;
    final double p = (s0 * h1 + s1 * h0) / (h0 + h1);
    final double sign =
        (s0 < 0 ? -1.0 : (s0 > 0 ? 1.0 : 0.0)) + (s1 < 0 ? -1.0 : (s1 > 0 ? 1.0 : 0.0));
    return sign * math.min(math.min(s0.abs(), s1.abs()), 0.5 * p.abs());
  }

  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    // The rows run along x, so none of them is the one at a given y.
    if (data.isEmpty || query.mode == ChartHitMode.nearestY) return;
    final ChartView view = query.view;
    if (!view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) return;
    final ChartScaleView xs = view.scale(xScale);
    final ChartScaleView ys = view.scale(yScale);

    ChartHit? hitFor(int i) {
      final double x = data.x(i);
      final double y = data.value(i, column);
      if (y.isNaN) return null;
      final Offset position = Offset(xs.toPixel(x), ys.toPixel(y));
      // A value the scale cannot show is not on the chart.
      if (!position.isFinite) return null;
      final double distance = query.mode == ChartHitMode.nearestX
          ? (position.dx - query.position.dx).abs()
          : (position - query.position).distance;
      if (distance > query.maxDistance) return null;
      final int? lower = baseColumn;
      return ChartHit(
        x: x,
        y: y,
        position: position,
        distance: distance,
        index: i,
        base: lower == null ? null : data.value(i, lower),
      );
    }

    if (query.mode == ChartHitMode.nearestX || !data.isSorted) {
      final int i = data.nearestIndex(xs.toValue(query.position.dx));
      if (i < 0) return;
      final ChartHit? hit = hitFor(i);
      if (hit != null) hits.add(hit);
      return;
    }
    // Nearest by distance: look at the rows around the pointer.
    final double radius = query.maxDistance.isFinite ? query.maxDistance : 24;
    final double a = xs.toValue(query.position.dx - radius);
    final double b = xs.toValue(query.position.dx + radius);
    final (int start, int end) = data.indexRange(math.min(a, b), math.max(a, b));
    ChartHit? best;
    final int stride = math.max(1, (end - start) ~/ 512);
    for (int i = start; i < end; i += stride) {
      final ChartHit? hit = hitFor(i);
      if (hit != null && (best == null || hit.distance < best.distance)) best = hit;
    }
    if (best != null) hits.add(best);
  }

  // --------------------------------------------------------------- paint

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    if (data.isEmpty || !view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) {
      return;
    }
    final ChartScaleView xs = view.scale(xScale);
    final ChartScaleView ys = view.scale(yScale);
    if (xs.extent <= 0 || ys.extent <= 0) return;
    final (int start, int end) = data.indexRange(xs.min, xs.max);
    if (end <= start) return;

    final _Polyline line = _Polyline();
    // The lower edge of the area, row for row with [line].
    final int? lower = baseColumn;
    final _Polyline? floor = lower == null ? null : _Polyline();
    final bool dense =
        decimate &&
        data.isSorted &&
        curve == LineCurve.linear &&
        floor == null &&
        (end - start) > xs.extent * 10;
    if (dense) {
      _collectDecimated(line, xs, ys, start, end);
    } else if (floor == null) {
      _collectAll(line, xs, ys, start, end);
    } else {
      _collectBand(line, floor, xs, ys, start, end, lower!);
    }
    if (line.isEmpty) return;
    // Zoomed deep into sparse data, the rows next to the window are far off
    // screen. Rasterizers should never see such coordinates, so nothing is
    // drawn further out than one plot width.
    final double reachMin = -xs.extent;
    final double reachMax = xs.extent * 2;
    final bool smooth = curve == LineCurve.smooth;
    // A smooth curve also depends on the row before its first point and the
    // one after its last. Without them the piece at the plot's edge would
    // change shape as rows come into view.
    Offset? before;
    Offset? after;
    Offset? floorBefore;
    Offset? floorAfter;
    if (smooth) {
      if (data.isSorted) {
        if (start > 0 && _pixelOf(start, xs, ys) != null) before = _pixelOf(start - 1, xs, ys);
        if (end < data.length && _pixelOf(end - 1, xs, ys) != null) after = _pixelOf(end, xs, ys);
        if (lower != null) {
          // The band breaks where either column has a gap, so both edges
          // have a neighbour or neither has.
          Offset? edge(int row) => _bandPixelOf(row, xs, ys, lower)?.$2;
          if (before != null) {
            floorBefore = edge(start - 1);
            if (floorBefore == null || edge(start) == null) before = floorBefore = null;
          }
          if (after != null) {
            floorAfter = edge(end);
            if (floorAfter == null || edge(end - 1) == null) after = floorAfter = null;
          }
        }
      }
    } else {
      line.clampEnds(reachMin, reachMax, step: curve == LineCurve.step);
      floor?.clampEnds(reachMin, reachMax, step: curve == LineCurve.step);
    }

    // Adds the points [from, to) of [line] to [path] and returns the x of the
    // two ends of what was added, or null when nothing was.
    (double, double)? addCurveOf(
      _Polyline line,
      ui.Path path,
      int from,
      int to, {
      Offset? before,
      Offset? after,
    }) {
      if (smooth) {
        return _addSmooth(
          path,
          line,
          from,
          to,
          before: from == 0 ? before : null,
          after: to == line.length ? after : null,
          min: reachMin,
          max: reachMax,
          cut: data.isSorted,
        );
      }
      _addSegment(path, line, from, to);
      return (line.x(from), line.x(to - 1));
    }

    (double, double)? addCurve(ui.Path path, int from, int to) =>
        addCurveOf(line, path, from, to, before: before, after: after);

    final Canvas canvas = context.canvas;
    final Rect plot = Offset.zero & view.size;
    final Color color = this.color ?? context.seriesColor;

    if (_hasFill) {
      // A base the scale cannot show is the edge of the plot.
      final double base = baseline == null || floor != null
          ? ys.extent * 2
          : ys.toPixel(baseline!).clamp(-ys.extent, ys.extent * 2);
      final ui.Path fill = ui.Path();
      void addArea(_Polyline edge, int from, int to, {Offset? before, Offset? after}) {
        final (double, double)? ends = addCurveOf(
          edge,
          fill,
          from,
          to,
          before: before,
          after: after,
        );
        if (ends == null) return;
        fill.lineTo(ends.$2, base);
        fill.lineTo(ends.$1, base);
        fill.close();
      }

      if (floor == null) {
        final double bottom = baseline == null ? view.size.height : base;
        line.forEachSegment((int from, int to) {
          if (to - from < 2) return;
          final (double, double)? ends = addCurve(fill, from, to);
          if (ends == null) return;
          fill.lineTo(ends.$2, bottom);
          fill.lineTo(ends.$1, bottom);
          fill.close();
        });
      } else {
        // The area under the line and the area under its lower edge, both
        // down to the same level far below the plot. Filled by the even-odd
        // rule, what is left is the part between the two, also where they
        // cross.
        fill.fillType = ui.PathFillType.evenOdd;
        line.forEachSegment((int from, int to) {
          if (to - from < 2) return;
          addArea(line, from, to, before: before, after: after);
          addArea(floor, from, to, before: floorBefore, after: floorAfter);
        });
      }
      final Paint paint = Paint()..style = PaintingStyle.fill;
      final Gradient? gradient = fillGradient;
      if (gradient != null) {
        paint.shader = gradient.createShader(plot);
      } else {
        paint.color = fillColor ?? color.withValues(alpha: color.a / 2);
      }
      canvas.drawPath(fill, paint);
    }

    if (width > 0) {
      final List<double>? pattern = dash;
      final bool dashed = pattern != null && pattern.isNotEmpty;
      ui.Path path = ui.Path();
      // The piece of a dashed line that the window cuts off at its start is
      // dashed on its own, from where the pattern has got to by then.
      final ui.Path head = ui.Path();
      double headPhase = 0;
      line.forEachSegment((int from, int to) {
        if (to - from == 1) {
          // A lone point between gaps: draw it as a dot-sized segment.
          path.moveTo(line.x(from), line.y(from));
          path.lineTo(line.x(from) + 0.01, line.y(from));
        } else if (dashed && from == 0 && !dense) {
          final (double, double)? ends = addCurve(head, from, to);
          if (ends != null) {
            headPhase = _dashPhase(xs, ys, start, smooth ? ends.$1 : line.x(0), line.y(0));
          }
        } else {
          addCurve(path, from, to);
        }
      });
      if (dashed) {
        path = ChartPainter.dashPath(path, pattern)
          ..addPath(ChartPainter.dashPath(head, pattern, phase: headPhase), Offset.zero);
      }
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = pattern == null ? StrokeCap.round : StrokeCap.butt
        ..color = color;
      final ChartShaderBuilder? builder = shader;
      if (builder != null) paint.shader = builder(view);
      canvas.drawPath(path, paint);
    }

    if (pointRadius > 0 && !dense) {
      final int count = line.length;
      final double spacing = xs.extent / math.max(1, end - start);
      if (spacing >= pointRadius * 3) {
        final Float32List points = Float32List(count * 2);
        int n = 0;
        for (int i = 0; i < count; i++) {
          final double px = line.x(i);
          if (px < reachMin || px > reachMax) continue;
          points[n++] = px;
          points[n++] = line.y(i);
        }
        canvas.drawRawPoints(
          ui.PointMode.points,
          Float32List.sublistView(points, 0, n),
          Paint()
            ..color = color
            ..strokeCap = StrokeCap.round
            ..strokeWidth = pointRadius * 2,
        );
      }
    }
  }

  // Rows a dash pattern is measured back over, at most.
  static const int _dashBlock = 4096;

  // How far into its dash pattern the line is at ([firstX], [firstY]), where
  // its path starts.
  //
  // The path starts at the first row near the window, and further in when
  // that row is far away. Dashes counted from there would jump along the line
  // whenever a row leaves the window. So the length of the line is measured
  // back to where it really starts: after a gap, or else at the start of the
  // block of [_dashBlock] rows that [start] is in.
  double _dashPhase(ChartScaleView xs, ChartScaleView ys, int start, double firstX, double firstY) {
    if (!data.isSorted) return 0;
    final Offset? origin = _pixelOf(start, xs, ys);
    if (origin == null) return 0;
    // The rows before [start], nearest first.
    final List<Offset> back = <Offset>[];
    final int floor = start - start % _dashBlock;
    int anchor = start;
    for (; anchor > floor; anchor--) {
      final Offset? pixel = _pixelOf(anchor - 1, xs, ys);
      if (pixel == null) break;
      back.add(pixel);
    }
    double length = 0;
    switch (curve) {
      case LineCurve.linear:
        Offset to = origin;
        for (final Offset from in back) {
          length += (to - from).distance;
          to = from;
        }
        return length + (Offset(firstX, firstY) - origin).distance;
      case LineCurve.step:
        Offset to = origin;
        for (final Offset from in back) {
          length += (to.dx - from.dx).abs() + (to.dy - from.dy).abs();
          to = from;
        }
        // A step is level until the next row.
        return length + (firstX - origin.dx).abs();
      case LineCurve.smooth:
        // Measured around the first row, so the result is the same wherever
        // the line has been panned to.
        final _Polyline lead = _Polyline();
        for (final Offset pixel in back.reversed) {
          lead.add(pixel.dx - origin.dx, pixel.dy - origin.dy);
        }
        lead.add(0, 0);
        Offset? relative(int row) {
          final Offset? pixel = row >= 0 && row < data.length ? _pixelOf(row, xs, ys) : null;
          return pixel == null ? null : pixel - origin;
        }
        final Offset? next = relative(start + 1);
        if (next != null) lead.add(next.dx, next.dy);
        final bool ascending = xs.toPixel(xs.max) >= xs.toPixel(xs.min);
        final double cutAt = firstX - origin.dx;
        final ui.Path path = ui.Path();
        _addSmooth(
          path,
          lead,
          0,
          lead.length,
          before: anchor > floor || anchor == 0 ? null : relative(anchor - 1),
          after: next == null ? null : relative(start + 2),
          min: ascending ? double.negativeInfinity : cutAt,
          max: ascending ? cutAt : double.infinity,
          cut: true,
        );
        for (final ui.PathMetric metric in path.computeMetrics()) {
          length += metric.length;
        }
        return length;
    }
  }

  // The pixel positions of the line and of its lower edge in row [i], or null
  // when the row is a gap in either. A lower edge the scale cannot show is at
  // the edge of the plot it lies beyond.
  (Offset, Offset)? _bandPixelOf(int i, ChartScaleView xs, ChartScaleView ys, int lower) {
    final Offset? top = _pixelOf(i, xs, ys);
    final double base = data.value(i, lower);
    if (top == null || base.isNaN) return null;
    final double py = ys.toPixel(base).clamp(-ys.extent, ys.extent * 2);
    return py.isNaN ? null : (top, Offset(top.dx, py));
  }

  // Adds the rows to the line and to its lower edge, breaking both at a gap.
  void _collectBand(
    _Polyline line,
    _Polyline floor,
    ChartScaleView xs,
    ChartScaleView ys,
    int start,
    int end,
    int lower,
  ) {
    for (int i = start; i < end; i++) {
      final (Offset, Offset)? pixels = _bandPixelOf(i, xs, ys, lower);
      if (pixels == null) {
        line.breakSegment();
        floor.breakSegment();
      } else {
        line.add(pixels.$1.dx, pixels.$1.dy);
        floor.add(pixels.$2.dx, pixels.$2.dy);
      }
    }
  }

  void _collectAll(_Polyline out, ChartScaleView xs, ChartScaleView ys, int start, int end) {
    for (int i = start; i < end; i++) {
      _addRow(out, xs, ys, i);
    }
  }

  // The pixel position of row [i], or null when the row is a gap.
  Offset? _pixelOf(int i, ChartScaleView xs, ChartScaleView ys) {
    final double v = data.value(i, column);
    if (v.isNaN) return null;
    final Offset pixel = Offset(xs.toPixel(data.x(i)), ys.toPixel(v));
    return pixel.isFinite ? pixel : null;
  }

  // Adds row [i] to the line, or breaks the line there when the row is a gap:
  // a missing value, or one that the scales cannot show (an infinite value,
  // or zero on a logarithmic scale).
  void _addRow(_Polyline out, ChartScaleView xs, ChartScaleView ys, int i) {
    final double v = data.value(i, column);
    if (!v.isNaN) {
      final double px = xs.toPixel(data.x(i));
      final double py = ys.toPixel(v);
      if (px.isFinite && py.isFinite) {
        out.add(px, py);
        return;
      }
    }
    out.breakSegment();
  }

  // Reduces each half-pixel sliver of the plot to its first, lowest, highest
  // and last value.
  void _collectDecimated(_Polyline out, ChartScaleView xs, ChartScaleView ys, int start, int end) {
    // Half-pixel columns: narrower than the stroke, so the reduced line is
    // as bold as the full one, and fine enough for high-density screens.
    const double columnWidth = 0.5;
    final int columns = (xs.extent / columnWidth).ceil();
    final bool ascending = xs.toPixel(xs.max) >= xs.toPixel(xs.min);
    double boundary(int k) => ascending
        ? xs.toValue((k + 1) * columnWidth)
        : xs.toValue(xs.extent - (k + 1) * columnWidth);

    void raw(int from, int to) {
      for (int i = from; i < to; i++) {
        _addRow(out, xs, ys, i);
      }
    }

    // Values the y scale cannot show are drawn at the edge they lie beyond.
    double py(double v) => ys.toPixel(v).clamp(-ys.extent, ys.extent * 2);

    int row = start;
    final int firstVisible = math.min(end, math.max(start, data.lowerBound(xs.min)));
    raw(row, firstVisible);
    row = firstVisible;
    for (int k = 0; k < columns && row < end; k++) {
      final int rowEnd = math.min(end, math.max(row, data.lowerBound(boundary(k))));
      final int n = rowEnd - row;
      if (n <= 0) continue;
      if (n <= 4) {
        raw(row, rowEnd);
      } else {
        // Many rows in a sliver narrower than the stroke. Stroking them all
        // paints a solid block: as tall as their lowest and highest value,
        // and as wide as the sliver plus the stroke. Trace that block's
        // outline, entering at the first row and leaving at the last so
        // neighbouring slivers stay connected.
        final (double lo, double hi) = data.minMax(row, rowEnd, column: column);
        if (lo > hi) {
          out.breakSegment();
        } else {
          final double px0 = xs.toPixel(data.x(row));
          final double px1 = xs.toPixel(data.x(rowEnd - 1));
          final double first = data.value(row, column);
          final double last = data.value(rowEnd - 1, column);
          final bool lowFirst = first.isNaN || (first - lo).abs() <= (first - hi).abs();
          final double near = py(lowFirst ? lo : hi);
          final double far = py(lowFirst ? hi : lo);
          if (first.isFinite) out.add(px0, py(first));
          out.add(px0, near);
          out.add(px0, far);
          out.add(px1, far);
          out.add(px1, near);
          if (last.isFinite) out.add(px1, py(last));
        }
      }
      row = rowEnd;
    }
    raw(row, end);
  }

  // Adds the straight or stepped line through the points [from, to).
  void _addSegment(ui.Path path, _Polyline line, int from, int to) {
    path.moveTo(line.x(from), line.y(from));
    if (curve == LineCurve.step) {
      for (int i = from + 1; i < to; i++) {
        path.lineTo(line.x(i), line.y(i - 1));
        path.lineTo(line.x(i), line.y(i));
      }
    } else {
      for (int i = from + 1; i < to; i++) {
        path.lineTo(line.x(i), line.y(i));
      }
    }
  }

  // Adds the smooth curve through the points [from, to) and returns the x of
  // its two ends, or null when none of it is between [min] and [max].
  //
  // [before] and [after] are the positions of the rows next to the first and
  // the last point, when the line goes on there. With [cut], only the part
  // between [min] and [max] is added. Each piece between two points is a
  // cubic, and a part of a cubic is a cubic again, so cutting keeps the shape
  // exactly; pulling a far point in would bend the curve.
  (double, double)? _addSmooth(
    ui.Path path,
    _Polyline line,
    int from,
    int to, {
    required Offset? before,
    required Offset? after,
    required double min,
    required double max,
    required bool cut,
  }) {
    // The slope of the curve at point [i]: Steffen's monotone tangent between
    // two neighbours, the straight line to the only neighbour at an end.
    double tangentAt(int i) {
      final double x = line.x(i);
      final double y = line.y(i);
      final bool hasPrevious = i > from || before != null;
      final bool hasNext = i < to - 1 || after != null;
      final double px = i > from ? line.x(i - 1) : (before?.dx ?? 0);
      final double py = i > from ? line.y(i - 1) : (before?.dy ?? 0);
      final double nx = i < to - 1 ? line.x(i + 1) : (after?.dx ?? 0);
      final double ny = i < to - 1 ? line.y(i + 1) : (after?.dy ?? 0);
      if (hasPrevious && hasNext) return _steffen(px, py, x, y, nx, ny);
      if (hasNext) return (ny - y) / _nonZero(nx - x);
      return (y - py) / _nonZero(x - px);
    }

    double? first;
    double last = 0;
    bool penDown = false;
    double m0 = tangentAt(from);
    for (int i = from; i < to - 1; i++) {
      final double m1 = tangentAt(i + 1);
      final double x0 = line.x(i);
      final double y0 = line.y(i);
      final double x1 = line.x(i + 1);
      final double y1 = line.y(i + 1);
      final double h = x1 - x0;
      // The part of this piece to draw, as fractions of its width.
      double a = 0;
      double b = 1;
      if (cut && h != 0) {
        if (math.max(x0, x1) < min || math.min(x0, x1) > max) {
          penDown = false;
          m0 = m1;
          continue;
        }
        a = (x0.clamp(min, max) - x0) / h;
        b = (x1.clamp(min, max) - x0) / h;
      }
      // The piece as a Bezier curve: x is linear, these are the y ordinates.
      final double c1 = y0 + m0 * h / 3;
      final double c2 = y1 - m1 * h / 3;
      if (a <= 0 && b >= 1) {
        if (!penDown) path.moveTo(x0, y0);
        path.cubicTo(x0 + h / 3, c1, x1 - h / 3, c2, x1, y1);
        first ??= x0;
        last = x1;
      } else {
        final double xa = x0 + h * a;
        final double xb = x0 + h * b;
        final double third = (xb - xa) / 3;
        if (!penDown) path.moveTo(xa, _blossom(y0, c1, c2, y1, a, a, a));
        path.cubicTo(
          xa + third,
          _blossom(y0, c1, c2, y1, a, a, b),
          xb - third,
          _blossom(y0, c1, c2, y1, a, b, b),
          xb,
          _blossom(y0, c1, c2, y1, b, b, b),
        );
        first ??= xa;
        last = xb;
      }
      penDown = true;
      m0 = m1;
    }
    return first == null ? null : (first, last);
  }

  // The blossom of the cubic with Bezier ordinates [p0] to [p3]: its value at
  // (t, t, t) is the curve at t, and the values at (a, a, b) and (a, b, b)
  // are the inner ordinates of the part between a and b.
  static double _blossom(double p0, double p1, double p2, double p3, double u, double v, double w) {
    final double q0 = p0 + (p1 - p0) * u;
    final double q1 = p1 + (p2 - p1) * u;
    final double q2 = p2 + (p3 - p2) * u;
    final double r0 = q0 + (q1 - q0) * v;
    final double r1 = q1 + (q2 - q1) * v;
    return r0 + (r1 - r0) * w;
  }

  static double _nonZero(double v) => v == 0 ? 1e-9 : v;
}

// A growable list of pixel points split into segments (at data gaps).
class _Polyline {
  Float64List _points = Float64List(512);
  int _count = 0;
  final List<int> _starts = <int>[0];

  int get length => _count;
  bool get isEmpty => _count == 0;

  double x(int i) => _points[i * 2];
  double y(int i) => _points[i * 2 + 1];

  void add(double x, double y) {
    if (_count * 2 + 2 > _points.length) {
      _points = Float64List(_points.length * 2)..setRange(0, _count * 2, _points);
    }
    _points[_count * 2] = x;
    _points[_count * 2 + 1] = y;
    _count++;
  }

  void breakSegment() {
    if (_starts.last != _count) _starts.add(_count);
  }

  void forEachSegment(void Function(int from, int to) visit) {
    for (int s = 0; s < _starts.length; s++) {
      final int from = _starts[s];
      final int to = s + 1 < _starts.length ? _starts[s + 1] : _count;
      if (to > from) visit(from, to);
    }
  }

  // Pulls far off-screen end points in along their segment, so rasterizers
  // never see huge coordinates when zoomed deep into sparse data.
  //
  // A stepped line ([step]) is level between two points, at the value of the
  // first one, so its end points move sideways only.
  void clampEnds(double min, double max, {bool step = false}) {
    forEachSegment((int from, int to) {
      if (to - from < 2) return;
      _clamp(from, from + 1, min, max, level: step ? y(from) : null);
      _clamp(to - 1, to - 2, min, max, level: step ? y(to - 2) : null);
    });
  }

  void _clamp(int end, int neighbour, double min, double max, {double? level}) {
    final double x0 = x(end);
    final double bound = x0 < min ? min : (x0 > max ? max : x0);
    if (bound == x0) return;
    final double x1 = x(neighbour);
    if (x1 == x0) return;
    final double t = (bound - x0) / (x1 - x0);
    if (t <= 0 || t >= 1) return;
    _points[end * 2] = bound;
    _points[end * 2 + 1] = level ?? y(end) + (y(neighbour) - y(end)) * t;
  }
}

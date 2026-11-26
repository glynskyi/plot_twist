import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// A line around the centre of a polar chart: the outline of a radar chart.
///
/// ```dart
/// PolarChart(
///   angle: const ChartScale.band(labels: ['Speed', 'Range', 'Comfort', 'Price']),
///   radius: const LinearScale(range: FixedRange(0, 10)),
///   children: [
///     const ChartPolarGrid(),
///     RadarSeries(data: ChartData.fromValues([8, 6, 7, 4]), label: 'Model A'),
///     RadarSeries(data: ChartData.fromValues([5, 9, 6, 8]), label: 'Model B'),
///   ],
/// )
/// ```
///
/// The x of a row is on the angle scale and its value on the radius scale.
/// With a band scale for the angles, row `i` points at category `i` and the
/// first category points straight up. The line is [closed] into a shape and
/// filled with [fillColor]. A row with a missing value breaks the line.
///
/// With `ChartCrosshair.point()` and a `ChartTooltip`, pointing anywhere in
/// the circle picks the nearest category and lists every series there.
class RadarSeries extends StatelessWidget {
  /// Creates a radar series.
  const RadarSeries({
    super.key,
    required this.data,
    this.column = 0,
    this.id,
    this.label,
    this.color,
    this.width = 2,
    this.fill = true,
    this.fillColor,
    this.pointRadius = 3,
    this.closed = true,
    this.visible = true,
    this.isolate = true,
  });

  /// The data to plot: one corner per row.
  final ChartData data;

  /// The value column holding the distance from the centre.
  final int column;

  /// Identifier of the series.
  final Object? id;

  /// Name of the series, for legends and tooltips.
  final String? label;

  /// Colour of the line and the dots. Defaults to the colour the palette of
  /// the chart theme has for the place of the series in the chart.
  final Color? color;

  /// Width of the line in logical pixels; zero draws none.
  final double width;

  /// Whether the shape inside the line is filled.
  final bool fill;

  /// Colour of the fill. Defaults to the colour of the line at a quarter of
  /// its opacity.
  final Color? fillColor;

  /// Radius of the dot on each corner, in logical pixels; zero draws none.
  final double pointRadius;

  /// Whether the last row is joined to the first.
  final bool closed;

  /// Whether the series is shown; a hidden series stays listed for legends.
  final bool visible;

  /// Whether the series paints into its own compositing layer.
  final bool isolate;

  @override
  Widget build(BuildContext context) {
    return ChartPaint(
      id: id,
      label: label,
      color: color,
      visible: visible,
      clip: false,
      isolate: isolate,
      painter: RadarSeriesPainter(
        data: data,
        polar: ChartPolarScope.of(context),
        column: column,
        color: color,
        width: width,
        fill: fill,
        fillColor: fillColor,
        pointRadius: pointRadius,
        closed: closed,
      ),
    );
  }
}

/// Paints a [RadarSeries]. Built entirely on the public [ChartSeriesPainter]
/// contract.
class RadarSeriesPainter extends ChartSeriesPainter {
  /// Creates a radar painter.
  RadarSeriesPainter({
    required this.data,
    required ChartPolar polar,
    this.column = 0,
    this.color,
    this.width = 2,
    this.fill = true,
    this.fillColor,
    this.pointRadius = 3,
    this.closed = true,
  }) : _polar = polar,
       super(data: data, xScale: polar.angleScale, yScale: polar.radiusScale);

  /// The data to plot.
  final ChartData data;

  final ChartPolar _polar;

  @override
  ChartPolar get polar => _polar;

  /// The value column holding the distance from the centre.
  final int column;

  /// Colour of the line; null uses `ChartPaintContext.seriesColor`.
  final Color? color;

  /// Width of the line in logical pixels.
  final double width;

  /// Whether the shape inside the line is filled.
  final bool fill;

  /// Colour of the fill.
  final Color? fillColor;

  /// Radius of the dot on each corner.
  final double pointRadius;

  /// Whether the last row is joined to the first.
  final bool closed;

  @override
  bool shouldRepaint(RadarSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate._polar != _polar ||
      oldDelegate.column != column ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.fill != fill ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.pointRadius != pointRadius ||
      oldDelegate.closed != closed;

  @override
  bool shouldRescale(RadarSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) || oldDelegate.column != column;

  /// The rows are on the angle scale and the values on the radius scale.
  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) {
    if (data.isEmpty) return null;
    return ChartDataBounds(
      x: data.xExtent,
      y: data.valueExtent(column: column, within: yWindow),
    );
  }

  bool _has(ChartView view) =>
      data.isNotEmpty && view.scales.containsKey(xScale) && view.scales.containsKey(yScale);

  // The pixel of row [i], or null when its value is missing.
  Offset? _point(ChartPolarView circle, int i) {
    final double value = data.value(i, column);
    if (!value.isFinite) return null;
    final Offset point = circle.toPixel(data.x(i), value);
    return point.isFinite ? point : null;
  }

  ChartHit _hitOf(int i, Offset position, double distance) => ChartHit(
    x: data.x(i),
    y: data.value(i, column),
    position: position,
    distance: distance,
    index: i,
  );

  /// Finds the row whose angle is nearest to the position of a query. Its
  /// distance is zero anywhere inside the circle and grows outside it, so
  /// every series of a radar chart answers with the same category. A radar
  /// series answers `ChartHitMode.nearest` only.
  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    if (query.mode != ChartHitMode.nearest || !_has(query.view)) return;
    final ChartPolarView circle = _polar.resolve(query.view);
    final Offset d = query.position - circle.center;
    final double distance = math.max(0, d.distance - circle.radius);
    if (distance > query.maxDistance) return;
    final double pointer = math.atan2(d.dy, d.dx);
    int best = -1;
    double bestTurn = double.infinity;
    for (int i = 0; i < data.length; i++) {
      if (!data.value(i, column).isFinite) continue;
      // The smaller of the two ways around the circle.
      final double turn =
          ((circle.angleOf(data.x(i)) - pointer + math.pi) % (2 * math.pi) - math.pi).abs();
      if (turn < bestTurn) {
        bestTurn = turn;
        best = i;
      }
    }
    final Offset? position = best < 0 ? null : _point(circle, best);
    if (position != null) hits.add(_hitOf(best, position, distance));
  }

  @override
  void visitMarks(ChartView view, bool Function(ChartHit mark) visit) {
    if (!_has(view)) return;
    final ChartPolarView circle = _polar.resolve(view);
    for (int i = 0; i < data.length; i++) {
      final Offset? position = _point(circle, i);
      if (position != null && !visit(_hitOf(i, position, 0))) return;
    }
  }

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    if (!_has(view)) return;
    final ChartPolarView circle = _polar.resolve(view);
    if (!(circle.radius > 0)) return;
    final List<Offset?> points = <Offset?>[for (int i = 0; i < data.length; i++) _point(circle, i)];
    // A line all the way round is one closed shape; a missing value leaves
    // open runs.
    final bool whole = closed && points.length > 2 && !points.contains(null);
    final ui.Path line = ui.Path();
    bool pen = false;
    for (final Offset? point in points) {
      if (point == null) {
        pen = false;
      } else if (pen) {
        line.lineTo(point.dx, point.dy);
      } else {
        line.moveTo(point.dx, point.dy);
        pen = true;
      }
    }
    if (whole) {
      line.close();
    } else if (closed && points.length > 2 && points.first != null && points.last != null) {
      // Join the two ends that meet where the circle closes.
      line
        ..moveTo(points.last!.dx, points.last!.dy)
        ..lineTo(points.first!.dx, points.first!.dy);
    }
    final Color color = this.color ?? context.seriesColor;
    final Canvas canvas = context.canvas;
    if (fill && whole) {
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.fill
          ..color = fillColor ?? color.withValues(alpha: color.a * 0.25),
      );
    }
    if (width > 0) {
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
    if (pointRadius > 0) {
      final Paint dot = Paint()..color = color;
      for (final Offset? point in points) {
        if (point != null) canvas.drawCircle(point, pointRadius, dot);
      }
    }
  }
}

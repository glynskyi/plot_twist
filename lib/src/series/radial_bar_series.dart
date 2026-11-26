import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Bars bent around the centre of a polar chart: a gauge, a progress ring,
/// or one ring per row of a [ChartData].
///
/// ```dart
/// PolarChart(
///   angle: const LinearScale(range: FixedRange(0, 100)),
///   innerRadius: 0.8,
///   children: [RadialBarSeries(data: ChartData.fromValues([72]), track: true)],
/// )
/// ```
///
/// The value of a row is on the angle scale: its bar runs from [baseline], or
/// from the value in [baseColumn], around the circle to the value. A value
/// beyond the scale stops at its end. The x of a row is on the radius scale:
/// the ring is centred there and [widthFactor] × [step] wide. A single row
/// on the default radius scale fills the space between the inner and the
/// outer radius of the chart.
///
/// For rings in different colours with a legend, as in an activity display,
/// give each ring a series of its own: one row each, at x = 0, 1, 2 and so
/// on, with the same [step].
class RadialBarSeries extends StatelessWidget {
  /// Creates a radial bar series.
  const RadialBarSeries({
    super.key,
    required this.data,
    this.column = 0,
    this.baseColumn,
    this.baseline = 0,
    this.id,
    this.label,
    this.color,
    this.colorOf,
    this.widthFactor = 0.7,
    this.step,
    this.cap = StrokeCap.butt,
    this.track = false,
    this.trackColor,
    this.visible = true,
    this.isolate = true,
  });

  /// The data to plot: one ring per row.
  final ChartData data;

  /// The value column holding the end of each bar.
  final int column;

  /// The value column holding the start of each bar; null uses [baseline].
  final int? baseColumn;

  /// The value bars start from when [baseColumn] is null.
  final double baseline;

  /// Identifier of the series.
  final Object? id;

  /// Name of the series, for legends and tooltips.
  final String? label;

  /// Bar colour. Defaults to the colour the palette of the chart theme has
  /// for the place of the series in the chart.
  final Color? color;

  /// Per-bar colour; return null to use [color].
  final ChartBarColor? colorOf;

  /// Thickness of a ring as a fraction of [step]. Defaults to `0.7`.
  final double widthFactor;

  /// Distance between two rings in data units. Defaults to the distance
  /// between the first two rows, or to 1.
  final double? step;

  /// The shape of the ends of a bar: `StrokeCap.butt` cuts them straight,
  /// `StrokeCap.round` rounds them. The round end stays within the value: it
  /// does not reach beyond it.
  final StrokeCap cap;

  /// Whether each ring is drawn in full behind its bar, in [trackColor].
  final bool track;

  /// Colour of the track. Defaults to the grid colour of the chart theme.
  final Color? trackColor;

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
      painter: RadialBarSeriesPainter(
        data: data,
        polar: ChartPolarScope.of(context),
        column: column,
        baseColumn: baseColumn,
        baseline: baseline,
        color: color,
        colorOf: colorOf,
        widthFactor: widthFactor,
        step: step,
        cap: cap,
        trackColor: track ? trackColor ?? ChartTheme.of(context).gridColor : null,
      ),
    );
  }
}

/// Paints a [RadialBarSeries]. Built entirely on the public
/// [ChartSeriesPainter] contract.
class RadialBarSeriesPainter extends ChartSeriesPainter {
  /// Creates a radial bar painter.
  RadialBarSeriesPainter({
    required this.data,
    required ChartPolar polar,
    this.column = 0,
    this.baseColumn,
    this.baseline = 0,
    this.color,
    this.colorOf,
    this.widthFactor = 0.7,
    this.step,
    this.cap = StrokeCap.butt,
    this.trackColor,
  }) : _polar = polar,
       super(data: data, xScale: polar.angleScale, yScale: polar.radiusScale);

  /// The data to plot.
  final ChartData data;

  final ChartPolar _polar;

  @override
  ChartPolar get polar => _polar;

  /// The value column holding the end of each bar.
  final int column;

  /// The value column holding the start of each bar.
  final int? baseColumn;

  /// The value bars start from.
  final double baseline;

  /// Bar colour; null uses `ChartPaintContext.seriesColor`.
  final Color? color;

  /// Per-bar colour.
  final ChartBarColor? colorOf;

  /// Thickness of a ring as a fraction of the step.
  final double widthFactor;

  /// Distance between two rings in data units.
  final double? step;

  /// The shape of the ends of a bar.
  final StrokeCap cap;

  /// Colour of the full ring behind each bar; null draws none.
  final Color? trackColor;

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
  bool shouldRepaint(RadialBarSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate._polar != _polar ||
      oldDelegate.column != column ||
      oldDelegate.baseColumn != baseColumn ||
      oldDelegate.baseline != baseline ||
      oldDelegate.color != color ||
      oldDelegate.colorOf != colorOf ||
      oldDelegate.widthFactor != widthFactor ||
      oldDelegate.step != step ||
      oldDelegate.cap != cap ||
      oldDelegate.trackColor != trackColor;

  @override
  bool shouldRescale(RadialBarSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate.column != column ||
      oldDelegate.baseColumn != baseColumn ||
      oldDelegate.baseline != baseline ||
      oldDelegate.widthFactor != widthFactor ||
      oldDelegate.step != step;

  /// The values are on the angle scale and the rings on the radius scale.
  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) {
    if (data.isEmpty) return null;
    ChartRange? value = data.valueExtent(column: column, within: xWindow);
    final int? base = baseColumn;
    if (base == null) {
      if (xWindow?.contains(baseline) ?? true) value = value?.include(baseline);
    } else {
      value = ChartRange.merge(value, data.valueExtent(column: base, within: xWindow));
    }
    final ChartRange? rows = data.xExtent;
    final double half = _half;
    return ChartDataBounds(
      x: value,
      y: rows == null ? null : ChartRange(rows.min - half, rows.max + half),
    );
  }

  // The ring of row [i] from the value [from] to the value [to] of the angle
  // scale, both cut off at the ends of that scale.
  ChartSector _ring(ChartPolarView circle, int i, double from, double to) {
    final double a = circle.angleFraction(from).clamp(0.0, 1.0);
    final double b = circle.angleFraction(to).clamp(0.0, 1.0);
    final double half = _half;
    final double r0 = circle.radiusOf(data.x(i) - half);
    final double r1 = circle.radiusOf(data.x(i) + half);
    return ChartSector(
      center: circle.center,
      innerRadius: math.max(0, math.min(r0, r1)),
      outerRadius: math.max(r0, r1),
      startAngle: _polar.startAngle + _polar.sweepAngle * a,
      sweepAngle: _polar.sweepAngle * (b - a),
    );
  }

  // Calls [visit] with the bar of every row that has one, until it returns
  // false.
  void _bars(ChartPolarView circle, bool Function(int index, ChartSector sector) visit) {
    if (!(circle.radius > 0)) return;
    for (int i = 0; i < data.length; i++) {
      final double value = data.value(i, column);
      final double base = _base(i);
      if (!value.isFinite || !base.isFinite) continue;
      final ChartSector sector = _ring(circle, i, base, value);
      if (!(sector.outerRadius > sector.innerRadius)) continue;
      if (!visit(i, sector)) return;
    }
  }

  bool _has(ChartView view) =>
      data.isNotEmpty && view.scales.containsKey(xScale) && view.scales.containsKey(yScale);

  ChartHit _hitOf(int i, ChartSector sector, double distance) {
    final double value = data.value(i, column);
    return ChartHit(
      x: value,
      y: data.x(i),
      // Where the value is drawn: the middle of the end of the bar.
      position: sector.pointAt(sector.startAngle + sector.sweepAngle, sector.middleRadius),
      distance: distance,
      index: i,
      sector: sector,
      base: _base(i),
      valueAxis: Axis.horizontal,
      color: colorOf?.call(i, data.x(i), value),
    );
  }

  /// Finds the bar at the position of a query, or the nearest one within its
  /// `maxDistance`. Radial bars answer `ChartHitMode.nearest` only.
  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    if (query.mode != ChartHitMode.nearest || !_has(query.view)) return;
    ChartHit? best;
    _bars(_polar.resolve(query.view), (int i, ChartSector sector) {
      final double distance = sector.distanceTo(query.position);
      if (distance <= query.maxDistance && (best == null || distance < best!.distance)) {
        best = _hitOf(i, sector, distance);
      }
      return true;
    });
    if (best != null) hits.add(best!);
  }

  @override
  void visitMarks(ChartView view, bool Function(ChartHit mark) visit) {
    if (!_has(view)) return;
    _bars(_polar.resolve(view), (int i, ChartSector sector) => visit(_hitOf(i, sector, 0)));
  }

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    if (!_has(view)) return;
    final ChartPolarView circle = _polar.resolve(view);
    final ChartScaleView angles = view.scale(xScale);
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final bool round = cap != StrokeCap.butt;
    final Color? track = trackColor;
    if (track != null && circle.radius > 0) {
      paint.color = track;
      for (int i = 0; i < data.length; i++) {
        final ChartSector ring = _ring(circle, i, angles.min, angles.max);
        if (!(ring.outerRadius > ring.innerRadius)) continue;
        context.canvas.drawPath(
          ring.toPath(cornerRadius: round ? (ring.outerRadius - ring.innerRadius) / 2 : 0),
          paint,
        );
      }
    }
    final Color color = this.color ?? context.seriesColor;
    _bars(circle, (int i, ChartSector sector) {
      paint.color = colorOf?.call(i, data.x(i), data.value(i, column)) ?? color;
      context.canvas.drawPath(
        sector.toPath(cornerRadius: round ? (sector.outerRadius - sector.innerRadius) / 2 : 0),
        paint,
      );
      return true;
    });
  }
}

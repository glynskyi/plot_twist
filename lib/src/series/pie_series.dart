import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Picks the colour of one slice from the [index] of its row and its
/// [value]. Return null for the colour of the palette.
typedef ChartSliceColor = Color? Function(int index, double value);

/// A pie or a doughnut: one slice per row of a [ChartData], as wide as its
/// value.
///
/// ```dart
/// PolarChart(
///   innerRadius: 0.6, // leave this out for a full pie
///   children: [
///     PieSeries(data: ChartData.fromValues([1200, 640, 310]), labels: ['Rent', 'Food', 'Fun']),
///   ],
/// )
/// ```
///
/// The slices follow each other along the angle scale of the chart. On the
/// default scale, which fits the data, they fill the whole sweep. On a scale
/// with a fixed range they fill their share of it: with
/// `LinearScale(range: FixedRange(0, 100))`, values that add up to 60 cover
/// 60% of the circle. From the centre they reach from the inner radius of
/// the chart to its outer radius.
///
/// Each slice takes the next colour of the palette of the chart theme;
/// [colorOf] overrides it. With [labels], a `ChartLegend` shows one item per
/// slice, and a tooltip names the slice. A row whose value is missing, zero
/// or negative has no slice.
///
/// `ChartDataLabels` writes on the slices, `ChartAppear` with
/// `ChartAppearEffect.reveal` draws the pie in around its centre, and
/// `AnimatedChartData` moves the slices to new values.
class PieSeries extends StatelessWidget {
  /// Creates a pie series.
  const PieSeries({
    super.key,
    required this.data,
    this.column = 0,
    this.labels,
    this.colorOf,
    this.gap = 0,
    this.cornerRadius = 0,
    this.offsetOf,
    this.id,
    this.label,
    this.visible = true,
    this.isolate = true,
  });

  /// The data to plot: one slice per row.
  final ChartData data;

  /// The value column holding the size of each slice.
  final int column;

  /// The names of the slices, by row, for legends and tooltips.
  final List<String>? labels;

  /// Per-slice colour; null, or a null result, uses the palette of the chart
  /// theme.
  final ChartSliceColor? colorOf;

  /// Space between two slices, in logical pixels. It is the same at every
  /// distance from the centre.
  final double gap;

  /// Radius of the corners of each slice, in logical pixels.
  final double cornerRadius;

  /// How far a slice is pulled out of the pie, in logical pixels, by the
  /// index of its row. Use it to set the selected slice apart; give the
  /// chart a `margin` so the slice has room.
  final double Function(int index)? offsetOf;

  /// Identifier of the series.
  final Object? id;

  /// Name of the series. A legend lists the slices by [labels] instead.
  final String? label;

  /// Whether the series is shown.
  final bool visible;

  /// Whether the series paints into its own compositing layer.
  final bool isolate;

  @override
  Widget build(BuildContext context) {
    return ChartPaint(
      id: id,
      label: label,
      visible: visible,
      clip: false,
      isolate: isolate,
      painter: PieSeriesPainter(
        data: data,
        polar: ChartPolarScope.of(context),
        palette: ChartTheme.of(context).palette,
        column: column,
        labels: labels,
        colorOf: colorOf,
        gap: gap,
        cornerRadius: cornerRadius,
        offsetOf: offsetOf,
      ),
    );
  }
}

/// Paints a [PieSeries]. Built entirely on the public [ChartSeriesPainter]
/// contract.
class PieSeriesPainter extends ChartSeriesPainter {
  /// Creates a pie painter.
  PieSeriesPainter({
    required this.data,
    required ChartPolar polar,
    this.palette = ChartThemeData.defaultPalette,
    this.column = 0,
    this.labels,
    this.colorOf,
    this.gap = 0,
    this.cornerRadius = 0,
    this.offsetOf,
  }) : _polar = polar,
       super(data: data, xScale: polar.angleScale, yScale: polar.radiusScale);

  /// The data to plot.
  final ChartData data;

  final ChartPolar _polar;

  @override
  ChartPolar get polar => _polar;

  /// The colours the slices take in turn.
  final List<Color> palette;

  /// The value column holding the size of each slice.
  final int column;

  /// The names of the slices, by row.
  final List<String>? labels;

  /// Per-slice colour.
  final ChartSliceColor? colorOf;

  /// Space between two slices, in logical pixels.
  final double gap;

  /// Corner radius in logical pixels.
  final double cornerRadius;

  /// How far a slice is pulled out, by the index of its row.
  final double Function(int index)? offsetOf;

  // The size of the slice of row [i]: zero for a row that has none.
  double _value(int i) {
    final double v = data.value(i, column);
    return v.isFinite && v > 0 ? v : 0;
  }

  Color _colorOf(int i, double value) {
    final Color? own = colorOf?.call(i, value);
    if (own != null) return own;
    return palette.isEmpty ? ChartThemeData.defaultPalette.first : palette[i % palette.length];
  }

  String? _labelOf(int i) {
    final List<String>? names = labels;
    return names != null && i < names.length ? names[i] : null;
  }

  @override
  List<ChartSeriesEntry> get entries => <ChartSeriesEntry>[
    for (int i = 0; i < data.length; i++)
      ChartSeriesEntry(
        index: i,
        color: _colorOf(i, _value(i)),
        label: _labelOf(i),
        visible: _value(i) > 0,
      ),
  ];

  @override
  bool shouldRepaint(PieSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate._polar != _polar ||
      !listEquals(oldDelegate.palette, palette) ||
      oldDelegate.column != column ||
      !listEquals(oldDelegate.labels, labels) ||
      oldDelegate.colorOf != colorOf ||
      oldDelegate.gap != gap ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.offsetOf != offsetOf;

  @override
  bool shouldRescale(PieSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) || oldDelegate.column != column;

  /// The slices cover the angle scale from zero to their sum.
  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) {
    double total = 0;
    for (int i = 0; i < data.length; i++) {
      total += _value(i);
    }
    return total > 0 ? ChartDataBounds(x: ChartRange(0, total)) : null;
  }

  // Calls [visit] with every slice [view] shows, until it returns false.
  void _slices(ChartView view, bool Function(int index, double value, ChartSector sector) visit) {
    if (data.isEmpty || !view.scales.containsKey(xScale)) return;
    final ChartPolarView circle = _polar.resolve(view);
    if (!(circle.radius > 0)) return;
    double before = 0;
    for (int i = 0; i < data.length; i++) {
      final double value = _value(i);
      if (value <= 0) continue;
      // What lies beyond the angle scale is cut off at its ends.
      final double from = circle.angleFraction(before).clamp(0.0, 1.0);
      final double to = circle.angleFraction(before + value).clamp(0.0, 1.0);
      before += value;
      if (to == from) continue;
      final ChartSector sector = ChartSector(
        center: circle.center,
        innerRadius: circle.innerRadius,
        outerRadius: circle.radius,
        startAngle: _polar.startAngle + _polar.sweepAngle * from,
        sweepAngle: _polar.sweepAngle * (to - from),
      ).shifted(offsetOf?.call(i) ?? 0);
      if (!visit(i, value, sector)) return;
    }
  }

  ChartHit _hitOf(int i, double value, ChartSector sector, double distance) => ChartHit(
    x: value,
    y: 0,
    position: sector.middle,
    distance: distance,
    index: i,
    sector: sector,
    valueAxis: Axis.horizontal,
    label: _labelOf(i),
    color: _colorOf(i, value),
  );

  /// Finds the slice at the position of a query, or the nearest one within
  /// its `maxDistance`. A pie answers `ChartHitMode.nearest` only.
  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    if (query.mode != ChartHitMode.nearest) return;
    ChartHit? best;
    _slices(query.view, (int i, double value, ChartSector sector) {
      final double distance = sector.distanceTo(query.position);
      if (distance <= query.maxDistance && (best == null || distance < best!.distance)) {
        best = _hitOf(i, value, sector, distance);
      }
      return true;
    });
    if (best != null) hits.add(best!);
  }

  @override
  void visitMarks(ChartView view, bool Function(ChartHit mark) visit) {
    _slices(view, (int i, double value, ChartSector sector) => visit(_hitOf(i, value, sector, 0)));
  }

  @override
  void paint(ChartPaintContext context) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    _slices(context.view, (int i, double value, ChartSector sector) {
      paint.color = _colorOf(i, value);
      context.canvas.drawPath(
        sector.toPath(gap: gap, cornerRadius: math.max(0, cornerRadius)),
        paint,
      );
      return true;
    });
  }
}

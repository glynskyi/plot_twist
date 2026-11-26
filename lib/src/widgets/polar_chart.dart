import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/chart_controller.dart';
import '../core/chart_view.dart';
import '../core/polar.dart';
import '../core/scale.dart';
import '../rendering/render_chart_stack.dart';
import 'chart.dart';
import 'chart_stack.dart';

/// A chart on a circle: pies and doughnuts, gauges and radar charts.
///
/// It is a [Chart] whose two scales are laid out around a centre. The
/// [angle] scale runs around the circle and the [radius] scale from the
/// centre outwards. As in a `Chart`, the [children] are ordinary widgets
/// stacked over the plot and painted in order: series, a grid, a legend, a
/// tooltip, and anything else, such as a `Center` with a total in the hole
/// of a doughnut.
///
/// ```dart
/// // A doughnut.
/// PolarChart(
///   innerRadius: 0.6,
///   children: [PieSeries(data: ChartData.fromValues([1200, 640, 310]))],
/// )
///
/// // A gauge that reads 72 of 100 on three quarters of a circle.
/// PolarChart(
///   angle: const LinearScale(range: FixedRange(0, 100)),
///   startAngle: 0.75 * math.pi,
///   sweepAngle: 1.5 * math.pi,
///   innerRadius: 0.8,
///   children: [RadialBarSeries(data: ChartData.fromValues([72]), track: true)],
/// )
///
/// // A radar chart.
/// PolarChart(
///   angle: const ChartScale.band(labels: ['Speed', 'Range', 'Comfort', 'Price']),
///   radius: const LinearScale(range: FixedRange(0, 10)),
///   children: [const ChartPolarGrid(), RadarSeries(data: ChartData.fromValues([8, 6, 7, 4]))],
/// )
/// ```
///
/// Angles are in radians and follow `Canvas.drawArc`: zero points to three
/// o'clock and positive angles turn clockwise.
///
/// The circle is as large as the plot allows after the [margin]. When
/// [sweepAngle] is less than a whole turn only the drawn part has to fit, so
/// a half-circle gauge fills a wide plot.
///
/// To follow the pointer, add `ChartCrosshair.point()` and a `ChartTooltip`.
/// A polar chart is not panned or zoomed.
class PolarChart extends StatelessWidget {
  /// Creates a polar chart.
  const PolarChart({
    super.key,
    this.controller,
    this.angle = const LinearScale(),
    this.radius = const LinearScale(range: FitDataRange(includeZero: true)),
    this.startAngle = -math.pi / 2,
    this.sweepAngle = 2 * math.pi,
    this.innerRadius = 0,
    this.margin = EdgeInsets.zero,
    this.left = const <Widget>[],
    this.top = const <Widget>[],
    this.right = const <Widget>[],
    this.bottom = const <Widget>[],
    this.children = const <Widget>[],
    this.isolate = true,
    this.fallbackSize = const Size(240, 240),
    this.semanticLabel,
  });

  /// Controls and observes the chart. Created internally when null.
  final ChartController? controller;

  /// The scale that runs around the circle, with id [kChartAngle].
  ///
  /// The default fits the data, which is what a pie needs: its slices then
  /// fill the whole sweep. Give a gauge a `FixedRange`, and a radar chart a
  /// band scale with the names of its categories.
  final ChartScale angle;

  /// The scale that runs from the centre outwards, with id [kChartRadius].
  /// The default fits the data and starts at zero.
  final ChartScale radius;

  /// The angle the low end of [angle] is drawn at. Defaults to twelve
  /// o'clock.
  final double startAngle;

  /// How far [angle] turns from [startAngle]: a whole turn by default.
  /// Negative runs anticlockwise.
  final double sweepAngle;

  /// The radius the low end of [radius] is drawn at, as a fraction of the
  /// outer radius: the hole of a doughnut, or the inside of a gauge.
  final double innerRadius;

  /// Space kept free around the circle, for labels outside it.
  final EdgeInsets margin;

  /// Widgets docked left of the plot, from the outside in.
  final List<Widget> left;

  /// Widgets docked above the plot, from the outside in.
  final List<Widget> top;

  /// Widgets docked right of the plot, from the plot outwards.
  final List<Widget> right;

  /// Widgets docked below the plot, from the plot outwards.
  final List<Widget> bottom;

  /// The layers of the plot, painted in order (later children on top).
  final List<Widget> children;

  /// Whether the chart paints into its own compositing layer.
  final bool isolate;

  /// The size used along an axis in which the chart is unconstrained.
  final Size fallbackSize;

  /// A description of the chart for assistive technologies.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ChartPolarScope(
      polar: ChartPolar(
        startAngle: startAngle,
        sweepAngle: sweepAngle,
        innerRadius: innerRadius,
        margin: margin,
      ),
      child: Chart(
        controller: controller,
        xScales: <Object, ChartScale>{kChartAngle: angle},
        yScales: <Object, ChartScale>{kChartRadius: radius},
        left: left,
        top: top,
        right: right,
        bottom: bottom,
        isolate: isolate,
        fallbackSize: fallbackSize,
        semanticLabel: semanticLabel,
        children: children,
      ),
    );
  }
}

/// Tells the widgets of a polar chart how its scales lie on the circle.
///
/// A [PolarChart] provides one. To draw polar series in a `Chart` of your
/// own, register an angle scale in `Chart.xScales` and a radius scale in
/// `Chart.yScales` and wrap the chart in a scope whose [polar] names them.
class ChartPolarScope extends InheritedWidget {
  /// Creates a scope. A [PolarChart] does this for you.
  const ChartPolarScope({super.key, required this.polar, required super.child});

  /// The frame of the chart.
  final ChartPolar polar;

  /// The frame of the closest polar chart above [context].
  static ChartPolar of(BuildContext context) {
    final ChartPolar? polar = maybeOf(context);
    if (polar == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No PolarChart found.'),
        ErrorDescription(
          '${context.widget.runtimeType} draws around a circle and must be placed in a '
          'PolarChart: in its children, in one of its side slots, or anywhere inside those.',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return polar;
  }

  /// The frame of the closest polar chart above [context], or null.
  static ChartPolar? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChartPolarScope>()?.polar;

  @override
  bool updateShouldNotify(ChartPolarScope oldWidget) => oldWidget.polar != polar;
}

/// Places a widget in a polar chart from an angle and a radius.
///
/// [angle] is a value of the angle scale and [radius] a value of the radius
/// scale. Leave [radius] out to place the widget by [radiusFactor] instead:
/// a fraction of the outer radius, where 1 is on the circle and more is
/// outside it.
///
/// ```dart
/// // An icon outside the circle, at the third category.
/// ChartPolarPositioned(angle: 2, radiusFactor: 1.15, child: icon)
/// ```
///
/// Like `ChartPositioned`, it goes directly into the children of the chart
/// or of a `ChartStack`.
class ChartPolarPositioned extends StatelessWidget {
  /// Places [child] at [angle] and [radius].
  const ChartPolarPositioned({
    super.key,
    required this.angle,
    this.radius,
    this.radiusFactor = 1,
    this.alignment = Alignment.center,
    this.offset = Offset.zero,
    this.fit = ChartPositionedFit.none,
    this.overflow = ChartOverflow.visible,
    required this.child,
  });

  /// Where the widget is on the angle scale.
  final double angle;

  /// Where the widget is on the radius scale. Null uses [radiusFactor].
  final double? radius;

  /// The distance from the centre as a fraction of the outer radius, used
  /// when [radius] is null.
  final double radiusFactor;

  /// Which point of the child sits on the position.
  final Alignment alignment;

  /// Extra shift in logical pixels.
  final Offset offset;

  /// How the child is kept inside the plot.
  final ChartPositionedFit fit;

  /// What happens when the child leaves the plot. Defaults to showing it,
  /// because labels around a circle usually lie outside it.
  final ChartOverflow overflow;

  /// The widget to place.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ChartPolar polar = ChartPolarScope.of(context);
    final double angle = this.angle;
    final double? radius = this.radius;
    final double factor = radiusFactor;
    return ChartPositioned.resolve(
      position: (ChartView view) {
        final ChartPolarView circle = polar.resolve(view);
        return circle.pointAt(
          circle.angleOf(angle),
          radius == null ? circle.radius * factor : circle.radiusOf(radius),
        );
      },
      alignment: alignment,
      offset: offset,
      fit: fit,
      overflow: overflow,
      child: child,
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' show Offset, Path, PathFillType, Radius, Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Axis, EdgeInsets;

import 'chart_view.dart';
import 'scale.dart';
import 'ticks.dart';

/// Identifies the angle scale of a polar chart.
const Object kChartAngle = 'angle';

/// Identifies the radius scale of a polar chart.
const Object kChartRadius = 'radius';

const double _turn = 2 * math.pi;

/// A part of a ring: what a slice of a pie or a bar of a gauge covers on
/// screen.
///
/// Angles are in radians and follow `Canvas.drawArc`: zero points to three
/// o'clock and positive angles turn clockwise. A negative [sweepAngle] turns
/// the other way.
@immutable
class ChartSector {
  /// Creates a sector.
  const ChartSector({
    required this.center,
    required this.innerRadius,
    required this.outerRadius,
    required this.startAngle,
    required this.sweepAngle,
  });

  /// The centre of the ring, in plot-local pixels.
  final Offset center;

  /// The radius the sector starts at; zero for a slice of a full pie.
  final double innerRadius;

  /// The radius the sector ends at.
  final double outerRadius;

  /// The angle the sector starts at.
  final double startAngle;

  /// How far the sector turns from [startAngle].
  final double sweepAngle;

  /// The angle halfway through the sector.
  double get middleAngle => startAngle + sweepAngle / 2;

  /// The radius halfway between the two edges.
  double get middleRadius => (innerRadius + outerRadius) / 2;

  /// The point in the middle of the sector.
  Offset get middle => pointAt(middleAngle, middleRadius);

  /// The point at [angle] and [radius] around [center].
  Offset pointAt(double angle, double radius) =>
      center + Offset(math.cos(angle), math.sin(angle)) * radius;

  /// This sector moved [distance] logical pixels away from the centre, along
  /// its middle. This is how a slice is pulled out of a pie.
  ChartSector shifted(double distance) => distance == 0
      ? this
      : ChartSector(
          center: pointAt(middleAngle, distance),
          innerRadius: innerRadius,
          outerRadius: outerRadius,
          startAngle: startAngle,
          sweepAngle: sweepAngle,
        );

  // The angle the sector starts at when it is walked clockwise.
  double get _from => sweepAngle >= 0 ? startAngle : startAngle + sweepAngle;

  /// Whether [position] is on the sector, edges included.
  bool contains(Offset position) => distanceTo(position) <= 0;

  /// The distance from [position] to the sector in logical pixels: zero on
  /// it.
  double distanceTo(Offset position) {
    final Offset d = position - center;
    final double r = d.distance;
    final double sweep = sweepAngle.abs();
    final double radial = math.max(0, math.max(innerRadius - r, r - outerRadius));
    if (sweep >= _turn - 1e-9 || r == 0) return radial;
    final double delta = (math.atan2(d.dy, d.dx) - _from) % _turn;
    if (delta <= sweep + 1e-9 || delta >= _turn - 1e-9) return radial;
    // Beside the sector: the nearer of its two straight edges.
    return math.min(_toEdge(position, _from), _toEdge(position, _from + sweep));
  }

  double _toEdge(Offset position, double angle) {
    final Offset a = pointAt(angle, innerRadius);
    final Offset ab = pointAt(angle, outerRadius) - a;
    final double length = ab.distanceSquared;
    final double t = length > 0
        ? (((position.dx - a.dx) * ab.dx + (position.dy - a.dy) * ab.dy) / length).clamp(0.0, 1.0)
        : 0;
    return (position - (a + ab * t)).distance;
  }

  /// The outline of the sector.
  ///
  /// With a [gap], each straight edge is moved inwards by half of it, so two
  /// neighbours are [gap] logical pixels apart at every radius. A
  /// [cornerRadius] rounds the corners; it is reduced where the sector is too
  /// small for it. A sector that turns a whole circle has no edges, and so
  /// neither a gap nor corners.
  Path toPath({double gap = 0, double cornerRadius = 0}) {
    final Path path = Path();
    final double outer = outerRadius;
    final double inner = math.max(0, innerRadius);
    final double sweep = sweepAngle.abs();
    if (!(outer > inner) || !(sweep > 0) || !sweep.isFinite) return path;
    if (sweep >= _turn - 1e-9) {
      path.addOval(Rect.fromCircle(center: center, radius: outer));
      if (inner > 0) {
        path
          ..addOval(Rect.fromCircle(center: center, radius: inner))
          ..fillType = PathFillType.evenOdd;
      }
      return path;
    }
    final double a0 = _from;
    final double a1 = a0 + sweep;
    final double half = sweep / 2;
    final double sinHalf = half < math.pi / 2 ? math.sin(half) : 1;
    // Each edge is moved in by [g], parallel to itself.
    final double g = math.max(0, gap) / 2;
    if (!(g < outer * sinHalf)) return path;

    // Unit vectors along the two edges, and across them into the sector.
    final Offset u0 = Offset(math.cos(a0), math.sin(a0));
    final Offset u1 = Offset(math.cos(a1), math.sin(a1));
    final Offset n0 = Offset(-u0.dy, u0.dx);
    final Offset n1 = Offset(u1.dy, -u1.dx);

    final double corner = math.max(0, math.min(cornerRadius, (outer - inner) / 2));
    // The outer corners need room along the arc and along the edge.
    double co = math.min(corner, (outer - g) / 2);
    if (half < math.pi / 2) co = math.min(co, (outer * sinHalf - g) / (1 + sinHalf));
    co = math.max(0, co);
    final double outerTurn = math.asin(((g + co) / (outer - co)).clamp(0.0, 1.0));
    final double outerAlong = math.sqrt(
      math.max(0, (outer - co) * (outer - co) - (g + co) * (g + co)),
    );
    final Radius outerCorner = Radius.circular(co);

    path.moveTo(
      center.dx + u0.dx * outerAlong + n0.dx * g,
      center.dy + u0.dy * outerAlong + n0.dy * g,
    );
    if (co > 0) path.arcToPoint(pointAt(a0 + outerTurn, outer), radius: outerCorner);
    path.arcTo(
      Rect.fromCircle(center: center, radius: outer),
      a0 + outerTurn,
      sweep - 2 * outerTurn,
      false,
    );
    if (co > 0) {
      path.arcToPoint(center + u1 * outerAlong + n1 * g, radius: outerCorner);
    }

    final bool hasInnerArc = inner > 0 && g < inner * sinHalf;
    if (hasInnerArc) {
      double ci = corner;
      if (half < math.pi / 2) ci = math.min(ci, (inner * sinHalf - g) / (1 - sinHalf));
      ci = math.max(0, ci);
      final double innerTurn = math.asin(((g + ci) / (inner + ci)).clamp(0.0, 1.0));
      final double innerAlong = math.sqrt(
        math.max(0, (inner + ci) * (inner + ci) - (g + ci) * (g + ci)),
      );
      final Radius innerCorner = Radius.circular(ci);
      final Offset end = center + u1 * innerAlong + n1 * g;
      path.lineTo(end.dx, end.dy);
      if (ci > 0) path.arcToPoint(pointAt(a1 - innerTurn, inner), radius: innerCorner);
      path.arcTo(
        Rect.fromCircle(center: center, radius: inner),
        a1 - innerTurn,
        -(sweep - 2 * innerTurn),
        false,
      );
      if (ci > 0) path.arcToPoint(center + u0 * innerAlong + n0 * g, radius: innerCorner);
    } else if (half < math.pi / 2) {
      // The two edges meet in a point on the middle of the sector.
      final Offset tip = pointAt(a0 + half, g / sinHalf);
      path.lineTo(tip.dx, tip.dy);
    } else {
      // Wider than half a turn: the edges end beside the centre.
      final Offset end = center + n1 * g;
      final Offset start = center + n0 * g;
      path
        ..lineTo(end.dx, end.dy)
        ..lineTo(start.dx, start.dy);
    }
    return path..close();
  }

  @override
  bool operator ==(Object other) =>
      other is ChartSector &&
      other.center == center &&
      other.innerRadius == innerRadius &&
      other.outerRadius == outerRadius &&
      other.startAngle == startAngle &&
      other.sweepAngle == sweepAngle;

  @override
  int get hashCode => Object.hash(center, innerRadius, outerRadius, startAngle, sweepAngle);

  @override
  String toString() =>
      'ChartSector($center, $innerRadius..$outerRadius, from $startAngle by $sweepAngle)';
}

/// How a polar chart lays its two scales out on a circle: the angle scale
/// runs around it, the radius scale from the centre outwards.
///
/// A `PolarChart` creates one from its own parameters and hands it to the
/// widgets below it; `ChartPolarScope.of` reads it. Angles are in radians and
/// follow `Canvas.drawArc`: zero points to three o'clock and positive angles
/// turn clockwise.
///
/// On a band scale the first band is centred on [startAngle], so the first
/// category of a radar chart points straight up.
@immutable
class ChartPolar {
  /// Creates a polar frame.
  const ChartPolar({
    this.startAngle = -math.pi / 2,
    this.sweepAngle = 2 * math.pi,
    this.innerRadius = 0,
    this.margin = EdgeInsets.zero,
    this.angleScale = kChartAngle,
    this.radiusScale = kChartRadius,
  }) : assert(innerRadius >= 0 && innerRadius < 1, 'innerRadius is a fraction of the radius'),
       assert(sweepAngle != 0, 'A polar chart needs an angle to turn through');

  /// The angle the low end of the angle scale is drawn at. Defaults to twelve
  /// o'clock.
  final double startAngle;

  /// How far the angle scale turns from [startAngle]: a whole turn by
  /// default, less for a gauge, negative to run anticlockwise.
  final double sweepAngle;

  /// The radius the low end of the radius scale is drawn at, as a fraction of
  /// the outer radius. Zero is the centre; more leaves a hole, as in a
  /// doughnut.
  final double innerRadius;

  /// Space kept free between the edges of the plot and the circle, for
  /// labels around it.
  final EdgeInsets margin;

  /// Id of the scale that runs around the circle.
  final Object angleScale;

  /// Id of the scale that runs from the centre outwards.
  final Object radiusScale;

  /// Where the circle is in [view], and how values map onto it.
  ChartPolarView resolve(ChartView view) => ChartPolarView(polar: this, view: view);

  @override
  bool operator ==(Object other) =>
      other is ChartPolar &&
      other.startAngle == startAngle &&
      other.sweepAngle == sweepAngle &&
      other.innerRadius == innerRadius &&
      other.margin == margin &&
      other.angleScale == angleScale &&
      other.radiusScale == radiusScale;

  @override
  int get hashCode =>
      Object.hash(startAngle, sweepAngle, innerRadius, margin, angleScale, radiusScale);

  @override
  String toString() => 'ChartPolar(from $startAngle by $sweepAngle, hole $innerRadius)';
}

/// A [ChartPolar] laid out in one frame of a chart: where the circle is, and
/// the pixel of every value.
///
/// The circle is as large as the plot allows. When the angle scale turns
/// less than a whole circle, only the part that is drawn has to fit, so a
/// half-circle gauge fills a wide plot.
class ChartPolarView {
  /// Lays [polar] out in [view]. `ChartPolar.resolve` does this for you.
  ChartPolarView({required this.polar, required this.view}) {
    // The box around the arc on a circle of radius one, the centre included.
    final double a0 = polar.startAngle;
    final double a1 = a0 + polar.sweepAngle;
    final double from = math.min(a0, a1);
    final double to = math.max(a0, a1);
    double left = 0;
    double top = 0;
    double right = 0;
    double bottom = 0;
    void include(double angle) {
      final double x = math.cos(angle);
      final double y = math.sin(angle);
      left = math.min(left, x);
      right = math.max(right, x);
      top = math.min(top, y);
      bottom = math.max(bottom, y);
    }

    if (to - from >= _turn - 1e-9) {
      left = top = -1;
      right = bottom = 1;
    } else {
      include(from);
      include(to);
      // Where the arc passes three, six, nine and twelve o'clock.
      for (double q = (from / (math.pi / 2)).ceilToDouble(); q * (math.pi / 2) <= to; q++) {
        include(q * (math.pi / 2));
      }
    }
    final Rect room = polar.margin.deflateRect(Offset.zero & view.size);
    final double width = math.max(right - left, 1e-9);
    final double height = math.max(bottom - top, 1e-9);
    radius = math.max(0, math.min(room.width / width, room.height / height));
    center = room.center - Offset((left + right) / 2, (top + bottom) / 2) * radius;
  }

  /// The frame that was laid out.
  final ChartPolar polar;

  /// The chart view it was laid out in.
  final ChartView view;

  /// The centre of the circle, in plot-local pixels.
  late final Offset center;

  /// The outer radius: where the high end of the radius scale is drawn.
  late final double radius;

  /// The inner radius: where the low end of the radius scale is drawn.
  double get innerRadius => radius * polar.innerRadius;

  /// The angle scale, or null in a chart that has none.
  ChartScaleView? get angleScale => view.scales[polar.angleScale];

  /// The radius scale, or null in a chart that has none.
  ChartScaleView? get radiusScale => view.scales[polar.radiusScale];

  /// Whether the angle scale turns a whole circle.
  bool get isFullCircle => polar.sweepAngle.abs() >= _turn - 1e-9;

  // Half a band on a band scale, whose first band is centred on the start
  // angle.
  static double _shift(ChartScaleView scale) => scale.scale is BandScale ? 0.5 : 0;

  /// How far along the angle scale [value] is: 0 at the start angle, 1 at
  /// the end of the sweep. Values outside the window give less or more.
  double angleFraction(double value) {
    final ChartScaleView? scale = angleScale;
    if (scale == null || !(scale.scaledSpan > 0)) return 0;
    final double t =
        (scale.scale.transform(value) - scale.scaledMin - _shift(scale)) / scale.scaledSpan;
    return scale.scale.reversed ? 1 - t : t;
  }

  /// How far along the radius scale [value] is: 0 at the inner radius, 1 at
  /// the outer one.
  double radiusFraction(double value) {
    final ChartScaleView? scale = radiusScale;
    if (scale == null || !(scale.scaledSpan > 0)) return 0;
    final double t = (scale.scale.transform(value) - scale.scaledMin) / scale.scaledSpan;
    return scale.scale.reversed ? 1 - t : t;
  }

  /// The angle [value] of the angle scale is drawn at, in radians.
  double angleOf(double value) => polar.startAngle + polar.sweepAngle * angleFraction(value);

  /// The distance from the centre that [value] of the radius scale is drawn
  /// at, in logical pixels.
  double radiusOf(double value) => innerRadius + (radius - innerRadius) * radiusFraction(value);

  /// The point at [angle] (in radians) and [radius] (in logical pixels).
  Offset pointAt(double angle, double radius) =>
      center + Offset(math.cos(angle), math.sin(angle)) * radius;

  /// The plot-local position of the data point at [angle] on the angle scale
  /// and [radius] on the radius scale.
  Offset toPixel(double angle, double radius) => pointAt(angleOf(angle), radiusOf(radius));

  /// How far around the sweep [position] is, from 0 to 1. Beside the arc of a
  /// chart that does not turn a whole circle, this is the nearer end.
  double fractionAt(Offset position) {
    final Offset d = position - center;
    final double sweep = polar.sweepAngle.abs();
    final double from = polar.sweepAngle >= 0
        ? polar.startAngle
        : polar.startAngle + polar.sweepAngle;
    final double delta = (math.atan2(d.dy, d.dx) - from) % _turn;
    double t;
    if (isFullCircle) {
      t = delta / _turn;
    } else if (delta <= sweep) {
      t = delta / sweep;
    } else {
      // In the part of the circle the chart leaves empty.
      t = delta - sweep < _turn - delta ? 1 : 0;
    }
    return polar.sweepAngle >= 0 ? t : 1 - t;
  }

  /// The values under a plot-local [position]: where it is on the angle
  /// scale and on the radius scale.
  ({double angle, double radius}) toValue(Offset position) {
    double angle = double.nan;
    double radiusValue = double.nan;
    final ChartScaleView? angles = angleScale;
    if (angles != null) {
      final double f = fractionAt(position);
      final double t = angles.scale.reversed ? 1 - f : f;
      angle = angles.scale.invert(angles.scaledMin + _shift(angles) + t * angles.scaledSpan);
    }
    final ChartScaleView? radii = radiusScale;
    final double length = radius - innerRadius;
    if (radii != null && length > 0) {
      final double f = ((position - center).distance - innerRadius) / length;
      final double t = radii.scale.reversed ? 1 - f : f;
      radiusValue = radii.scale.invert(radii.scaledMin + t * radii.scaledSpan);
    }
    return (angle: angle, radius: radiusValue);
  }

  /// The sector between two values of the angle scale and two values of the
  /// radius scale.
  ChartSector sector({
    required double angleFrom,
    required double angleTo,
    required double radiusFrom,
    required double radiusTo,
  }) {
    final double start = angleOf(angleFrom);
    final double r0 = radiusOf(radiusFrom);
    final double r1 = radiusOf(radiusTo);
    return ChartSector(
      center: center,
      innerRadius: math.min(r0, r1),
      outerRadius: math.max(r0, r1),
      startAngle: start,
      sweepAngle: angleOf(angleTo) - start,
    );
  }

  /// The ticks of the angle scale, spaced for the length of the arc. On a
  /// whole circle a last tick that falls on the first one is left out.
  late final List<ChartTick> angleTicks = () {
    final ChartScaleView? scale = angleScale;
    if (scale == null) return const <ChartTick>[];
    final List<ChartTick> ticks = scale.scale.effectiveTicks.generate(
      ChartTickContext(
        min: scale.min,
        max: scale.max,
        extent: radius * polar.sweepAngle.abs(),
        direction: Axis.horizontal,
      ),
    );
    if (isFullCircle && ticks.length > 1) {
      final double turn = (angleFraction(ticks.last.value) - angleFraction(ticks.first.value))
          .abs();
      if ((turn - 1).abs() < 1e-9) return ticks.sublist(0, ticks.length - 1);
    }
    return ticks;
  }();

  /// The ticks of the radius scale, spaced for the length of the radius.
  late final List<ChartTick> radiusTicks = () {
    final ChartScaleView? scale = radiusScale;
    if (scale == null) return const <ChartTick>[];
    return scale.scale.effectiveTicks.generate(
      ChartTickContext(
        min: scale.min,
        max: scale.max,
        extent: radius - innerRadius,
        direction: Axis.vertical,
      ),
    );
  }();
}

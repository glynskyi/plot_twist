import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

const Size _size = Size(400, 300);

/// A view of [_size] whose angle scale shows 0 to 100 and whose radius scale
/// shows 0 to 10, unless told otherwise.
ChartView _view({
  ChartScale angle = const LinearScale(),
  double angleMin = 0,
  double angleMax = 100,
  ChartScale radius = const LinearScale(),
}) => ChartView(
  size: _size,
  chartRect: Offset.zero & _size,
  scales: <Object, ChartScaleView>{
    kChartAngle: ChartScaleView(
      id: kChartAngle,
      scale: angle,
      scaledMin: angleMin,
      scaledMax: angleMax,
      extent: _size.width,
      direction: Axis.horizontal,
    ),
    kChartRadius: ChartScaleView(
      id: kChartRadius,
      scale: radius,
      scaledMin: 0,
      scaledMax: 10,
      extent: _size.height,
      direction: Axis.vertical,
    ),
  },
);

Matcher _near(Offset point) => within<Offset>(distance: 1e-6, from: point);

void main() {
  group('ChartPolarView', () {
    test('a whole circle is as large as the plot allows, in its middle', () {
      final ChartPolarView circle = const ChartPolar().resolve(_view());
      expect(circle.center, const Offset(200, 150));
      expect(circle.radius, 150);
      expect(circle.innerRadius, 0);
      expect(circle.isFullCircle, isTrue);

      final ChartPolarView smaller = const ChartPolar(
        margin: EdgeInsets.all(10),
        innerRadius: 0.5,
      ).resolve(_view());
      expect(smaller.radius, 140);
      expect(smaller.innerRadius, 70);
    });

    test('an arc of less than a circle only has to fit the part that is drawn', () {
      // The upper half: twice as wide as it is high.
      final ChartPolarView half = const ChartPolar(
        startAngle: math.pi,
        sweepAngle: math.pi,
      ).resolve(_view());
      expect(half.radius, 200);
      expect(half.center, _near(const Offset(200, 250)));
      expect(half.isFullCircle, isFalse);

      // Three quarters, open at the bottom: the circle touches the top, and
      // the ends of the arc, 45 degrees below the centre, touch the bottom.
      final ChartPolarView gauge = const ChartPolar(
        startAngle: 0.75 * math.pi,
        sweepAngle: 1.5 * math.pi,
      ).resolve(_view());
      final double radius = 300 / (1 + math.sqrt1_2);
      expect(gauge.radius, closeTo(radius, 1e-9));
      expect(gauge.center, _near(Offset(200, radius)));
    });

    test('the angle scale runs clockwise from twelve o\'clock', () {
      final ChartPolarView circle = const ChartPolar().resolve(_view());
      expect(circle.angleOf(0), -math.pi / 2);
      expect(circle.angleOf(25), closeTo(0, 1e-12));
      expect(circle.toPixel(0, 10), _near(const Offset(200, 0)));
      expect(circle.toPixel(25, 10), _near(const Offset(350, 150)));
      expect(circle.toPixel(50, 5), _near(const Offset(200, 225)));
      expect(circle.toPixel(75, 10), _near(const Offset(50, 150)));
    });

    test('a negative sweep and a reversed scale run the other way', () {
      final ChartPolarView anticlockwise = const ChartPolar(
        sweepAngle: -2 * math.pi,
      ).resolve(_view());
      expect(anticlockwise.toPixel(25, 10), _near(const Offset(50, 150)));

      final ChartPolarView reversed = const ChartPolar().resolve(
        _view(angle: const LinearScale(reversed: true)),
      );
      expect(reversed.toPixel(25, 10), _near(const Offset(50, 150)));
    });

    test('the first band of a band scale is centred on the start angle', () {
      // Four bands: the window of the scale is -0.5 to 3.5.
      final ChartPolarView circle = const ChartPolar().resolve(
        _view(angle: const BandScale(), angleMin: -0.5, angleMax: 3.5),
      );
      expect(circle.toPixel(0, 10), _near(const Offset(200, 0)));
      expect(circle.toPixel(1, 10), _near(const Offset(350, 150)));
      expect(circle.toPixel(2, 10), _near(const Offset(200, 300)));
      expect(circle.toPixel(3, 10), _near(const Offset(50, 150)));
    });

    test('the radius scale starts at the inner radius', () {
      final ChartPolarView ring = const ChartPolar(innerRadius: 0.5).resolve(_view());
      expect(ring.radiusOf(0), 75);
      expect(ring.radiusOf(5), 112.5);
      expect(ring.radiusOf(10), 150);

      final ChartPolarView reversed = const ChartPolar(
        innerRadius: 0.5,
      ).resolve(_view(radius: const LinearScale(reversed: true)));
      expect(reversed.radiusOf(0), 150);
      expect(reversed.radiusOf(10), 75);
    });

    test('toValue is the inverse of toPixel', () {
      final ChartPolarView circle = const ChartPolar(innerRadius: 0.2).resolve(_view());
      final ({double angle, double radius}) value = circle.toValue(circle.toPixel(30, 4));
      expect(value.angle, closeTo(30, 1e-9));
      expect(value.radius, closeTo(4, 1e-9));

      final ChartPolarView bands = const ChartPolar().resolve(
        _view(angle: const BandScale(), angleMin: -0.5, angleMax: 3.5),
      );
      expect(bands.toValue(bands.toPixel(2, 7)).angle, closeTo(2, 1e-9));
      expect(bands.toValue(bands.toPixel(2, 7)).radius, closeTo(7, 1e-9));
    });

    test('beside the arc of a gauge, a position counts as its nearer end', () {
      final ChartPolarView half = const ChartPolar(
        startAngle: math.pi,
        sweepAngle: math.pi,
      ).resolve(_view());
      // The centre is at (200, 250); these two points lie below it.
      expect(half.fractionAt(const Offset(60, 290)), 0);
      expect(half.fractionAt(const Offset(340, 290)), 1);
      expect(half.fractionAt(const Offset(200, 100)), closeTo(0.5, 1e-12));
      expect(half.toValue(const Offset(60, 290)).angle, 0);
      expect(half.toValue(const Offset(340, 290)).angle, 100);
    });

    test('ticks are spaced for the length of the arc and of the radius', () {
      final ChartPolarView circle = const ChartPolar().resolve(_view());
      // 942 px around: a tick every 10. The one at 100 falls on the one at 0.
      expect(circle.angleTicks.map((ChartTick tick) => tick.value), <double>[
        0,
        10,
        20,
        30,
        40,
        50,
        60,
        70,
        80,
        90,
      ]);
      // 150 px from the centre to the rim.
      expect(circle.radiusTicks.map((ChartTick tick) => tick.value), <double>[0, 5, 10]);

      final ChartPolarView half = const ChartPolar(
        startAngle: math.pi,
        sweepAngle: math.pi,
      ).resolve(_view());
      expect(half.angleTicks.last.value, 100, reason: 'the two ends of an arc are two places');
    });

    test('a chart without polar scales gives no ticks and no positions', () {
      final ChartView plain = ChartView(
        size: _size,
        chartRect: Offset.zero & _size,
        scales: const <Object, ChartScaleView>{},
      );
      final ChartPolarView circle = const ChartPolar().resolve(plain);
      expect(circle.angleTicks, isEmpty);
      expect(circle.radiusTicks, isEmpty);
      expect(circle.angleFraction(5), 0);
      expect(circle.toValue(const Offset(10, 10)).angle, isNaN);
    });
  });

  group('ChartSector', () {
    // The quarter between three and six o'clock of a ring around (100, 100).
    const ChartSector quarter = ChartSector(
      center: Offset(100, 100),
      innerRadius: 50,
      outerRadius: 100,
      startAngle: 0,
      sweepAngle: math.pi / 2,
    );
    Offset at(double degrees, double radius) => quarter.pointAt(degrees * math.pi / 180, radius);

    test('knows what is on it and how far away the rest is', () {
      expect(quarter.contains(at(45, 75)), isTrue);
      expect(quarter.contains(at(0, 50)), isTrue, reason: 'edges are part of it');
      expect(quarter.contains(at(90, 100)), isTrue);
      expect(quarter.distanceTo(at(45, 120)), closeTo(20, 1e-9));
      expect(quarter.distanceTo(at(45, 30)), closeTo(20, 1e-9));
      // Beside it: the distance to the nearer straight edge.
      expect(quarter.distanceTo(const Offset(175, 90)), closeTo(10, 1e-9));
      expect(quarter.distanceTo(const Offset(130, 90)), closeTo(math.sqrt(500), 1e-9));
      expect(quarter.contains(const Offset(175, 90)), isFalse);
    });

    test('a negative sweep covers the same ground', () {
      const ChartSector back = ChartSector(
        center: Offset(100, 100),
        innerRadius: 50,
        outerRadius: 100,
        startAngle: math.pi / 2,
        sweepAngle: -math.pi / 2,
      );
      expect(back.contains(at(45, 75)), isTrue);
      expect(back.contains(at(100, 75)), isFalse);
      expect(back.distanceTo(const Offset(175, 90)), closeTo(10, 1e-9));
      expect(back.middle, _near(quarter.middle));
      expect(back.toPath().contains(at(45, 75)), isTrue);
      expect(back.toPath().contains(at(100, 75)), isFalse);
    });

    test('a whole ring has no edges', () {
      const ChartSector ring = ChartSector(
        center: Offset(100, 100),
        innerRadius: 50,
        outerRadius: 100,
        startAngle: 1,
        sweepAngle: 2 * math.pi,
      );
      for (final double degrees in <double>[0, 57, 123, 270]) {
        expect(ring.contains(at(degrees, 75)), isTrue);
        expect(ring.distanceTo(at(degrees, 40)), closeTo(10, 1e-9));
      }
      final Path path = ring.toPath(gap: 8, cornerRadius: 8);
      expect(path.contains(at(57, 75)), isTrue);
      expect(path.contains(const Offset(100, 100)), isFalse, reason: 'the hole');
    });

    test('has a middle, and can be pulled out along it', () {
      expect(quarter.middleAngle, math.pi / 4);
      expect(quarter.middleRadius, 75);
      expect(quarter.middle, _near(at(45, 75)));
      final ChartSector out = quarter.shifted(10);
      expect(out.center, _near(at(45, 10)));
      expect(out.outerRadius, 100);
      expect(quarter.shifted(0), same(quarter));
    });

    test('toPath: the plain outline', () {
      final Path path = quarter.toPath();
      expect(path.contains(at(45, 75)), isTrue);
      expect(path.contains(at(2, 98)), isTrue, reason: 'the corner is sharp');
      expect(path.contains(at(45, 102)), isFalse);
      expect(path.contains(at(45, 48)), isFalse);
      expect(path.contains(at(-2, 75)), isFalse);
      expect(path.contains(at(92, 75)), isFalse);
    });

    test('toPath: a gap is as wide near the centre as at the rim', () {
      final Path path = quarter.toPath(gap: 10);
      // The start edge runs along y = 100; half the gap is 5 px.
      expect(path.contains(const Offset(160, 104)), isFalse);
      expect(path.contains(const Offset(160, 106)), isTrue);
      expect(path.contains(const Offset(195, 104)), isFalse);
      expect(path.contains(const Offset(195, 106)), isTrue);
      // The end edge runs along x = 100.
      expect(path.contains(const Offset(104, 160)), isFalse);
      expect(path.contains(const Offset(106, 160)), isTrue);
    });

    test('toPath: corners are rounded', () {
      final Path path = quarter.toPath(cornerRadius: 10);
      expect(path.contains(const Offset(198, 101)), isFalse, reason: 'outer corner cut off');
      expect(path.contains(const Offset(190, 110)), isTrue);
      expect(path.contains(const Offset(151, 101)), isFalse, reason: 'inner corner cut off');
      expect(path.contains(const Offset(160, 110)), isTrue);
      expect(path.contains(const Offset(101, 198)), isFalse, reason: 'the other end too');
      expect(path.contains(at(45, 75)), isTrue);
    });

    test('toPath: a slice of a full pie with a gap ends in a point on its middle', () {
      const ChartSector slice = ChartSector(
        center: Offset(100, 100),
        innerRadius: 0,
        outerRadius: 100,
        startAngle: 0,
        sweepAngle: math.pi / 2,
      );
      expect(slice.toPath().contains(at(45, 2)), isTrue, reason: 'without a gap: the centre');
      // With a gap of 10 the point is 5 / sin(45°), about 7 px, from the centre.
      final Path path = slice.toPath(gap: 10);
      expect(path.contains(at(45, 5)), isFalse);
      expect(path.contains(at(45, 9)), isTrue);
    });

    test('toPath: wider than half a turn', () {
      const ChartSector wide = ChartSector(
        center: Offset(100, 100),
        innerRadius: 0,
        outerRadius: 100,
        startAngle: 0,
        sweepAngle: 1.5 * math.pi,
      );
      final Path path = wide.toPath(gap: 10);
      expect(path.contains(at(135, 50)), isTrue);
      expect(path.contains(at(260, 50)), isTrue);
      expect(path.contains(at(315, 50)), isFalse, reason: 'the missing quarter');
      expect(path.contains(const Offset(150, 103)), isFalse, reason: 'half the gap');
      expect(path.contains(const Offset(150, 107)), isTrue);
    });

    test('toPath: nothing is left of a sector thinner than its gap', () {
      const ChartSector sliver = ChartSector(
        center: Offset(100, 100),
        innerRadius: 0,
        outerRadius: 100,
        startAngle: 0,
        sweepAngle: 0.01,
      );
      expect(sliver.toPath(gap: 10).getBounds().isEmpty, isTrue);
      expect(sliver.toPath().getBounds().isEmpty, isFalse);
    });
  });
}

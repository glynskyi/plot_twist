import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// In the 400 x 300 host a polar chart is a circle of radius 150 around
// (200, 150). With an inner radius of 0.5 a single ring reaches from 75 to
// 150 px. The angle scale shows 0 to 100, so 25 is a quarter turn.
const ChartScale _percent = LinearScale(range: FixedRange(0, 100));
const int _white = 0xFFFFFFFF;
const Color _red = Color(0xFFFF0000);
const Color _green = Color(0xFF00FF00);
const Color _blue = Color(0xFF0000FF);

ChartData _one(double value) => ChartData.fromValues(<double>[value]);

Widget _gauge(
  ChartData data, {
  ChartController? controller,
  double baseline = 0,
  int? baseColumn,
  bool track = false,
  StrokeCap cap = StrokeCap.butt,
  List<Widget> more = const <Widget>[],
}) => PolarChart(
  controller: controller,
  angle: _percent,
  innerRadius: 0.5,
  children: <Widget>[
    RadialBarSeries(
      data: data,
      label: 'Load',
      color: _red,
      baseline: baseline,
      baseColumn: baseColumn,
      track: track,
      trackColor: _green,
      cap: cap,
      isolate: false,
    ),
    ...more,
  ],
);

void main() {
  testWidgets('a bar runs around the circle from the baseline to its value', (
    WidgetTester tester,
  ) async {
    int Function(int x, int y) pixel = await renderPixels(tester, _gauge(_one(50)));
    // Half of the scale: the right half of the ring.
    expect(pixel(300, 150), _red.toARGB32());
    expect(pixel(205, 40), _red.toARGB32());
    expect(pixel(205, 260), _red.toARGB32());
    expect(pixel(100, 150), _white);
    expect(pixel(230, 150), _white, reason: 'the hole');

    pixel = await renderPixels(tester, _gauge(_one(50), track: true));
    expect(pixel(300, 150), _red.toARGB32());
    expect(pixel(100, 150), _green.toARGB32(), reason: 'the track shows the rest of the ring');
    expect(pixel(230, 150), _white);
  });

  testWidgets('a value beyond the scale stops at its end; a missing value has no bar', (
    WidgetTester tester,
  ) async {
    int Function(int x, int y) pixel = await renderPixels(tester, _gauge(_one(150)));
    expect(pixel(300, 150), _red.toARGB32());
    expect(pixel(100, 150), _red.toARGB32());
    expect(pixel(195, 40), _red.toARGB32());

    pixel = await renderPixels(tester, _gauge(_one(double.nan), track: true));
    expect(pixel(300, 150), _green.toARGB32());
    expect(pixel(100, 150), _green.toARGB32());
  });

  testWidgets('a bar can start at a baseline or at a value of its own', (
    WidgetTester tester,
  ) async {
    // From 25 to 75: the lower half.
    int Function(int x, int y) pixel = await renderPixels(tester, _gauge(_one(75), baseline: 25));
    expect(pixel(200, 260), _red.toARGB32());
    expect(pixel(200, 40), _white);

    // From 50 to 75: the quarter between six and nine o'clock.
    final ChartData range = ChartData(valueColumns: 2)..addRow(0, <double>[75, 50]);
    pixel = await renderPixels(tester, _gauge(range, baseColumn: 1));
    expect(pixel(122, 228), _red.toARGB32());
    expect(pixel(278, 228), _white);
    expect(pixel(122, 72), _white);
  });

  testWidgets('each row is a ring on the radius scale', (WidgetTester tester) async {
    // Three bands between 37.5 and 150 px, 37.5 px each; a ring fills 70%.
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(
        angle: _percent,
        radius: const ChartScale.band(),
        innerRadius: 0.25,
        children: <Widget>[
          RadialBarSeries(
            data: ChartData.fromValues(<double>[100, 50, 100]),
            colorOf: (int index, double x, double y) => index == 2 ? _blue : null,
            color: _red,
            isolate: false,
          ),
        ],
      ),
    );
    // Left of the centre: the inner ring and the outer one, which are whole.
    expect(pixel(144, 150), _red.toARGB32());
    expect(pixel(106, 150), _white, reason: 'the middle ring is half');
    expect(pixel(69, 150), _blue.toARGB32());
    expect(pixel(125, 150), _white, reason: 'between two rings');
    // Right of the centre: all three.
    expect(pixel(256, 150), _red.toARGB32());
    expect(pixel(294, 150), _red.toARGB32());
    expect(pixel(331, 150), _blue.toARGB32());
  });

  testWidgets('round ends stay within the value', (WidgetTester tester) async {
    // The bar ends at six o'clock, on the line x = 200 from y = 225 to 300.
    int Function(int x, int y) pixel = await renderPixels(tester, _gauge(_one(50)));
    expect(pixel(203, 228), _red.toARGB32());
    expect(pixel(203, 256), _red.toARGB32());
    expect(pixel(197, 256), _white);

    pixel = await renderPixels(tester, _gauge(_one(50), cap: StrokeCap.round));
    expect(pixel(203, 228), _white, reason: 'the corner is rounded off');
    expect(pixel(203, 296), _white);
    expect(pixel(203, 262), _red.toARGB32(), reason: 'the end still reaches the value');
    expect(pixel(197, 262), _white, reason: 'and not beyond it');
    expect(pixel(300, 150), _red.toARGB32());
  });

  testWidgets('a gauge on half a circle fills a wide plot', (WidgetTester tester) async {
    // The circle has a radius of 200 around (200, 250); the ring starts at 100.
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(
        angle: _percent,
        startAngle: math.pi,
        sweepAngle: math.pi,
        innerRadius: 0.5,
        children: <Widget>[
          RadialBarSeries(
            data: _one(50),
            color: _red,
            track: true,
            trackColor: _green,
            isolate: false,
          ),
        ],
      ),
    );
    expect(pixel(94, 144), _red.toARGB32(), reason: 'from nine to twelve o\'clock');
    expect(pixel(306, 144), _green.toARGB32());
    expect(pixel(20, 245), _red.toARGB32(), reason: 'the ring reaches the left edge');
    expect(pixel(200, 200), _white, reason: 'inside the ring');
  });

  testWidgets('automatic ranges: the values on the angle scale, the rings on the radius scale', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        PolarChart(
          controller: c,
          children: <Widget>[
            RadialBarSeries(data: ChartData.fromValues(<double>[40, 80])),
          ],
        ),
      ),
    );
    expect(c.view!.scale(kChartAngle).range, const ChartRange(0, 80));
    final ChartRange rings = c.view!.scale(kChartRadius).range;
    expect(rings.min, closeTo(-0.35, 1e-9));
    expect(rings.max, closeTo(1.35, 1e-9));
  });

  testWidgets('a bar is hit by position; its value is drawn at its end', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(host(_gauge(_one(50), controller: c)));
    final ChartHit hit = c.hitTest(const Offset(300, 150), mode: ChartHitMode.nearest).single;
    expect(hit.index, 0);
    expect(hit.value, 50);
    expect(hit.x, 50);
    expect(hit.y, 0, reason: 'the place of its ring');
    expect(hit.base, 0);
    expect(hit.distance, 0);
    expect(hit.valueAxis, Axis.horizontal);
    expect(hit.sector!.innerRadius, closeTo(75, 1e-9));
    expect(hit.sector!.outerRadius, closeTo(150, 1e-9));
    expect(hit.position, within<Offset>(distance: 1e-6, from: const Offset(200, 262.5)));
    expect(hit.series!.label, 'Load');

    // On the empty half of the ring, 125 px from the bar.
    final ChartHit far = c.hitTest(const Offset(100, 150), mode: ChartHitMode.nearest).single;
    expect(far.distance, closeTo(125, 1e-6));
    expect(c.hitTest(const Offset(100, 150), mode: ChartHitMode.nearest, maxDistance: 8), isEmpty);
    expect(c.hitTest(const Offset(300, 150)), isEmpty, reason: 'no points at an x');
  });

  testWidgets('ChartCrosshair.point and a tooltip show the bar under the pointer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(_gauge(_one(50), more: const <Widget>[ChartCrosshair.point(), ChartTooltip()])),
    );
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(300, 150)));
    await tester.pump();
    expect(find.text('Load: '), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    await tester.sendEventToBinding(mouse.hover(const Offset(100, 150)));
    await tester.pump();
    expect(find.text('Load: '), findsNothing);
  });

  testWidgets('three series make three rings in three colours, with a legend', (
    WidgetTester tester,
  ) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(
        angle: _percent,
        radius: const ChartScale.band(),
        innerRadius: 0.25,
        left: const <Widget>[ChartLegend()],
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            RadialBarSeries(
              data: ChartData.fromXY(<double>[i.toDouble()], <double>[100]),
              step: 1,
              label: 'Ring $i',
              isolate: false,
            ),
        ],
      ),
    );
    expect(find.text('Ring 0'), findsOneWidget);
    expect(find.text('Ring 2'), findsOneWidget);
    // The legend takes room on the left, so read the rings from the plot.
    final Rect plot = tester.getRect(find.byType(ChartStack));
    final double radius = plot.shortestSide / 2;
    int at(double fraction) =>
        pixel((plot.center.dx + radius * fraction).round(), plot.center.dy.round());
    // The bands are a quarter of the radius each, starting at a quarter.
    expect(at(0.375), ChartThemeData.defaultPalette[0].toARGB32());
    expect(at(0.625), ChartThemeData.defaultPalette[1].toARGB32());
    expect(at(0.875), ChartThemeData.defaultPalette[2].toARGB32());
  });

  testWidgets('AnimatedChartData lets the value grow', (WidgetTester tester) async {
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(
        angle: _percent,
        innerRadius: 0.5,
        children: <Widget>[
          AnimatedChartData(
            data: _one(100),
            duration: const Duration(seconds: 1),
            curve: Curves.linear,
            builder: (BuildContext context, ChartData animated) =>
                RadialBarSeries(data: animated, color: _red, isolate: false),
          ),
        ],
      ),
    );
    expect(pixel(300, 150), _white);
    await tester.pump(const Duration(milliseconds: 500));
    pixel = await capturePixels(tester);
    // Half way: 50 of 100.
    expect(pixel(300, 150), _red.toARGB32());
    expect(pixel(100, 150), _white);
    await tester.pump(const Duration(milliseconds: 500));
    pixel = await capturePixels(tester);
    expect(pixel(100, 150), _red.toARGB32());
  });
}

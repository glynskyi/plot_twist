import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// In the 400 x 300 host a polar chart is a circle of radius 150 around
// (200, 150). With four categories and values up to 10, the series
// [10, 5, 10, 5] has its corners at (200, 0), (275, 150), (200, 300) and
// (125, 150): a diamond.
const ChartScale _four = ChartScale.band(labels: <String>['N', 'E', 'S', 'W']);
const ChartScale _ten = LinearScale(range: FixedRange(0, 10));
const int _white = 0xFFFFFFFF;
const Color _red = Color(0xFFFF0000);
const Color _green = Color(0xFF00FF00);
const TextStyle _style = TextStyle(fontSize: 10, height: 1, color: Color(0xFF000000));

ChartData _diamond() => ChartData.fromValues(<double>[10, 5, 10, 5]);

Widget _chart(List<Widget> children, {ChartController? controller}) =>
    PolarChart(controller: controller, angle: _four, radius: _ten, children: children);

RadarSeries _radar(
  ChartData data, {
  bool closed = true,
  bool fill = true,
  Color? fillColor = _green,
  double pointRadius = 0,
  String? label,
}) => RadarSeries(
  data: data,
  label: label,
  color: _red,
  width: 6,
  closed: closed,
  fill: fill,
  fillColor: fillColor,
  pointRadius: pointRadius,
  isolate: false,
);

List<Rect> _labels(WidgetTester tester) {
  final RenderObject layer = tester.renderObject(
    find.descendant(of: find.byType(ChartDataLabels), matching: find.byType(ChartPaint)),
  );
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  layer.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return <Rect>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawParagraph)
        (call.invocation.positionalArguments[1] as Offset) &
            Size(
              (call.invocation.positionalArguments[0] as ui.Paragraph).longestLine,
              (call.invocation.positionalArguments[0] as ui.Paragraph).height,
            ),
  ];
}

void main() {
  testWidgets('a corner at each category, the first straight up, joined into a filled shape', (
    WidgetTester tester,
  ) async {
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      _chart(<Widget>[_radar(_diamond())]),
    );
    // The middles of the four sides.
    expect(pixel(237, 75), _red.toARGB32());
    expect(pixel(237, 225), _red.toARGB32());
    expect(pixel(162, 225), _red.toARGB32());
    expect(pixel(162, 75), _red.toARGB32(), reason: 'the last corner is joined to the first');
    expect(pixel(200, 150), _green.toARGB32(), reason: 'the fill');
    expect(pixel(260, 40), _white, reason: 'outside the shape');

    pixel = await renderPixels(tester, _chart(<Widget>[_radar(_diamond(), closed: false)]));
    expect(pixel(237, 75), _red.toARGB32());
    expect(pixel(162, 75), _white, reason: 'an open line has three sides');
    expect(pixel(200, 150), _white, reason: 'and no fill');
  });

  testWidgets('the fill defaults to a quarter of the line colour; dots mark the corners', (
    WidgetTester tester,
  ) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      _chart(<Widget>[_radar(_diamond(), fillColor: null, pointRadius: 8)]),
    );
    final int fill = pixel(200, 150);
    expect(fill >> 16 & 0xFF, 255);
    expect(fill >> 8 & 0xFF, closeTo(191, 1));
    expect(fill & 0xFF, closeTo(191, 1));
    // Beside the corner at three o'clock, off the line but on the dot.
    expect(pixel(280, 150), _red.toARGB32());
    expect(pixel(275, 144), _red.toARGB32());
  });

  testWidgets('a missing value breaks the line and leaves the shape unfilled', (
    WidgetTester tester,
  ) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      _chart(<Widget>[
        _radar(ChartData.fromValues(<double>[10, double.nan, 10, 5])),
      ]),
    );
    expect(pixel(237, 75), _white, reason: 'no side to the missing corner');
    expect(pixel(237, 225), _white);
    expect(pixel(162, 225), _red.toARGB32());
    expect(pixel(162, 75), _red.toARGB32(), reason: 'the two ends are still joined');
    expect(pixel(200, 150), _white);
  });

  testWidgets('automatic ranges: whole bands around, from zero to the largest value', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        PolarChart(
          controller: c,
          angle: const ChartScale.band(),
          children: <Widget>[
            RadarSeries(data: ChartData.fromValues(<double>[4, 8, 6])),
          ],
        ),
      ),
    );
    expect(c.view!.scale(kChartAngle).range, const ChartRange(-0.5, 2.5));
    expect(c.view!.scale(kChartRadius).range, const ChartRange(0, 8));
  });

  testWidgets('every series is hit at the category nearest to the pointer', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        _chart(<Widget>[
          _radar(_diamond(), label: 'A'),
          _radar(ChartData.fromValues(<double>[5, 10, 5, 10]), label: 'B'),
        ], controller: c),
      ),
    );
    // A little above three o'clock, between the two corners there.
    List<ChartHit> hits = c.hitTest(const Offset(300, 140), mode: ChartHitMode.nearest);
    expect(hits.map((ChartHit hit) => hit.series!.label).toSet(), <String>{'A', 'B'});
    expect(hits.map((ChartHit hit) => hit.index), <int>[1, 1]);
    expect(hits.map((ChartHit hit) => hit.distance), <double>[0, 0]);
    final ChartHit a = hits.firstWhere((ChartHit hit) => hit.series!.label == 'A');
    final ChartHit b = hits.firstWhere((ChartHit hit) => hit.series!.label == 'B');
    expect(a.position, within<Offset>(distance: 1e-6, from: const Offset(275, 150)));
    expect(b.position, within<Offset>(distance: 1e-6, from: const Offset(350, 150)));
    expect(a.value, 5);
    expect(a.x, 1);
    expect(a.valueAxis, Axis.vertical);

    // Just left of twelve o'clock is nearest to the first category.
    hits = c.hitTest(const Offset(190, 20), mode: ChartHitMode.nearest);
    expect(hits.map((ChartHit hit) => hit.index), <int>[0, 0]);

    // Outside the circle the distance grows.
    hits = c.hitTest(const Offset(380, 290), mode: ChartHitMode.nearest);
    expect(hits.first.distance, closeTo(const Offset(180, 140).distance - 150, 1e-6));
    expect(c.hitTest(const Offset(380, 290), mode: ChartHitMode.nearest, maxDistance: 8), isEmpty);
    expect(c.hitTest(const Offset(300, 140)), isEmpty, reason: 'no points at an x');
  });

  testWidgets('ChartCrosshair.point and a tooltip list every series at the category', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        _chart(<Widget>[
          _radar(_diamond(), label: 'A'),
          _radar(ChartData.fromValues(<double>[5, 10, 5, 10]), label: 'B'),
          const ChartCrosshair.point(showPoints: true),
          const ChartTooltip(),
        ]),
      ),
    );
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(300, 140)));
    await tester.pump();
    expect(find.text('A: '), findsOneWidget);
    expect(find.text('B: '), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    // A dot on each of the two corners, each with a ring around it.
    final RenderObject crosshair = tester.renderObject(
      find.descendant(of: find.byType(ChartCrosshair), matching: find.byType(ChartPaint)),
    );
    expect(
      crosshair,
      paints
        ..circle()
        ..circle()
        ..circle()
        ..circle(),
    );
    expect(crosshair, isNot(paints..line()));

    // Another category, another pair of values.
    await tester.sendEventToBinding(mouse.hover(const Offset(200, 250)));
    await tester.pump();
    expect(find.text('A: '), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('series take the colours of the palette in turn, and a legend lists them', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        PolarChart(
          controller: c,
          angle: _four,
          radius: _ten,
          top: const <Widget>[ChartLegend()],
          children: <Widget>[
            RadarSeries(data: _diamond(), label: 'A'),
            RadarSeries(data: _diamond(), label: 'B'),
          ],
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(c.series.map((ChartSeries series) => series.color), <Color>[
      ChartThemeData.defaultPalette[0],
      ChartThemeData.defaultPalette[1],
    ]);
    expect(c.series.first.entries, isEmpty);
  });

  testWidgets('data labels stand away from the centre, or towards it where the plot ends', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(_chart(<Widget>[_radar(_diamond()), const ChartDataLabels(style: _style)])),
    );
    // "10" is 20 px wide and "5" is 10 px wide; both are 10 px high.
    expect(_labels(tester), <Rect>[
      const Rect.fromLTWH(190, 4, 20, 10), // below the corner on the upper edge
      const Rect.fromLTWH(279, 145, 10, 10), // right of the corner at three o'clock
      const Rect.fromLTWH(190, 286, 20, 10), // above the corner on the lower edge
      const Rect.fromLTWH(111, 145, 10, 10), // left of the corner at nine o'clock
    ]);
  });

  testWidgets('on a linear angle scale it is a line around the centre', (
    WidgetTester tester,
  ) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(
        angle: const LinearScale(range: FixedRange(0, 360)),
        radius: _ten,
        children: <Widget>[
          _radar(ChartData.fromXY(<double>[0, 90, 180], <double>[10, 10, 10]), closed: false),
        ],
      ),
    );
    // From twelve to three to six o'clock, and not back through the centre.
    expect(pixel(275, 75), _red.toARGB32());
    expect(pixel(275, 225), _red.toARGB32());
    expect(pixel(200, 150), _white);
  });
}

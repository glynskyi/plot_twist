import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// In the 400 x 300 host, a value of 1 is 4 px along x and 3 px along y.
const ChartScale _x = LinearScale(range: FixedRange(0, 100));
const ChartScale _y = LinearScale(range: FixedRange(0, 100));

/// Dots at the pixels (80, 240), (200, 60) and (320, 180).
ChartData _dots() => ChartData.fromXY(<double>[20, 50, 80], <double>[20, 80, 40]);

/// A line through (0, 0), (50, 50) and (100, 100); (50, 50) is at the pixel (200, 150).
ChartData _diagonal() => ChartData.fromXY(<double>[0, 50, 100], <double>[0, 50, 100]);

/// The centres of the circles the last painted layer (the crosshair) draws.
List<Offset> _circles(WidgetTester tester) {
  final RenderObject layer = tester.renderObjectList(find.byType(ChartPaint)).last;
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  layer.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return <Offset>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawCircle)
        call.invocation.positionalArguments.first as Offset,
  ];
}

/// The lines the last painted layer (the crosshair) draws, as (from, to).
List<(Offset, Offset)> _lines(WidgetTester tester) {
  final RenderObject layer = tester.renderObjectList(find.byType(ChartPaint)).last;
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  layer.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return <(Offset, Offset)>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawLine)
        (
          call.invocation.positionalArguments[0] as Offset,
          call.invocation.positionalArguments[1] as Offset,
        ),
  ];
}

void main() {
  group('hit modes', () {
    testWidgets('nearestY finds the closest point along y; series drawn along x add none', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData candles = ChartData(valueColumns: 4)..addRow(50, <double>[40, 60, 30, 50]);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            children: <Widget>[
              ScatterSeries(data: _dots(), label: 'dots'),
              LineSeries(data: _diagonal(), label: 'line'),
              BarSeries(data: _diagonal(), label: 'bars'),
              CandlestickSeries(data: candles, label: 'candles'),
            ],
          ),
        ),
      );
      // 70 px from the top is 10 px below the dot at y = 80, wherever x is.
      final List<ChartHit> hits = c.hitTest(const Offset(10, 70), mode: ChartHitMode.nearestY);
      expect(hits.single.series?.label, 'dots');
      expect(hits.single.y, 80);
      expect(hits.single.distance, closeTo(10, 1e-9));

      expect(
        c.hitTest(const Offset(10, 70)).map((ChartHit h) => h.series?.label),
        containsAll(<String>['dots', 'line', 'bars', 'candles']),
      );
    });

    testWidgets('a hit has a value, an argument and, for a bar, a base', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData stacked = ChartData(valueColumns: 2)..addRow(50, <double>[60, 20]);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            children: <Widget>[
              BarSeries(data: stacked, baseColumn: 1, step: 10, label: 'floating'),
              BarSeries(data: stacked, step: 10, baseline: 5, label: 'plain'),
              LineSeries(data: _diagonal(), label: 'line'),
            ],
          ),
        ),
      );
      final Map<String?, ChartHit> hits = <String?, ChartHit>{
        for (final ChartHit hit in c.hitsAt(50)) hit.series?.label: hit,
      };
      final ChartHit floating = hits['floating']!;
      expect(floating.valueAxis, Axis.vertical);
      expect(floating.value, 60);
      expect(floating.argument, 50);
      expect(floating.base, 20);
      expect(hits['plain']!.base, 5);
      expect(hits['line']!.base, isNull);
      expect(hits['line']!.value, 50);

      const ChartHit sideways = ChartHit(
        x: 7,
        y: 2,
        position: Offset.zero,
        distance: 0,
        base: 1,
        valueAxis: Axis.horizontal,
      );
      expect(sideways.value, 7);
      expect(sideways.argument, 2);
      final ChartHit attributed = sideways.withSeries(c.series.first);
      expect(attributed.base, 1);
      expect(attributed.valueAxis, Axis.horizontal);
    });

    test('a focus has a mode, which counts for equality', () {
      const ChartFocus alongX = ChartFocus(x: 1, y: 2);
      expect(alongX.mode, ChartHitMode.nearestX);
      expect(alongX, const ChartFocus(x: 1, y: 2));
      expect(alongX == const ChartFocus(x: 1, y: 2, mode: ChartHitMode.nearest), isFalse);
    });
  });

  group('ChartController.hitsFor', () {
    Future<ChartController> pump(WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            children: <Widget>[
              ScatterSeries(data: _dots(), label: 'dots'),
              LineSeries(data: _diagonal(), label: 'line'),
            ],
          ),
        ),
      );
      return c;
    }

    testWidgets('a focus along x stands for the point of each series at that x', (
      WidgetTester tester,
    ) async {
      final ChartController c = await pump(tester);
      final List<ChartHit> hits = c.hitsFor(ChartFocus(x: 50, source: c));
      expect(hits.map((ChartHit h) => (h.series?.label, h.y)), <(String?, double)>{
        ('dots', 80),
        ('line', 50),
      });
      expect(hits.map((ChartHit h) => h.y), c.hitsAt(50).map((ChartHit h) => h.y));
    });

    testWidgets('a nearest focus stands for the points at its position only', (
      WidgetTester tester,
    ) async {
      final ChartController c = await pump(tester);
      final List<ChartHit> onDot = c.hitsFor(
        ChartFocus(x: 50, y: 80, mode: ChartHitMode.nearest, source: c),
      );
      expect(onDot.single.series?.label, 'dots');
      expect(onDot.single.index, 1);

      final List<ChartHit> onLine = c.hitsFor(
        ChartFocus(x: 50, y: 50, mode: ChartHitMode.nearest, source: c),
      );
      expect(onLine.single.series?.label, 'line');

      expect(c.hitsFor(ChartFocus(x: 30, y: 70, mode: ChartHitMode.nearest, source: c)), isEmpty);
    });

    testWidgets('a nearest focus of another chart, or one without a y, is matched along x', (
      WidgetTester tester,
    ) async {
      final ChartController c = await pump(tester);
      final Object other = Object();
      final List<ChartHit> mirrored = c.hitsFor(
        ChartFocus(x: 50, y: 3, mode: ChartHitMode.nearest, source: other),
      );
      expect(mirrored.map((ChartHit h) => h.series?.label), containsAll(<String>['dots', 'line']));
      final List<ChartHit> withoutY = c.hitsFor(
        ChartFocus(x: 50, mode: ChartHitMode.nearest, source: c),
      );
      expect(withoutY, hasLength(2));
    });

    testWidgets('a focus along y stands for the points at that y', (WidgetTester tester) async {
      final ChartController c = await pump(tester);
      final List<ChartHit> hits = c.hitsFor(
        ChartFocus(x: 0, y: 40, mode: ChartHitMode.nearestY, source: c),
      );
      expect(hits.single.series?.label, 'dots');
      expect(hits.single.x, 80);
      expect(c.hitsFor(ChartFocus(x: 0, mode: ChartHitMode.nearestY, source: c)), isEmpty);
    });
  });

  group('ChartCrosshair modes', () {
    testWidgets('nearest snaps to the closest point within snapDistance, in both dimensions', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            children: <Widget>[
              ScatterSeries(data: _dots(), label: 'dots'),
              LineSeries(data: _diagonal(), label: 'line'),
              const ChartCrosshair(mode: ChartHitMode.nearest, snapDistance: 20, horizontal: true),
              const ChartTooltip(),
            ],
          ),
        ),
      );
      final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
      // 8 px from the dot at the pixel (200, 60).
      await tester.sendEventToBinding(mouse.hover(const Offset(205, 66)));
      await tester.pump();
      expect(c.focus.value, ChartFocus(x: 50, y: 80, mode: ChartHitMode.nearest, source: c));
      // Only the pointed-at dot is marked and listed, not the line at the same x.
      expect(_circles(tester).toSet(), <Offset>{const Offset(200, 60)});
      expect(_lines(tester), <(Offset, Offset)>[
        (const Offset(200, 0), const Offset(200, 300)),
        (const Offset(0, 60), const Offset(400, 60)),
      ]);
      expect(find.text('dots: '), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('line: '), findsNothing);

      // Nothing within 20 px: the crosshair follows the pointer and no point is listed.
      await tester.sendEventToBinding(mouse.hover(const Offset(100, 150)));
      await tester.pump();
      expect(c.focus.value, ChartFocus(x: 25, y: 50, mode: ChartHitMode.nearest, source: c));
      expect(c.hitsFor(c.focus.value!), isEmpty);
      expect(_circles(tester), isEmpty);
      expect(find.text('dots: '), findsNothing);
    });

    testWidgets('snapDistance also bounds the snap along x', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            children: <Widget>[
              ScatterSeries(data: _dots()),
              const ChartCrosshair(snapDistance: 10),
            ],
          ),
        ),
      );
      final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(206, 250)));
      await tester.pump();
      expect(c.focus.value?.x, 50);
      await tester.sendEventToBinding(mouse.hover(const Offset(140, 250)));
      await tester.pump();
      expect(c.focus.value?.x, 35);
    });

    test('the lines default to the mode', () {
      const ChartCrosshair alongX = ChartCrosshair();
      expect((alongX.vertical, alongX.horizontal), (true, false));
      const ChartCrosshair alongY = ChartCrosshair(mode: ChartHitMode.nearestY);
      expect((alongY.vertical, alongY.horizontal), (false, true));
      const ChartCrosshair nearest = ChartCrosshair(mode: ChartHitMode.nearest);
      expect((nearest.vertical, nearest.horizontal), (true, false));
      const ChartCrosshair chosen = ChartCrosshair(
        mode: ChartHitMode.nearestY,
        vertical: true,
        horizontal: false,
      );
      expect((chosen.vertical, chosen.horizontal), (true, false));
    });

    testWidgets('nearestY snaps along y, and the axis badge shows the snapped value', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            left: <Widget>[
              ChartAxis(
                markers: <Widget>[
                  ChartCrosshairBadge(
                    builder: (BuildContext context, double value) => Text('at $value'),
                  ),
                ],
              ),
            ],
            children: <Widget>[
              ScatterSeries(data: _dots(), label: 'dots'),
              const ChartCrosshair(mode: ChartHitMode.nearestY),
              const ChartTooltip(),
            ],
          ),
        ),
      );
      final ChartView view = c.view!;
      final Offset plotOrigin = -view.chartRect.topLeft;
      final Offset dot = Offset(view.x.toPixel(80), view.y.toPixel(40));
      final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
      // Far to the left of the dot at y = 40, and 6 px above it.
      await tester.sendEventToBinding(mouse.hover(plotOrigin + Offset(20, dot.dy - 6)));
      await tester.pump();
      final ChartFocus focus = c.focus.value!;
      expect(focus.mode, ChartHitMode.nearestY);
      expect(focus.y, 40);
      expect(focus.x, closeTo(view.x.toValue(20), 1e-9));
      expect(c.hitsFor(focus).single.x, 80);
      expect(find.text('at 40.0'), findsOneWidget);
      // One horizontal line through the dot, and the dot is marked.
      expect(_lines(tester), <(Offset, Offset)>[
        (Offset(0, dot.dy), Offset(view.size.width, dot.dy)),
      ]);
      expect(_circles(tester).toSet(), <Offset>{dot});
      expect(find.text('dots: '), findsOneWidget);
    });

    testWidgets('a tap in nearest mode holds the point until it is tapped again', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            children: <Widget>[
              ScatterSeries(data: _dots()),
              const ChartCrosshair(
                mode: ChartHitMode.nearest,
                snapDistance: 20,
                tap: true,
                hover: false,
              ),
            ],
          ),
        ),
      );
      await tester.tapAt(const Offset(203, 62));
      await tester.pump();
      expect(c.focus.value?.x, 50);
      expect(c.focus.value?.y, 80);
      // Another pixel of the same dot.
      await tester.tapAt(const Offset(197, 57));
      await tester.pump();
      expect(c.focus.value, isNull);
      await tester.tapAt(const Offset(322, 178));
      await tester.pump();
      expect(c.focus.value?.x, 80);
    });

    testWidgets('a crosshair and a tooltip can use a second vertical scale', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      // On the scale 'r' (0 to 10), the dot (50, 8) is at the pixel (200, 60).
      final ChartData dots = ChartData.fromXY(<double>[50], <double>[8]);
      Widget build({required Object crosshairScale, required Object tooltipScale}) => host(
        Chart(
          controller: c,
          x: _x,
          y: _y,
          yScales: const <Object, ChartScale>{'r': LinearScale(range: FixedRange(0, 10))},
          children: <Widget>[
            ScatterSeries(data: dots, yScale: 'r', label: 'dots'),
            ChartCrosshair(mode: ChartHitMode.nearest, snapDistance: 20, yScale: crosshairScale),
            ChartTooltip(yScale: tooltipScale),
          ],
        ),
      );
      final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.pumpWidget(build(crosshairScale: 'r', tooltipScale: 'r'));
      await tester.sendEventToBinding(mouse.hover(const Offset(203, 62)));
      await tester.pump();
      expect(c.focus.value?.y, 8);
      expect(find.text('8'), findsOneWidget);

      // The focus is kept in the units of the crosshair's scale.
      await tester.pumpWidget(build(crosshairScale: kChartY, tooltipScale: kChartY));
      await tester.sendEventToBinding(mouse.hover(const Offset(204, 63)));
      await tester.pump();
      expect(c.focus.value?.y, closeTo(80, 1e-9));
      expect(find.text('8'), findsOneWidget);
    });
  });
}

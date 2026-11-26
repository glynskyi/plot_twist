// Recipes that no gallery demo shows, checked here so the docs and answers that describe them stay
// true.
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(800, 600)),
    child: child,
  ),
);

Widget _host(Widget chart) => _app(
  Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 400, height: 300, child: chart),
  ),
);

/// Drag-to-scrub written with the public API: a horizontal drag moves the shared focus.
class DragScrub extends StatelessWidget {
  const DragScrub({super.key, required this.chart});

  final ChartController chart;

  void _focus(Offset local) {
    final ChartView view = chart.view!;
    final double x = view.x.toValue(view.chartToPlot(local).dx);
    chart.focus.value = ChartFocus(x: x, source: chart);
  }

  @override
  Widget build(BuildContext context) => ChartGestureDetector(
    gestures: <Type, GestureRecognizerFactory>{
      HorizontalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
            HorizontalDragGestureRecognizer.new,
            (HorizontalDragGestureRecognizer r) => r
              ..onStart = ((DragStartDetails d) => _focus(d.localPosition))
              ..onUpdate = ((DragUpdateDetails d) => _focus(d.localPosition))
              ..onEnd = ((DragEndDetails d) => chart.focus.value = null),
          ),
    },
  );
}

void main() {
  testWidgets(
    'a drag recognizer in the chart scrubs, and the PageView around it stays on its page',
    (WidgetTester tester) async {
      final ChartController c = ChartController();
      final PageController pages = PageController();
      final ChartData data = ChartData.fromValues(<double>[for (int i = 0; i <= 100; i++) i * 1.0]);
      addTearDown(c.dispose);
      addTearDown(pages.dispose);
      addTearDown(data.dispose);
      final List<double> seen = <double>[];
      c.focus.addListener(() {
        final ChartFocus? f = c.focus.value;
        if (f != null) seen.add(f.x);
      });
      await tester.pumpWidget(
        _app(
          PageView(
            controller: pages,
            children: <Widget>[
              Chart(
                controller: c,
                children: <Widget>[
                  LineSeries(data: data),
                  DragScrub(chart: c),
                  const ChartTooltip(),
                ],
              ),
              const SizedBox.expand(),
            ],
          ),
        ),
      );
      final TestGesture g = await tester.startGesture(const Offset(600, 300));
      await g.moveBy(const Offset(-30, 0));
      await g.moveBy(const Offset(-200, 0));
      await tester.pump();
      // While dragging, the focus follows the finger: 370 px of 800 is about x = 46.
      expect(c.focus.value, isNotNull);
      expect(c.focus.value!.x, moreOrLessEquals(370 / 800 * 100, epsilon: 1));
      await g.up();
      await tester.pumpAndSettle();
      expect(pages.page, 0);
      expect(seen.length, greaterThan(1));
    },
  );

  testWidgets('log scales on both axes lay out, label decades and pan by a constant ratio', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    final ChartData spectrum = ChartData.generate(400, (int i) {
      final double f = 20 * (1000.0 * (i / 399)).clamp(1, 1000);
      return (f, 1000 / f);
    });
    addTearDown(c.dispose);
    addTearDown(spectrum.dispose);
    await tester.pumpWidget(
      _host(
        Chart(
          controller: c,
          x: const .log(),
          y: const .log(),
          left: const <Widget>[ChartAxis()],
          bottom: const <Widget>[ChartAxis()],
          children: <Widget>[
            LineSeries(data: spectrum),
            const ChartPanZoom(panY: true, zoomY: true, inertia: false),
            const ChartCrosshair(),
            const ChartTooltip(),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(c.x.min, greaterThan(0));
    expect(find.text('100'), findsWidgets);
    final double before = c.x.max / c.x.min;
    final TestGesture g = await tester.startGesture(const Offset(250, 120));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-60, 0));
    await g.up();
    await tester.pumpAndSettle();
    // Panning on a log scale keeps the ratio max/min (it moves in decades, not units).
    expect(c.x.max / c.x.min, moreOrLessEquals(before, epsilon: before * 1e-6));
  });

  testWidgets(
    'a window that starts left of the data asks the loader for older rows, and keeps its place',
    (WidgetTester tester) async {
      final ChartController c = ChartController();
      final ChartData data = ChartData.fromValues(<double>[
        for (int i = 0; i < 50; i++) i * 1.0,
      ], start: 1000);
      addTearDown(c.dispose);
      addTearDown(data.dispose);
      int calls = 0;
      Future<bool> loadOlder() async {
        calls++;
        final double first = data.x(0);
        data.prependAll(<double>[
          for (int i = 50; i >= 1; i--) first - i,
        ], List<double>.filled(50, 1));
        return calls < 2;
      }

      final double first = data.x(0), last = data.x(data.length - 1);
      await tester.pumpWidget(
        _host(
          Chart(
            controller: c,
            x: ChartScale.linear(range: FixedRange(first - (last - first) / 9, last)),
            y: const .linear(range: .fitVisible()),
            children: <Widget>[
              LineSeries(data: data),
              const ChartPanZoom(zoomY: true, anisotropicPinch: true),
              ChartLoader(data: data, onLoadBefore: loadOlder),
            ],
          ),
        ),
      );
      final double min0 = c.x.min, max0 = c.x.max;
      await tester.pumpAndSettle();
      expect(calls, greaterThan(0));
      expect(data.x(0), lessThan(first));
      expect(c.x.min, min0);
      expect(c.x.max, max0);
    },
  );

  testWidgets(
    'a following window pauses on a pan, holds while data arrives, and follows after resetToAuto',
    (WidgetTester tester) async {
      final ChartController c = ChartController();
      final ChartData samples = ChartData();
      for (int i = 0; i < 200; i++) {
        samples.add(i.toDouble(), (i % 10).toDouble());
      }
      addTearDown(c.dispose);
      addTearDown(samples.dispose);
      await tester.pumpWidget(
        _host(
          Chart(
            controller: c,
            x: const .linear(range: .follow(span: 60)),
            children: <Widget>[
              LineSeries(data: samples),
              const ChartPanZoom(inertia: false),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(c.x.max, moreOrLessEquals(199, epsilon: 1e-9));
      final TestGesture g = await tester.startGesture(const Offset(200, 150));
      await g.moveBy(const Offset(20, 0));
      await g.moveBy(const Offset(100, 0));
      await g.up();
      await tester.pump();
      expect(c.x.isAuto, isFalse);
      final ChartRange paused = c.x.range;
      for (int i = 200; i < 260; i++) {
        samples.add(i.toDouble(), 1);
      }
      await tester.pump();
      expect(c.x.range, paused);
      c.x.resetToAuto();
      await tester.pump();
      expect(c.x.isAuto, isTrue);
      expect(c.x.max, moreOrLessEquals(259, epsilon: 1e-9));
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('a crosshair pinned by a tap keeps its x through a pan', (WidgetTester tester) async {
    final ChartController c = ChartController();
    final ChartData days = ChartData.fromValues(<double>[
      for (int i = 0; i < 100; i++) (i % 7) * 1.0,
    ]);
    addTearDown(c.dispose);
    addTearDown(days.dispose);
    await tester.pumpWidget(
      _host(
        Chart(
          controller: c,
          x: const .linear(range: .fixed(0, 50)),
          children: <Widget>[
            LineSeries(data: days),
            const ChartPanZoom(inertia: false),
            const ChartCrosshair(tap: true),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(200, 150));
    await tester.pump(const Duration(milliseconds: 500));
    final double? pinned = c.focus.value?.x;
    expect(pinned, isNotNull);
    final TestGesture g = await tester.startGesture(const Offset(200, 150));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-100, 0));
    await g.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.x.min, greaterThan(0));
    expect(c.focus.value?.x, pinned);
  });

  testWidgets('ChartPositioned corner anchors sit on the plot corners', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Chart(
          left: <Widget>[ChartAxis(extent: .fixed(40))],
          bottom: <Widget>[ChartAxis(extent: .fixed(30))],
          children: <Widget>[
            ChartPositioned(
              x: .start,
              y: .start,
              alignment: .topLeft,
              child: SizedBox(key: Key('tl'), width: 10, height: 10),
            ),
            ChartPositioned(
              x: .end,
              y: .end,
              alignment: .bottomRight,
              child: SizedBox(key: Key('br'), width: 10, height: 10),
            ),
          ],
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const Key('tl'))), const Offset(40, 0));
    expect(tester.getBottomRight(find.byKey(const Key('br'))), const Offset(400, 270));
  });

  testWidgets('a stacked area chart whose tooltip shows the size of each layer', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    // Three products over six months; the stack carries each layer's base.
    final List<String> names = <String>['Basic', 'Plus', 'Pro'];
    final List<ChartData> layers = ChartData.stacked(<ChartData>[
      ChartData.fromValues(<double>[10, 12, 15, 14, 18, 20]),
      ChartData.fromValues(<double>[5, 6, 6, 8, 9, 12]),
      ChartData.fromValues(<double>[2, 2, 3, 5, 6, 9]),
    ]);
    await tester.pumpWidget(
      _host(
        Chart(
          controller: c,
          y: const LinearScale(range: FitDataRange(includeZero: true)),
          top: const <Widget>[ChartLegend()],
          children: <Widget>[
            for (int i = 0; i < layers.length; i++)
              LineSeries(data: layers[i], baseColumn: 1, label: names[i], curve: LineCurve.smooth),
            const ChartCrosshair(),
            ChartTooltip(
              builder: (BuildContext context, List<ChartHit> hits) => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // A hit carries the top of its layer and the top of the one below.
                  for (final ChartHit hit in hits)
                    Text('${hit.series!.label}: ${(hit.value - hit.base!).round()}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // The whole stack fits: the top layer ends at 20 + 12 + 9.
    expect(c.y.range, const ChartRange(0, 41));
    expect(find.text('Pro'), findsOneWidget);
    // The layers take the first three colours of the palette.
    expect(
      c.series.map((ChartSeries s) => s.color!.toARGB32()),
      ChartThemeData.defaultPalette.take(3).map((Color color) => color.toARGB32()),
    );

    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    final ChartView view = c.view!;
    await tester.sendEventToBinding(
      mouse.hover(-view.chartRect.topLeft + Offset(view.x.toPixel(3) + 2, 60)),
    );
    await tester.pump();
    expect(c.focus.value?.x, 3);
    expect(find.text('Basic: 14'), findsOneWidget);
    expect(find.text('Plus: 8'), findsOneWidget);
    expect(find.text('Pro: 5'), findsOneWidget);
  });

  testWidgets('candles as OHLC bars above a dashed line at the last close', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData candles = ChartData(valueColumns: 4)
      ..addRow(0, <double>[10, 14, 9, 13])
      ..addRow(1, <double>[13, 15, 11, 12])
      ..addRow(2, <double>[12, 18, 12, 17]);
    final double last = candles.value(candles.length - 1, 3);
    await tester.pumpWidget(
      _host(
        Chart(
          controller: c,
          children: <Widget>[
            CandlestickSeries(data: candles, style: CandleStyle.ohlc, label: 'ACME'),
            // Not a series: it is no legend entry and takes no palette colour.
            ChartReferenceLine.y(
              last,
              dash: const <double>[4, 4],
              label: Text('last ${last.toStringAsFixed(0)}'),
            ),
          ],
        ),
      ),
    );
    expect(c.series.single.label, 'ACME');
    expect(find.text('last 17'), findsOneWidget);
    // The label sits on the line, at the right end of the plot.
    final Rect label = tester.getRect(find.text('last 17'));
    expect(label.right, lessThanOrEqualTo(400));
    expect(label.right, greaterThan(380));
    expect((label.bottom - c.view!.y.toPixel(17)).abs(), lessThan(8));
    expect(c.hitsAt(2).single.datum, const ChartCandle(open: 12, high: 18, low: 12, close: 17));
  });
}

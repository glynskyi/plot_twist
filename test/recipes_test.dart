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
}

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

const ChartScale _x = LinearScale(range: FixedRange(0, 100));
const ChartScale _y = LinearScale(range: FixedRange(0, 100));

ChartData _line() => ChartData.generate(11, (int i) => (i * 10.0, i * 10.0));

Widget _overlayHost(Widget chart) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(800, 600)),
    child: Overlay(
      initialEntries: <OverlayEntry>[
        OverlayEntry(
          builder: (BuildContext context) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 400, height: 300, child: chart),
          ),
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('hovering sets a snapped focus in data space; leaving clears it', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = _line();
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: _x,
          y: _y,
          children: <Widget>[
            LineSeries(data: data, id: 'a', label: 'A'),
            const ChartCrosshair(),
          ],
        ),
      ),
    );
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    // 212 px of 400 is x = 53; the nearest point is at 50.
    await tester.sendEventToBinding(mouse.hover(const Offset(212, 100)));
    await tester.pump();
    expect(c.focus.value?.x, 50);
    final List<ChartHit> hits = c.hitsAt(c.focus.value!.x);
    expect(hits.single.series?.label, 'A');
    expect(hits.single.y, 50);

    // The focus is data, so it survives a pan.
    c.x.jumpTo(20, 120);
    await tester.pump();
    expect(c.focus.value?.x, 50);

    await tester.sendEventToBinding(mouse.hover(const Offset(700, 500)));
    await tester.pump();
    expect(c.focus.value, isNull);
  });

  testWidgets('the tooltip is a widget that follows the data without rebuilding', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = _line();
    int builds = 0;
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: _x,
          y: _y,
          children: <Widget>[
            LineSeries(data: data),
            ChartTooltip(
              builder: (BuildContext context, List<ChartHit> hits) {
                builds++;
                return SizedBox(
                  key: const Key('tip'),
                  width: 60,
                  height: 30,
                  child: Text('${hits.first.y}'),
                );
              },
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(const Key('tip')), findsNothing);

    c.focus.value = const ChartFocus(x: 50);
    await tester.pump();
    expect(builds, 1);
    expect(find.text('50.0'), findsOneWidget);
    // Above the point (200, 150), 12 px away.
    Rect rect = tester.getRect(find.byKey(const Key('tip')));
    expect(rect.bottomCenter, const Offset(200, 138));

    // Panning moves it with the point; the same data is under the focus, so
    // the content is not rebuilt.
    c.x.jumpTo(10, 110);
    await tester.pump();
    rect = tester.getRect(find.byKey(const Key('tip')));
    expect(rect.bottomCenter.dx, moreOrLessEquals(160, epsilon: 1e-6));
    expect(builds, 1);

    // Near the top of the plot it flips below the point.
    c.focus.value = const ChartFocus(x: 100);
    await tester.pump();
    rect = tester.getRect(find.byKey(const Key('tip')));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(builds, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an overlay tooltip escapes the chart and tracks its anchor in the same frame', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = _line();
    await tester.pumpWidget(
      _overlayHost(
        Chart(
          controller: c,
          x: _x,
          y: _y,
          children: <Widget>[
            LineSeries(data: data),
            ChartTooltip(
              overlay: true,
              // Below and to the right of the point: at x=100,y=100 that is
              // outside the 400x300 chart.
              alignment: Alignment.topLeft,
              offset: const Offset(8, 8),
              builder: (BuildContext context, List<ChartHit> hits) =>
                  const SizedBox(key: Key('tip'), width: 120, height: 40),
            ),
          ],
        ),
      ),
    );
    c.focus.value = const ChartFocus(x: 100);
    await tester.pump();
    Rect rect = tester.getRect(find.byKey(const Key('tip')));
    // The point is at the top-right corner of the chart: (400, 0).
    expect(rect.topLeft, const Offset(408, 8));
    expect(rect.right, greaterThan(400), reason: 'drawn outside the chart');

    c.x.jumpTo(50, 150);
    await tester.pump();
    rect = tester.getRect(find.byKey(const Key('tip')));
    expect(rect.left, moreOrLessEquals(208, epsilon: 1e-6), reason: 'moved in the same frame');
    expect(tester.takeException(), isNull);
  });

  testWidgets('linked charts share a scale and a focus', (WidgetTester tester) async {
    final ChartScaleController time = ChartScaleController();
    final ValueNotifier<ChartFocus?> focus = ValueNotifier<ChartFocus?>(null);
    final ChartController top = ChartController(x: time, focus: focus);
    final ChartController bottom = ChartController(x: time, focus: focus);
    addTearDown(top.dispose);
    addTearDown(bottom.dispose);
    addTearDown(time.dispose);
    addTearDown(focus.dispose);
    final ChartData a = _line();
    final ChartData b = ChartData.generate(21, (int i) => (i * 10.0, 5.0));
    final ChartGutterGroup gutter = ChartGutterGroup();
    int externalBuilds = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: <Widget>[
            ListenableBuilder(
              listenable: time,
              builder: (BuildContext context, Widget? child) {
                externalBuilds++;
                return Text('${time.min.round()}..${time.max.round()}');
              },
            ),
            SizedBox(
              height: 200,
              child: Chart(
                controller: top,
                y: const LinearScale(range: FixedRange(0, 1000000)),
                left: <Widget>[ChartAxis(extent: ChartAxisExtent.shared(gutter))],
                children: <Widget>[
                  LineSeries(data: a),
                  const ChartCrosshair(),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: Chart(
                controller: bottom,
                y: const LinearScale(range: FixedRange(0, 10)),
                left: <Widget>[ChartAxis(extent: ChartAxisExtent.shared(gutter))],
                children: <Widget>[
                  LineSeries(data: b),
                  const ChartCrosshair(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    // The shared x scale fits the data of both charts.
    expect(time.range, const ChartRange(0, 200));
    expect(find.text('0..200'), findsOneWidget);
    // Both plots start at the same x: the narrow axis matches the wide one.
    expect(top.view!.chartRect.left, bottom.view!.chartRect.left);
    expect(top.view!.chartRect.left, lessThan(-30));

    time.jumpTo(50, 150);
    await tester.pump();
    expect(top.view!.x.min, 50);
    expect(bottom.view!.x.min, 50);
    expect(find.text('50..150'), findsOneWidget);
    expect(externalBuilds, lessThan(6));

    focus.value = ChartFocus(x: 100, source: top);
    await tester.pump();
    expect(bottom.hitsAt(100).single.y, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a series with a gap at the focused x is left out of the hits', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final List<double> xs = <double>[0, 10, 20, 30];
    // A NaN says "no value here". It is not replaced by a neighbouring row.
    final ChartData a = ChartData.fromXY(xs, <double>[10, 20, 30, 40]);
    final ChartData b = ChartData.fromXY(xs, <double>[50, 60, double.nan, 80]);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: const LinearScale(range: FixedRange(0, 30)),
          y: _y,
          children: <Widget>[
            LineSeries(data: a, label: 'A'),
            LineSeries(data: b, label: 'B'),
            BarSeries(data: b, label: 'bars', step: 10),
            const ChartCrosshair(),
            const ChartTooltip(),
          ],
        ),
      ),
    );
    expect(c.hitsAt(10).map((ChartHit h) => h.series?.label), <String?>['A', 'B', 'bars']);
    expect(c.hitsAt(20).map((ChartHit h) => h.series?.label), <String?>['A']);

    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(Offset(c.view!.x.toPixel(21), 100)));
    await tester.pump();
    expect(c.focus.value?.x, 20);
    expect(find.textContaining('A: '), findsOneWidget);
    expect(find.textContaining('B: '), findsNothing);
  });

  testWidgets('bar, scatter and line series share one plot with two y scales', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData rain = ChartData.fromValues(<double>[1, 4, 2, 0, 3]);
    final ChartData temp = ChartData.fromValues(<double>[12, 15, 11, 9, 14]);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: const BandScale(labels: <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri']),
          y: const LinearScale(range: FitDataRange(padding: 0.1)),
          scales: const <Object, ChartScale>{
            'mm': LinearScale(range: FitDataRange(includeZero: true)),
          },
          left: const <Widget>[ChartAxis()],
          right: const <Widget>[ChartAxis(scale: 'mm')],
          bottom: const <Widget>[ChartAxis()],
          children: <Widget>[
            BarSeries(data: rain, yScale: 'mm', label: 'Rain'),
            LineSeries(data: temp, label: 'Temp'),
            ScatterSeries(data: temp),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // Bars reach half a band beyond the first and last category.
    expect(c.x.range, const ChartRange(-0.5, 4.5));
    expect(c.scale('mm').range, const ChartRange(0, 4));
    expect(c.y.min, lessThan(9));
    expect(find.text('Wed'), findsOneWidget);
    expect(c.series.map((ChartSeries s) => s.label), <String?>['Rain', 'Temp', null]);
    // A bar hit carries its rectangle.
    final ChartHit bar = c.hitTest(Offset(c.view!.x.toPixel(1), 10)).first;
    expect(bar.rect, isNotNull);
    expect(bar.y, 4);
  });

  testWidgets('animated data morphs without rebuilding the series widget', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData week = ChartData.fromValues(<double>[10, 20, 30]);
    final ChartData other = ChartData.fromValues(<double>[30, 20, 10, 40]);
    int builds = 0;
    Widget build(ChartData data) => host(
      Chart(
        controller: c,
        children: <Widget>[
          AnimatedChartData(
            data: data,
            animateOnMount: false,
            duration: const Duration(milliseconds: 200),
            curve: Curves.linear,
            builder: (BuildContext context, ChartData animated) {
              builds++;
              return BarSeries(data: animated, id: 'bars');
            },
          ),
        ],
      ),
    );
    await tester.pumpWidget(build(week));
    expect(c.seriesById('bars')!.valueAt(0), 10);
    final int before = builds;

    await tester.pumpWidget(build(other));
    final int afterSwap = builds;
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.seriesById('bars')!.valueAt(0), moreOrLessEquals(20, epsilon: 1e-6));
    // The new fourth bar is growing from the baseline.
    expect(c.seriesById('bars')!.valueAt(3), moreOrLessEquals(20, epsilon: 1e-6));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.seriesById('bars')!.valueAt(0), 30);
    expect(c.seriesById('bars')!.valueAt(3), 40);
    expect(builds, afterSwap, reason: 'animation frames do not rebuild');
    expect(afterSwap - before, 1);
  });

  testWidgets('the loader asks for more data near the edge and prepending does not jump', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = ChartData.generate(101, (int i) => (100.0 + i, i.toDouble()));
    int loads = 0;
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: const LinearScale(range: FixedRange(150, 200)),
          y: _y,
          children: <Widget>[
            LineSeries(data: data),
            ChartLoader(
              data: data,
              prefetch: 0.5,
              onLoadBefore: () async {
                loads++;
                final double first = data.x(0);
                data.prependAll(
                  List<double>.generate(50, (int i) => first - 50 + i),
                  List<double>.filled(50, 1),
                );
                return first - 50 > 0;
              },
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(loads, 0, reason: 'far from the loaded edge');

    // Within half a window of the first loaded value (100).
    c.x.jumpTo(110, 160);
    await tester.pump();
    await tester.pump();
    expect(loads, 1);
    expect(data.x(0), 50);
    expect(c.x.range, const ChartRange(110, 160), reason: 'the view did not move');
    expect(data.firstOrdinal, -50);
  });

  testWidgets('the loader asks for newer data near the last loaded value, until there is none', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = ChartData.generate(101, (int i) => (i.toDouble(), i.toDouble()));
    final List<bool> loading = <bool>[];
    int loads = 0;
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: const LinearScale(range: FixedRange(0, 50)),
          y: _y,
          children: <Widget>[
            LineSeries(data: data),
            ChartLoader(
              data: data,
              prefetch: 0.5,
              onLoadingChanged: loading.add,
              onLoadAfter: () async {
                loads++;
                final double last = data.x(data.length - 1);
                data.addAll(
                  List<double>.generate(50, (int i) => last + 1 + i),
                  List<double>.filled(50, 1),
                );
                return last + 50 < 200;
              },
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(loads, 0, reason: 'far from the loaded edge');

    // Within half a window of the last loaded value (100).
    c.x.jumpTo(40, 90);
    await tester.pump();
    await tester.pump();
    expect(loads, 1);
    expect(data.x(data.length - 1), 150);
    expect(data.firstOrdinal, 0, reason: 'rows added at the end keep their ordinals');
    expect(c.x.range, const ChartRange(40, 90), reason: 'the view did not move');
    expect(loading, <bool>[true, false]);

    // The second page is the last one: the callback completed with false.
    c.x.jumpTo(120, 170);
    await tester.pump();
    await tester.pump();
    expect(loads, 2);
    expect(data.x(data.length - 1), 200);
    c.x.jumpTo(180, 230);
    await tester.pump();
    await tester.pump();
    expect(loads, 2, reason: 'nothing more to load on this side');
  });

  testWidgets('a failed load is reported once and tried again when the window moves', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = ChartData.generate(101, (int i) => (100.0 + i, i.toDouble()));
    final List<Object> errors = <Object>[];
    final List<bool> loading = <bool>[];
    int calls = 0;
    Widget chart({required bool report}) => host(
      Chart(
        controller: c,
        x: const LinearScale(range: FixedRange(110, 160)),
        y: _y,
        children: <Widget>[
          LineSeries(data: data),
          ChartLoader(
            data: data,
            onLoadingChanged: loading.add,
            onError: report ? (Object error, StackTrace stack) => errors.add(error) : null,
            onLoadBefore: () async {
              calls++;
              if (calls == 1 || calls == 3) throw StateError('offline');
              final double first = data.x(0);
              data.prependAll(<double>[first - 2, first - 1], <double>[1, 1]);
              return false;
            },
          ),
        ],
      ),
    );
    await tester.pumpWidget(chart(report: true));
    await tester.pump();
    await tester.pump();
    expect(calls, 1);
    expect(errors.single, isStateError);
    expect(loading, <bool>[true, false], reason: 'the failed load is over');
    // Not asked again while nothing changes.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(calls, 1);

    // The user keeps panning: the loader tries again, and this time it works.
    c.x.jumpTo(105, 155);
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(data.x(0), 98);
    expect(errors, hasLength(1));
    expect(tester.takeException(), isNull);

    // Without onError the failure is reported the way Flutter reports errors.
    data.replaceAll(<double>[100, 101], <double>[1, 2]);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(chart(report: false));
    await tester.pump();
    await tester.pump();
    expect(calls, 3);
    expect(tester.takeException(), isStateError);
  });

  testWidgets('a load that says there is more but adds nothing is not repeated at once', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = ChartData.generate(101, (int i) => (100.0 + i, i.toDouble()));
    int calls = 0;
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: const LinearScale(range: FixedRange(110, 160)),
          y: _y,
          children: <Widget>[
            LineSeries(data: data),
            ChartLoader(
              data: data,
              onLoadBefore: () async {
                calls++;
                return true;
              },
              onLoadAfter: () {
                throw StateError('not even a future');
              },
            ),
          ],
        ),
      ),
    );
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(calls, 1);
    expect(tester.takeException(), isNull, reason: 'the newer side is not near');
    c.x.jumpTo(108, 158);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(calls, 2);

    // A callback that throws instead of returning a future is a failed load.
    c.x.jumpTo(170, 220);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isStateError);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'reported once');
  });

  testWidgets('the loader follows a change of its scale', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = ChartData.generate(101, (int i) => (100.0 + i, i.toDouble()));
    int calls = 0;
    Widget chart(Object xScale) => host(
      Chart(
        controller: c,
        x: const LinearScale(range: FixedRange(140, 160)),
        xScales: const <Object, ChartScale>{'history': LinearScale(range: FixedRange(100, 120))},
        y: _y,
        children: <Widget>[
          LineSeries(data: data),
          ChartLoader(
            data: data,
            xScale: xScale,
            onLoadBefore: () async {
              calls++;
              return false;
            },
          ),
        ],
      ),
    );
    await tester.pumpWidget(chart(kChartX));
    await tester.pump();
    expect(calls, 0, reason: 'the default scale shows the middle of the data');
    await tester.pumpWidget(chart('history'));
    await tester.pump();
    await tester.pump();
    expect(calls, 1, reason: 'this scale shows the first loaded value');
  });

  testWidgets('with reduced motion, animated data is in place on the first frame', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = ChartData.fromValues(<double>[10, 20, 30]);
    Widget chart({required bool reduceMotion}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: host(
        Chart(
          controller: c,
          children: <Widget>[
            AnimatedChartData(
              data: data,
              duration: const Duration(milliseconds: 200),
              curve: Curves.linear,
              builder: (BuildContext context, ChartData animated) =>
                  BarSeries(data: animated, id: 'bars'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(chart(reduceMotion: true));
    expect(c.seriesById('bars')!.valueAt(2), 30);
    expect(tester.hasRunningAnimations, isFalse);
    // Taking down a chart that never animated is fine as well.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(chart(reduceMotion: true));
    data.setValue(2, 40);
    await tester.pump();
    expect(c.seriesById('bars')!.valueAt(2), 40, reason: 'changes are not animated either');
    data.setValue(2, 30);

    // Otherwise the first data set grows in from the baseline.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(chart(reduceMotion: false));
    expect(c.seriesById('bars')!.valueAt(2), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.seriesById('bars')!.valueAt(2), moreOrLessEquals(15, epsilon: 1e-6));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.seriesById('bars')!.valueAt(2), 30);
  });
}

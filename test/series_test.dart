import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

const ChartScale _x = LinearScale(range: FixedRange(0, 10));
const ChartScale _y = LinearScale(range: FixedRange(0, 100));
const Color _black = Color(0xFF000000);

/// The first painter of type [T] in the pumped chart.
T _painter<T extends ChartPainter>(WidgetTester tester) => tester
    .widgetList<ChartPaint>(find.byType(ChartPaint))
    .map((ChartPaint paint) => paint.painter)
    .whereType<T>()
    .first;

/// The calls [painter] makes on a canvas for [view].
List<RecordedInvocation> _calls(ChartPainter painter, ChartView view) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  painter.paint(ChartPaintContext(canvas: canvas, view: view));
  return canvas.invocations;
}

/// The paths [painter] draws for [view].
List<ui.Path> _paths(ChartPainter painter, ChartView view) => <ui.Path>[
  for (final RecordedInvocation call in _calls(painter, view))
    if (call.invocation.memberName == #drawPath)
      call.invocation.positionalArguments.first as ui.Path,
];

/// One series of each built-in kind, with the number of value columns it reads.
final Map<String, (int, Widget Function(ChartData))> _kinds =
    <String, (int, Widget Function(ChartData))>{
      'line': (1, (ChartData data) => LineSeries(data: data)),
      'bar': (1, (ChartData data) => BarSeries(data: data)),
      'scatter': (1, (ChartData data) => ScatterSeries(data: data)),
      'candlestick': (4, (ChartData data) => CandlestickSeries(data: data)),
    };

/// A chart with automatic ranges, axes and the hover behaviors around [series].
Widget _full(ChartController controller, Widget series) => host(
  Chart(
    controller: controller,
    left: const <Widget>[ChartAxis()],
    bottom: const <Widget>[ChartAxis()],
    children: <Widget>[const ChartGrid(), series, const ChartCrosshair(), const ChartTooltip()],
  ),
);

void main() {
  group('little or no data', () {
    for (final MapEntry<String, (int, Widget Function(ChartData))> kind in _kinds.entries) {
      final (int columns, Widget Function(ChartData) build) = kind.value;

      testWidgets('an empty ${kind.key} series draws nothing and keeps the fallback ranges', (
        WidgetTester tester,
      ) async {
        final ChartController c = ChartController();
        addTearDown(c.dispose);
        final ChartData data = ChartData(valueColumns: columns);
        await tester.pumpWidget(_full(c, build(data)));
        expect(tester.takeException(), isNull);
        expect(c.x.range, const ChartRange(0, 1));
        expect(c.y.range, const ChartRange(0, 1));
        expect(c.hitTest(const Offset(100, 100)), isEmpty);
        expect(_calls(_painter<ChartSeriesPainter>(tester), c.view!), isEmpty);

        final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(mouse.hover(const Offset(200, 100)));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('a ${kind.key} series of one row gets a range around it and one hit', (
        WidgetTester tester,
      ) async {
        final ChartController c = ChartController();
        addTearDown(c.dispose);
        // One row at x = 5: a value of 8, or a candle that opens at 7, reaches
        // 9, falls to 6 and closes at 8.
        final ChartData data = ChartData(valueColumns: columns)
          ..addRow(5, columns == 1 ? <double>[8] : <double>[7, 9, 6, 8]);
        await tester.pumpWidget(_full(c, build(data)));
        expect(tester.takeException(), isNull);
        expect(c.x.range.span, greaterThan(0));
        expect(c.x.range.contains(5), isTrue);
        expect(c.y.range.span, greaterThan(0));
        expect(c.y.range.contains(8), isTrue);

        final ChartView view = c.view!;
        final List<ChartHit> hits = c.hitTest(view.toPixel(5, 8));
        expect(hits.single.index, 0);
        expect(hits.single.x, 5);
        expect(_calls(_painter<ChartSeriesPainter>(tester), view), isNotEmpty);

        final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(mouse.hover(view.toPixel(5, 8) + const Offset(60, 10)));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('BarSeries', () {
    testWidgets('floating bars span from the base column to the value', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData data = ChartData(valueColumns: 2)
        ..addRows(
          <double>[1, 2, 3],
          <List<double>>[
            <double>[30, 60, 90],
            <double>[10, 40, 20],
          ],
        );
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            children: <Widget>[BarSeries(data: data, baseColumn: 1, step: 1, width: 0.5)],
          ),
        ),
      );
      final ChartView view = c.view!;
      final ChartHit hit = c.hitTest(view.toPixel(2, 50)).single;
      expect(hit.y, 60);
      expect(
        hit.rect,
        rectMoreOrLessEquals(
          Rect.fromLTRB(
            view.x.toPixel(1.75),
            view.y.toPixel(60),
            view.x.toPixel(2.25),
            view.y.toPixel(40),
          ),
          epsilon: 1e-6,
        ),
      );
      final BarSeriesPainter painter = _painter<BarSeriesPainter>(tester);
      final ui.Path path = _paths(painter, view).single;
      expect(path.contains(view.toPixel(2, 50)), isTrue);
      expect(path.contains(view.toPixel(2, 30)), isFalse, reason: 'below the base');
      expect(path.contains(view.toPixel(2, 70)), isFalse, reason: 'above the value');
      // Both columns count towards the range.
      expect(painter.bounds()!.y, const ChartRange(10, 90));
    });

    testWidgets('series side by side share a step and differ by an offset', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData a = ChartData.fromXY(<double>[1, 2, 3], <double>[10, 20, 30]);
      final ChartData b = ChartData.fromXY(<double>[1, 2, 3], <double>[30, 20, 10]);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            y: _y,
            children: <Widget>[
              BarSeries(data: a, label: 'a', step: 1, width: 0.4, offset: -0.2),
              BarSeries(data: b, label: 'b', step: 1, width: 0.4, offset: 0.2),
            ],
          ),
        ),
      );
      // The x range reaches the outer edges of the outer bars.
      expect(c.x.min, moreOrLessEquals(0.6));
      expect(c.x.max, moreOrLessEquals(3.4));
      final ChartView view = c.view!;
      final List<ChartHit> hits = c.hitTest(view.toPixel(1.8, 5));
      expect(hits.map((ChartHit h) => h.series?.label), <String?>['a', 'b']);
      expect(hits.map((ChartHit h) => h.index), <int?>[1, 1]);
      expect(hits[0].distance, 0);
      expect(hits[0].rect!.right, moreOrLessEquals(hits[1].rect!.left, epsilon: 1e-6));
    });

    testWidgets('colorOf paints one path per colour', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData data = ChartData.fromXY(<double>[1, 2, 3, 4], <double>[10, 80, 20, 90]);
      Widget chart(ChartBarColor? colorOf) => host(
        Chart(
          controller: c,
          x: _x,
          y: _y,
          children: <Widget>[BarSeries(data: data, color: _black, colorOf: colorOf)],
        ),
      );
      await tester.pumpWidget(chart(null));
      expect(_paths(_painter<BarSeriesPainter>(tester), c.view!), hasLength(1));

      final List<int> asked = <int>[];
      await tester.pumpWidget(
        chart((int index, double x, double y) {
          asked.add(index);
          return y > 50 ? const Color(0xFFCC0000) : null;
        }),
      );
      asked.clear();
      expect(_paths(_painter<BarSeriesPainter>(tester), c.view!), hasLength(2));
      expect(asked, <int>[0, 1, 2, 3]);
    });

    testWidgets('corners are rounded on the end away from the base', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData data = ChartData.fromXY(<double>[1, 2], <double>[50, -50]);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: const LinearScale(range: FixedRange(0, 3)),
            y: const LinearScale(range: FixedRange(-100, 100)),
            children: <Widget>[BarSeries(data: data, step: 1, width: 0.5, radius: 8)],
          ),
        ),
      );
      final ChartView view = c.view!;
      final ui.Path path = _paths(_painter<BarSeriesPainter>(tester), view).single;
      final double zero = view.y.toPixel(0);
      // Half a pixel inside each corner of the bar's rectangle.
      final double upLeft = view.x.toPixel(0.75) + 0.5;
      expect(path.contains(Offset(upLeft, view.y.toPixel(50) + 0.5)), isFalse, reason: 'rounded');
      expect(path.contains(Offset(upLeft, zero - 0.5)), isTrue, reason: 'square at the base');
      final double downLeft = view.x.toPixel(1.75) + 0.5;
      expect(path.contains(Offset(downLeft, view.y.toPixel(-50) - 0.5)), isFalse);
      expect(path.contains(Offset(downLeft, zero + 0.5)), isTrue);
    });

    testWidgets('more bars than pixels are drawn as one column per pixel', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData data = ChartData.generate(
        5000,
        (int i) => (i.toDouble(), 10 + (i * 37 % 80).toDouble()),
      );
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: const LinearScale(range: FixedRange(0, 5000)),
            y: _y,
            children: <Widget>[BarSeries(data: data)],
          ),
        ),
      );
      final ChartView view = c.view!;
      final ui.Path path = _paths(_painter<BarSeriesPainter>(tester), view).single;
      expect(path.computeMetrics().length, inInclusiveRange(360, 400));
      // Every column reaches the highest bar among its rows, here at least 80.
      expect(path.getBounds().top, lessThanOrEqualTo(view.y.toPixel(80)));
      expect(path.getBounds().bottom, view.y.toPixel(0));
    });

    testWidgets('valueAt answers inside a bar only', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData data = ChartData.fromXY(<double>[1, 2, 3], <double>[10, double.nan, 30]);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            children: <Widget>[BarSeries(data: data, step: 1, width: 0.5)],
          ),
        ),
      );
      final ChartSeries series = c.series.single;
      expect(series.valueAt(1.2), 10);
      expect(series.valueAt(1.4), isNull, reason: 'between two bars');
      expect(series.valueAt(2), isNull, reason: 'a gap');
      expect(series.valueAt(3.25), 30);
    });

    testWidgets('a fit-visible y scale follows the bars in the x window', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData data = ChartData.fromValues(<double>[1, 2, 50, 3, 4, 5, 6]);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            y: const LinearScale(range: FitVisibleRange(padding: 0)),
            children: <Widget>[BarSeries(data: data)],
          ),
        ),
      );
      expect(c.y.range, const ChartRange(0, 50));
      // Rows 4 to 6 only; the baseline stays in view.
      c.x.jumpTo(3.6, 6.4);
      await tester.pump();
      expect(c.y.range, const ChartRange(0, 6));
    });
  });

  group('ScatterSeries', () {
    test('with unsorted points, each window restricts the other dimension', () {
      final ChartData data = ChartData.fromXY(<double>[5, 1, 9, 3], <double>[10, 40, 20, 30]);
      addTearDown(data.dispose);
      expect(data.isSorted, isFalse);
      final ScatterSeriesPainter painter = ScatterSeriesPainter(data: data, color: _black);
      expect(painter.bounds(), const ChartDataBounds(x: ChartRange(1, 9), y: ChartRange(10, 40)));
      // Rows with x in 0..4 have the values 40 and 30.
      expect(
        painter.bounds(xWindow: const ChartRange(0, 4)),
        const ChartDataBounds(x: ChartRange(1, 9), y: ChartRange(30, 40)),
      );
      // Rows with a value in 0..25 sit at x = 5 and x = 9.
      expect(
        painter.bounds(yWindow: const ChartRange(0, 25)),
        const ChartDataBounds(x: ChartRange(5, 9), y: ChartRange(10, 40)),
      );
    });

    testWidgets('a size column gives each dot its own radius', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData data = ChartData(valueColumns: 2)
        ..addRows(
          <double>[2, 8],
          <List<double>>[
            <double>[20, 80],
            <double>[2, 6],
          ],
        );
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            children: <Widget>[ScatterSeries(data: data, sizeColumn: 1)],
          ),
        ),
      );
      final ChartView view = c.view!;
      final List<RecordedInvocation> calls = _calls(_painter<ScatterSeriesPainter>(tester), view);
      expect(calls.map((RecordedInvocation call) => call.invocation.memberName), <Symbol>[
        #drawCircle,
        #drawCircle,
      ]);
      expect(
        calls.map((RecordedInvocation call) => call.invocation.positionalArguments[1]),
        <double>[2, 6],
      );
      expect(calls.first.invocation.positionalArguments[0], view.toPixel(2, 20));
    });

    testWidgets('nearest ranks by distance on screen, nearestX by x alone', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData data = ChartData.fromXY(<double>[4, 5], <double>[10, 90]);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: _x,
            y: _y,
            children: <Widget>[ScatterSeries(data: data)],
          ),
        ),
      );
      final ChartView view = c.view!;
      // Closer to x = 4 along x, but right next to the point at (5, 90).
      final Offset pointer = view.toPixel(4.4, 88);
      expect(c.hitTest(pointer).single.index, 0);
      final ChartHit near = c.hitTest(pointer, mode: ChartHitMode.nearest).single;
      expect(near.index, 1);
      expect(near.position, view.toPixel(5, 90));
      expect(near.distance, moreOrLessEquals((view.toPixel(5, 90) - pointer).distance));

      // Nothing within reach.
      expect(c.hitTest(pointer, mode: ChartHitMode.nearest, maxDistance: 5), isEmpty);
      expect(c.hitTest(pointer, mode: ChartHitMode.nearest, maxDistance: 30), hasLength(1));
    });
  });
}

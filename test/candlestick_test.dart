import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

const Color _up = Color(0xFF00AA00);
const Color _down = Color(0xFFCC0000);
const int _white = 0xFFFFFFFF;

/// A store with one `(open, high, low, close)` row per x value.
ChartData _candles(List<double> xs, List<(double, double, double, double)> rows) =>
    ChartData(valueColumns: 4)..addRows(xs, <List<double>>[
      <double>[for (final (double open, _, _, _) in rows) open],
      <double>[for (final (_, double high, _, _) in rows) high],
      <double>[for (final (_, _, double low, _) in rows) low],
      <double>[for (final (_, _, _, double close) in rows) close],
    ]);

ChartData _fourDays() => _candles(
  <double>[0, 1, 2, 3],
  <(double, double, double, double)>[
    (10, 14, 8, 12),
    (12, 13, 9, 10),
    (10, 18, 10, 17),
    (17, 17.5, 15, 15),
  ],
);

/// A random walk of [count] candles, one per x unit.
ChartData _walk(int count, {int seed = 5}) {
  final math.Random random = math.Random(seed);
  final List<double> xs = List<double>.generate(count, (int i) => i.toDouble());
  final List<List<double>> columns = List<List<double>>.generate(
    4,
    (_) => List<double>.filled(count, 0),
  );
  double price = 100;
  for (int i = 0; i < count; i++) {
    final double open = price;
    price += (random.nextDouble() - 0.5) * 2;
    columns[0][i] = open;
    columns[1][i] = math.max(open, price) + random.nextDouble();
    columns[2][i] = math.min(open, price) - random.nextDouble();
    columns[3][i] = price;
  }
  return ChartData(valueColumns: 4, capacity: count)..addRows(xs, columns);
}

/// Days as x values, where days 5 and 6 of every week take no room.
class _WeekdayScale extends ChartScale {
  const _WeekdayScale({super.range});

  @override
  double transform(double value) {
    final double weeks = (value / 7).floorToDouble();
    return weeks * 5 + (value - weeks * 7).clamp(0, 5);
  }

  @override
  double invert(double scaled) {
    final double weeks = (scaled / 5).floorToDouble();
    return weeks * 7 + (scaled - weeks * 5);
  }

  @override
  ChartTicks get defaultTicks => const LinearTicks();
}

/// Renders [chart] on white, 400x300, and returns a reader of its pixels as
/// `0xAARRGGBB`.
Future<int Function(int x, int y)> _render(WidgetTester tester, Widget chart) async {
  const Key key = Key('shot');
  await tester.pumpWidget(
    host(
      RepaintBoundary(
        key: key,
        child: ColoredBox(color: const Color(_white), child: chart),
      ),
    ),
  );
  final RenderRepaintBoundary boundary = tester.renderObject(find.byKey(key));
  late Uint8List bytes;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    bytes = (await image.toByteData())!.buffer.asUint8List();
    image.dispose();
  });
  return (int x, int y) {
    final int i = (y * 400 + x) * 4;
    return bytes[i + 3] << 24 | bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2];
  };
}

/// The number of boxes in the paths [painter] draws for [view].
int _boxes(CandlestickSeriesPainter painter, ChartView view) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  painter.paint(ChartPaintContext(canvas: canvas, view: view));
  int boxes = 0;
  for (final RecordedInvocation call in canvas.invocations) {
    expect(call.invocation.memberName, #drawPath);
    boxes += (call.invocation.positionalArguments.first as ui.Path).computeMetrics().length;
  }
  return boxes;
}

void main() {
  testWidgets('both scales fit the candles, and the series is listed for a legend', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          children: <Widget>[CandlestickSeries(data: _fourDays(), id: 'acme', label: 'ACME')],
        ),
      ),
    );
    // Half a body (0.7 of a step) beyond the first and last candle.
    expect(c.x.range, const ChartRange(-0.35, 3.35));
    // From the lowest low to the highest high.
    expect(c.y.range, const ChartRange(8, 18));
    final ChartSeries series = c.seriesById('acme')!;
    expect((series.label, series.color), ('ACME', const Color(0xFF59A14F)));
    // The close of the candle whose step holds x.
    expect(series.valueAt(1.4), 10);
    expect(series.valueAt(1.6), 17);
    expect(series.valueAt(3.6), isNull);
  });

  testWidgets('Y fits the candles visible in the X window', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          y: const LinearScale(range: FitVisibleRange(padding: 0)),
          children: <Widget>[CandlestickSeries(data: _fourDays())],
        ),
      ),
    );
    expect(c.y.range, const ChartRange(8, 18));

    c.x.jumpTo(-0.5, 1.5);
    await tester.pump();
    expect(c.y.range, const ChartRange(8, 14));

    // A candle counts as soon as its body reaches into the window.
    c.x.jumpTo(2.7, 3.5);
    await tester.pump();
    expect(c.y.range, const ChartRange(15, 17.5));
    c.x.jumpTo(2.3, 3.5);
    await tester.pump();
    expect(c.y.range, const ChartRange(10, 18));
  });

  testWidgets('a hit carries the close, the four prices and the box of the candle', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: const LinearScale(range: FixedRange(0, 4)),
          y: const LinearScale(range: FixedRange(0, 30)),
          children: <Widget>[
            CandlestickSeries(data: _fourDays(), label: 'ACME'),
            const ChartCrosshair(),
            const ChartTooltip(),
          ],
        ),
      ),
    );
    // 100 px per x unit and 10 px per y unit.
    final ChartHit hit = c.hitsAt(1.2).single;
    expect((hit.index, hit.x, hit.y), (1, 1, 10));
    expect(hit.datum, const ChartCandle(open: 12, high: 13, low: 9, close: 10));
    expect((hit.datum! as ChartCandle).isUp, isFalse);
    // As wide as the body, from the high (y = 13) down to the low (y = 9).
    expect(hit.rect!.left, moreOrLessEquals(65));
    expect(hit.rect!.right, moreOrLessEquals(135));
    expect((hit.rect!.top, hit.rect!.bottom), (170, 210));
    // Anchored on top of the wick, so a tooltip clears the candle.
    expect(hit.position, hit.rect!.topCenter);

    // By distance: inside the box is a hit, far above it is not.
    List<ChartHit> near(Offset position) =>
        c.hitTest(position, mode: ChartHitMode.nearest, maxDistance: 8);
    expect(near(const Offset(70, 200)).single.distance, 0);
    expect(near(const Offset(60, 164)).single.distance, moreOrLessEquals(math.sqrt(61)));
    expect(near(const Offset(100, 100)), isEmpty);

    // The crosshair snaps to the candle and marks it with its rule only: a
    // candle is its own highlight, as a bar is.
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(212, 100)));
    await tester.pump();
    expect(c.focus.value?.x, 2);
    final RenderObject crosshair = tester.renderObject(
      find.descendant(of: find.byType(ChartCrosshair), matching: find.byType(ChartPaint)),
    );
    expect(crosshair, paints..line());
    expect(crosshair, isNot(paints..circle()));
    // The default tooltip shows the close.
    expect(find.text('ACME: '), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rising and falling candles are drawn in their colours, with wick and body', (
    WidgetTester tester,
  ) async {
    final ChartData data = _candles(
      <double>[2, 5, 8],
      <(double, double, double, double)>[
        (20, 60, 10, 40), // rising
        (70, 80, 30, 50), // falling
        (50, 55, 45, 50), // open == close
      ],
    );
    // 40 px per x unit, 3 px per y unit; a body is 28 px wide.
    final int Function(int x, int y) pixel = await _render(
      tester,
      Chart(
        x: const LinearScale(range: FixedRange(0, 10)),
        y: const LinearScale(range: FixedRange(0, 100)),
        children: <Widget>[
          CandlestickSeries(
            data: data,
            step: 1,
            wickWidth: 2,
            upColor: _up,
            downColor: _down,
            isolate: false,
          ),
        ],
      ),
    );
    // Rising, centred on x = 80: body from the open (y = 240) up to the close
    // (y = 180), wick from the low (y = 270) to the high (y = 120).
    expect(pixel(80, 210), _up.toARGB32());
    expect(pixel(67, 239), _up.toARGB32());
    expect(pixel(93, 181), _up.toARGB32());
    expect(pixel(80, 121), _up.toARGB32());
    expect(pixel(80, 269), _up.toARGB32());
    expect(pixel(70, 150), _white, reason: 'beside the upper wick');
    expect(pixel(70, 260), _white, reason: 'beside the lower wick');
    expect(pixel(80, 118), _white, reason: 'above the high');
    expect(pixel(80, 272), _white, reason: 'below the low');
    expect(pixel(64, 210), _white, reason: 'left of the body');
    expect(pixel(96, 210), _white, reason: 'right of the body');

    // Falling, centred on x = 200: body from the open (y = 90) down to the
    // close (y = 150), wick from the high (y = 60) to the low (y = 210).
    expect(pixel(200, 120), _down.toARGB32());
    expect(pixel(190, 91), _down.toARGB32());
    expect(pixel(200, 61), _down.toARGB32());
    expect(pixel(200, 209), _down.toARGB32());
    expect(pixel(190, 180), _white);

    // Open equals close, centred on x = 320: the body is a hairline at
    // y = 150, in the rising colour.
    expect(pixel(320, 140), _up.toARGB32());
    expect(pixel(310, 150), isNot(_white));
    expect(pixel(310, 147), _white);
    expect(pixel(310, 153), _white);
  });

  group('styles', () {
    // The candles of the test above: 40 px per x unit, 3 px per y unit, a
    // body 28 px wide and lines 2 px thick.
    ChartData threeCandles() => _candles(
      <double>[2, 5, 8],
      <(double, double, double, double)>[
        (20, 60, 10, 40), // rising
        (70, 80, 30, 50), // falling
        (50, 55, 45, 50), // open == close
      ],
    );
    Widget chart(CandleStyle style, {double wickWidth = 2, double widthFactor = 0.7}) => Chart(
      x: const LinearScale(range: FixedRange(0, 10)),
      y: const LinearScale(range: FixedRange(0, 100)),
      children: <Widget>[
        CandlestickSeries(
          data: threeCandles(),
          style: style,
          step: 1,
          widthFactor: widthFactor,
          wickWidth: wickWidth,
          upColor: _up,
          downColor: _down,
          isolate: false,
        ),
      ],
    );

    testWidgets('hollow: a rising candle is an outline, a falling one is filled', (
      WidgetTester tester,
    ) async {
      final int Function(int x, int y) pixel = await _render(tester, chart(CandleStyle.hollow));
      // Rising, centred on x = 80: the body spans x 66 to 94 and y 180 to 240.
      expect(pixel(80, 210), _white, reason: 'inside the body');
      expect(pixel(72, 190), _white, reason: 'inside the body');
      expect(pixel(67, 210), _up.toARGB32(), reason: 'left edge');
      expect(pixel(93, 210), _up.toARGB32(), reason: 'right edge');
      expect(pixel(80, 181), _up.toARGB32(), reason: 'top edge');
      expect(pixel(80, 239), _up.toARGB32(), reason: 'bottom edge');
      expect(pixel(80, 150), _up.toARGB32(), reason: 'upper wick');
      expect(pixel(80, 255), _up.toARGB32(), reason: 'lower wick');
      expect(pixel(70, 150), _white, reason: 'beside the upper wick');
      expect(pixel(64, 210), _white, reason: 'left of the body');

      // Falling, centred on x = 200: filled from y = 90 to y = 150.
      expect(pixel(200, 120), _down.toARGB32());
      expect(pixel(190, 91), _down.toARGB32());
      expect(pixel(200, 61), _down.toARGB32());
      expect(pixel(200, 209), _down.toARGB32());

      // Open equals close: still a hairline.
      expect(pixel(310, 150), isNot(_white));
      expect(pixel(310, 147), _white);
    });

    testWidgets('hollow: a body too small for an outline is filled', (WidgetTester tester) async {
      // A body 4 px wide has no room between two 2 px edges.
      final int Function(int x, int y) pixel = await _render(
        tester,
        chart(CandleStyle.hollow, widthFactor: 0.1),
      );
      expect(pixel(80, 210), _up.toARGB32());
      expect(pixel(79, 200), _up.toARGB32());
    });

    testWidgets('ohlc: a stem from low to high, the open to its left, the close to its right', (
      WidgetTester tester,
    ) async {
      final int Function(int x, int y) pixel = await _render(tester, chart(CandleStyle.ohlc));
      // Rising, centred on x = 80: low 270, open 240, close 180, high 120.
      expect(pixel(80, 125), _up.toARGB32(), reason: 'stem near the high');
      expect(pixel(80, 210), _up.toARGB32(), reason: 'stem');
      expect(pixel(80, 265), _up.toARGB32(), reason: 'stem near the low');
      expect(pixel(72, 240), _up.toARGB32(), reason: 'open tick');
      expect(pixel(88, 240), _white, reason: 'no tick right of the stem at the open');
      expect(pixel(88, 180), _up.toARGB32(), reason: 'close tick');
      expect(pixel(72, 180), _white, reason: 'no tick left of the stem at the close');
      expect(pixel(72, 210), _white, reason: 'no body');
      expect(pixel(88, 210), _white, reason: 'no body');
      expect(pixel(96, 180), _white, reason: 'the tick is as long as half a body');

      // Falling, centred on x = 200: open 90, close 150.
      expect(pixel(192, 90), _down.toARGB32());
      expect(pixel(208, 150), _down.toARGB32());
      expect(pixel(208, 90), _white);
      expect(pixel(200, 120), _down.toARGB32());

      // Open equals close, centred on x = 320: both ticks at y = 150.
      expect(pixel(312, 150), _up.toARGB32());
      expect(pixel(328, 150), _up.toARGB32());
    });

    testWidgets('every style is drawn with two calls', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      for (final CandleStyle style in CandleStyle.values) {
        await tester.pumpWidget(
          host(
            Chart(
              controller: c,
              children: <Widget>[CandlestickSeries(data: _walk(60), style: style)],
            ),
          ),
        );
        final TestRecordingCanvas canvas = TestRecordingCanvas();
        tester
            .widget<ChartPaint>(find.byType(ChartPaint))
            .painter
            .paint(ChartPaintContext(canvas: canvas, view: c.view!));
        expect(canvas.invocations.map((RecordedInvocation i) => i.invocation.memberName), <Symbol>[
          #drawPath,
          #drawPath,
        ], reason: style.name);
      }
    });

    test('a change of style repaints, and does not change the ranges', () {
      final ChartData data = _fourDays();
      CandlestickSeriesPainter painter(CandleStyle style) =>
          CandlestickSeriesPainter(data: data, upColor: _up, downColor: _down, style: style);
      expect(painter(CandleStyle.filled).style, CandleStyle.filled);
      expect(painter(CandleStyle.hollow).shouldRepaint(painter(CandleStyle.filled)), isTrue);
      expect(painter(CandleStyle.hollow).shouldRescale(painter(CandleStyle.filled)), isFalse);
      expect(painter(CandleStyle.ohlc).shouldRepaint(painter(CandleStyle.ohlc)), isFalse);
      expect(CandlestickSeries(data: data).style, CandleStyle.filled);
    });
  });

  testWidgets('the step is the smallest gap, so a weekend does not widen the candles', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    // Days: Friday, then Monday to Thursday.
    final ChartData data = _candles(<double>[
      4,
      7,
      8,
      9,
      10,
    ], List<(double, double, double, double)>.filled(5, (10, 12, 9, 11)));
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: const LinearScale(range: FixedRange(0, 20)),
          children: <Widget>[CandlestickSeries(data: data)],
        ),
      ),
    );
    final ChartSeries series = c.series.single;
    expect(series.bounds()!.x, const ChartRange(3.65, 10.35));
    // 20 px per day: a body is 0.7 of a day wide.
    expect(c.hitsAt(4).single.rect!.width, moreOrLessEquals(14));
    // Saturday belongs to no candle.
    expect(series.valueAt(5), isNull);
  });

  testWidgets('on a scale that skips the weekend every candle keeps its width', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    // Two weeks, Monday to Friday.
    final List<double> days = <double>[0, 1, 2, 3, 4, 7, 8, 9, 10, 11];
    final ChartData data = _candles(
      days,
      List<(double, double, double, double)>.filled(days.length, (10, 12, 9, 11)),
    );
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          // Half a trading day of room on each side: 40 px per trading day.
          x: const _WeekdayScale(range: FixedRange(-2.5, 11.5)),
          children: <Widget>[CandlestickSeries(data: data)],
        ),
      ),
    );
    final ChartScaleView x = c.view!.x;
    // Friday and the Monday after it are neighbours.
    expect(x.toPixel(7) - x.toPixel(4), moreOrLessEquals(40));
    for (final double day in days) {
      final Rect box = c.hitsAt(day).single.rect!;
      // The Monday candle is not squeezed by the weekend to its left.
      expect(box.width, moreOrLessEquals(28), reason: 'day $day');
      expect(box.center.dx, moreOrLessEquals(x.toPixel(day)), reason: 'day $day');
    }
    final CandlestickSeriesPainter painter =
        tester.widget<ChartPaint>(find.byType(ChartPaint)).painter as CandlestickSeriesPainter;
    expect(_boxes(painter, c.view!), 2 * days.length);
  });

  testWidgets('more candles than pixels: one box per pixel column that keeps every extreme', (
    WidgetTester tester,
  ) async {
    const int width = 400;
    const int height = 300;
    final ChartData data = _walk(100000);
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final int Function(int x, int y) pixel = await _render(
      tester,
      Chart(
        controller: c,
        children: <Widget>[
          CandlestickSeries(data: data, upColor: _up, downColor: _down, isolate: false),
        ],
      ),
    );
    final ChartView view = c.view!;
    final CandlestickSeriesPainter painter =
        tester.widget<ChartPaint>(find.byType(ChartPaint)).painter as CandlestickSeriesPainter;
    expect(_boxes(painter, view), width);

    // Ground truth: per pixel column, the highest high, the lowest low, the
    // first open and the last close of the rows in it.
    final List<double> top = List<double>.filled(width, double.infinity);
    final List<double> bottom = List<double>.filled(width, double.negativeInfinity);
    final List<int> first = List<int>.filled(width, -1);
    final List<int> last = List<int>.filled(width, -1);
    for (int i = 0; i < data.length; i++) {
      final int column = view.x.toPixel(data.x(i)).floor();
      top[column] = math.min(top[column], view.y.toPixel(data.value(i, 1)));
      bottom[column] = math.max(bottom[column], view.y.toPixel(data.value(i, 2)));
      if (first[column] < 0) first[column] = i;
      last[column] = i;
    }
    for (int x = 0; x < width; x++) {
      int inkTop = -1;
      int inkBottom = -1;
      for (int y = 0; y < height; y++) {
        if (pixel(x, y) != _white) {
          if (inkTop < 0) inkTop = y;
          inkBottom = y;
        }
      }
      // To the pixel: an edge that covers a sliver of a pixel may not ink it.
      expect(inkTop, closeTo(top[x], 1), reason: 'the high of column $x');
      expect(inkBottom + 1, closeTo(bottom[x], 1), reason: 'the low of column $x');
      final bool up = data.value(last[x], 3) >= data.value(first[x], 0);
      expect(
        pixel(x, (inkTop + inkBottom) ~/ 2),
        (up ? _up : _down).toARGB32(),
        reason: 'the direction of column $x',
      );
    }

    // Zoomed in until candles are wider than a pixel, each is drawn by itself.
    c.x.jumpTo(1000, 1200);
    await tester.pump();
    expect(_boxes(painter, c.view!), 2 * 201);
    c.x.jumpTo(1000, 1020);
    await tester.pump();
    expect(_boxes(painter, c.view!), 2 * 21);
  });

  testWidgets('a forming candle repaints and re-fits; a missing price is a gap', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = _fourDays();
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          children: <Widget>[CandlestickSeries(data: data)],
        ),
      ),
    );
    final RenderObject paint = tester.renderObject(find.byType(ChartPaint));
    expect(paint.debugNeedsPaint, isFalse);

    // The last candle trades up to 21.
    data.setValue(3, 21, column: 1);
    data.setValue(3, 21, column: 3);
    expect(paint.debugNeedsPaint, isTrue);
    await tester.pump();
    expect(c.y.range, const ChartRange(8, 21));
    expect(c.hitsAt(3).single.datum, const ChartCandle(open: 17, high: 21, low: 15, close: 21));

    // The next candle opens.
    data.addRow(4, <double>[21, 22, 20, 20.5]);
    await tester.pump();
    expect(c.x.range, const ChartRange(-0.35, 4.35));
    expect(c.series.single.valueAt(4), 20.5);

    // A row with a missing price is not drawn, hit or measured.
    data.setValue(2, double.nan, column: 1);
    await tester.pump();
    expect(c.hitsAt(2), isEmpty);
    expect(c.series.single.valueAt(2), 17);
    expect(tester.takeException(), isNull);
  });

  test('the data needs a column each for open, high, low and close', () {
    expect(
      () => CandlestickSeriesPainter(
        data: ChartData(valueColumns: 2),
        upColor: _up,
        downColor: _down,
      ),
      throwsAssertionError,
    );
    // Any four columns will do.
    final CandlestickSeriesPainter painter = CandlestickSeriesPainter(
      data: ChartData(valueColumns: 5)..addRow(0, <double>[99, 12, 9, 13, 10]),
      openColumn: 4,
      highColumn: 3,
      lowColumn: 2,
      closeColumn: 1,
      upColor: _up,
      downColor: _down,
    );
    expect(painter.candleAt(0), const ChartCandle(open: 10, high: 13, low: 9, close: 12));
    expect(painter.bounds()!.y, const ChartRange(9, 13));
  });
}

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// In the 400 x 300 host: a value of 1 is 4 px along x, and a row is 30 px
// along y, with row 0 at the bottom.
const ChartScale _values = LinearScale(range: FixedRange(0, 100));
const ChartScale _rows = LinearScale(range: FixedRange(0, 10));
const int _white = 0xFFFFFFFF;
const Color _red = Color(0xFFFF0000);
const Color _green = Color(0xFF00FF00);

/// Rows 2, 5 and 8 (at y = 240, 150 and 60 px) with the values 50, 25 and 75.
ChartData _three() => ChartData.fromXY(<double>[2, 5, 8], <double>[50, 25, 75]);

BarSeries _bars(
  ChartData data, {
  Color color = _red,
  double cornerRadius = 0,
  int? baseColumn,
  double offset = 0,
  String? label,
}) => BarSeries(
  data: data,
  direction: Axis.horizontal,
  step: 1,
  widthFactor: 0.5,
  color: color,
  cornerRadius: cornerRadius,
  baseColumn: baseColumn,
  offset: offset,
  label: label,
  isolate: false,
);

void main() {
  testWidgets('bars grow along x from the baseline, one row per x value of the data', (
    WidgetTester tester,
  ) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(x: _values, y: _rows, children: <Widget>[_bars(_three())]),
    );
    // Row 5: 15 px thick around y = 150, from x = 0 to the value 25 (100 px).
    expect(pixel(50, 150), _red.toARGB32());
    expect(pixel(2, 144), _red.toARGB32());
    expect(pixel(97, 156), _red.toARGB32());
    expect(pixel(104, 150), _white, reason: 'beyond the value');
    expect(pixel(50, 140), _white, reason: 'above the bar');
    expect(pixel(50, 160), _white, reason: 'below the bar');
    // Row 2 reaches 200 px, row 8 reaches 300 px.
    expect(pixel(196, 240), _red.toARGB32());
    expect(pixel(204, 240), _white);
    expect(pixel(296, 60), _red.toARGB32());
    expect(pixel(304, 60), _white);
  });

  testWidgets('automatic ranges: values along x, rows along y', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: const LinearScale(range: FitDataRange()),
          y: const LinearScale(range: FitDataRange()),
          children: <Widget>[_bars(_three())],
        ),
      ),
    );
    // The baseline 0 to the largest value; the rows with half a bar around.
    expect(c.x.range, const ChartRange(0, 75));
    expect(c.y.range, const ChartRange(1.75, 8.25));
  });

  testWidgets('on a band scale the rows are the bands', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          y: const BandScale(labels: <String>['a', 'b', 'c']),
          left: const <Widget>[ChartAxis()],
          children: <Widget>[
            BarSeries(data: ChartData.fromValues(<double>[3, 1, 2]), direction: Axis.horizontal),
          ],
        ),
      ),
    );
    expect(c.y.range, const ChartRange(-0.5, 2.5));
    expect(c.x.range.min, 0);
    expect(c.x.range.max, greaterThanOrEqualTo(3));
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('a hit is found along y and says that its value runs along x', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(Chart(controller: c, x: _values, y: _rows, children: <Widget>[_bars(_three())])),
    );
    // Far right of the bar of row 5, 2 px below its middle.
    final ChartHit hit = c.hitTest(const Offset(380, 152), mode: ChartHitMode.nearestY).single;
    expect(hit.index, 1);
    expect(hit.valueAxis, Axis.horizontal);
    expect(hit.value, 25);
    expect(hit.argument, 5);
    expect((hit.x, hit.y), (25, 5));
    expect(hit.base, 0);
    expect(hit.rect, const Rect.fromLTRB(0, 142.5, 100, 157.5));
    expect(hit.position, const Offset(100, 150));
    expect(hit.distance, 0);

    // Between two rows the distance is the gap to the nearer bar.
    final ChartHit between = c.hitTest(const Offset(10, 170), mode: ChartHitMode.nearestY).single;
    expect(between.index, 1);
    expect(between.distance, closeTo(12.5, 1e-9));

    // The rows do not run along x.
    expect(c.hitTest(const Offset(50, 150)), isEmpty);
    // By distance: inside the bar it is zero, outside it is measured to the end.
    expect(c.hitTest(const Offset(50, 150), mode: ChartHitMode.nearest).single.distance, 0);
    expect(
      c.hitTest(const Offset(130, 150), mode: ChartHitMode.nearest).single.distance,
      closeTo(30, 1e-9),
    );
    expect(c.series.single.valueAt(5), isNull);
  });

  testWidgets('a crosshair along y and its tooltip follow the rows', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: _values,
          y: _rows,
          children: <Widget>[
            _bars(_three(), label: 'sales'),
            const ChartCrosshair(mode: ChartHitMode.nearestY),
            const ChartTooltip(),
          ],
        ),
      ),
    );
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(300, 146)));
    await tester.pump();
    expect(c.focus.value?.y, 5);
    expect(c.focus.value?.mode, ChartHitMode.nearestY);
    expect(find.text('sales: '), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('floating and stacked rows, and values below the baseline', (
    WidgetTester tester,
  ) async {
    // (top, base): row 2 from 20 to 60, row 5 from 0 to -1 (off the scale),
    // row 8 from 90 down to 40.
    final ChartData data = ChartData(valueColumns: 2)
      ..addRow(2, <double>[60, 20])
      ..addRow(5, <double>[30, 10])
      ..addRow(8, <double>[40, 90]);
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(x: _values, y: _rows, children: <Widget>[_bars(data, baseColumn: 1)]),
    );
    expect(pixel(160, 240), _red.toARGB32());
    expect(pixel(70, 240), _white, reason: 'left of the base of row 2');
    expect(pixel(250, 240), _white, reason: 'right of the top of row 2');
    expect(pixel(80, 150), _red.toARGB32());
    expect(pixel(30, 150), _white);
    expect(pixel(260, 60), _red.toARGB32(), reason: 'a top below its base');
    expect(pixel(150, 60), _white);
  });

  testWidgets('only the end away from the base is rounded', (WidgetTester tester) async {
    final ChartData data = ChartData.fromXY(<double>[2, 8], <double>[-50, 50]);
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(
        x: const LinearScale(range: FixedRange(-100, 100)),
        y: _rows,
        children: <Widget>[_bars(data, cornerRadius: 6)],
      ),
    );
    // Row 8 (y = 52.5 to 67.5 px) runs right from 200 px to 300 px.
    expect(pixel(250, 60), _red.toARGB32());
    expect(pixel(299, 53), _white, reason: 'the rounded corner at the value');
    expect(pixel(201, 53), _red.toARGB32(), reason: 'the square corner at the base');
    // Row 2 (y = 232.5 to 247.5 px) runs left from 200 px to 100 px.
    expect(pixel(150, 240), _red.toARGB32());
    expect(pixel(100, 233), _white, reason: 'the rounded corner at the value');
    expect(pixel(198, 233), _red.toARGB32(), reason: 'the square corner at the base');
  });

  testWidgets('two series side by side with an offset', (WidgetTester tester) async {
    final ChartData a = ChartData.fromXY(<double>[5], <double>[50]);
    final ChartData b = ChartData.fromXY(<double>[5], <double>[75]);
    BarSeries series(ChartData data, Color color, double offset) => BarSeries(
      data: data,
      direction: Axis.horizontal,
      step: 1,
      widthFactor: 0.4,
      offset: offset,
      color: color,
      isolate: false,
    );
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(
        x: _values,
        y: _rows,
        children: <Widget>[series(a, _red, -0.2), series(b, _green, 0.2)],
      ),
    );
    // An offset of -0.2 rows is 6 px further down, +0.2 is 6 px further up.
    expect(pixel(100, 156), _red.toARGB32());
    expect(pixel(100, 144), _green.toARGB32());
    expect(pixel(250, 156), _white);
    expect(pixel(250, 144), _green.toARGB32());
  });

  testWidgets('more rows than pixels: one bar per pixel row that keeps the extremes', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    // 3000 rows on 300 px. The long one is in the middle of each pixel row.
    final ChartData data = ChartData.generate(
      3000,
      (int i) => (i.toDouble(), i % 10 == 5 ? 90 : 10),
    );
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: _values,
          y: const LinearScale(range: FixedRange(0, 3000)),
          children: <Widget>[BarSeries(data: data, direction: Axis.horizontal, color: _red)],
        ),
      ),
    );
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    tester
        .widget<ChartPaint>(find.byType(ChartPaint))
        .painter
        .paint(ChartPaintContext(canvas: canvas, view: c.view!));
    final ui.Path path = canvas.invocations.single.invocation.positionalArguments.first as ui.Path;
    final List<Rect> boxes = <Rect>[
      for (final ui.PathMetric metric in path.computeMetrics())
        metric.extractPath(0, 1e9).getBounds(),
    ];
    expect(boxes.length, inInclusiveRange(250, 301));
    for (final Rect box in boxes) {
      expect(box.height, closeTo(1, 1e-6));
      expect(box.left, 0);
      expect(box.right, closeTo(360, 1e-3), reason: 'each pixel row holds a long bar');
    }
  });

  testWidgets('with only y to pan, a wheel that pans moves the rows', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: _values,
          y: _rows,
          children: <Widget>[
            _bars(_three()),
            const ChartPanZoom(
              panX: false,
              panY: true,
              zoomX: false,
              zoomY: true,
              wheel: ChartWheelAction.pan,
            ),
          ],
        ),
      ),
    );
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(200, 150)));
    // Scrolling down by 60 px shows what is 2 rows further down.
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 60)));
    await tester.pump();
    expect(c.x.range, const ChartRange(0, 100));
    expect(c.y.range.min, closeTo(-2, 1e-9));
    expect(c.y.range.max, closeTo(8, 1e-9));
  });

  test('the direction is part of what repaints and re-fits', () {
    final ChartData data = _three();
    BarSeriesPainter painter(Axis direction) => BarSeriesPainter(data: data, direction: direction);
    expect(painter(Axis.horizontal).shouldRepaint(painter(Axis.vertical)), isTrue);
    expect(painter(Axis.horizontal).shouldRescale(painter(Axis.vertical)), isTrue);
    expect(painter(Axis.horizontal).shouldRepaint(painter(Axis.horizontal)), isFalse);
    expect(BarSeries(data: data).direction, Axis.vertical);
    expect(painter(Axis.horizontal).valueAt(5), isNull);
    expect(painter(Axis.vertical).valueAt(5), 25);
  });
}

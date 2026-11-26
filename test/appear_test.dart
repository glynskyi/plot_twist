import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// In the 400 x 300 host, a value of 1 is 4 px along x and 3 px along y.
const ChartScale _x = LinearScale(range: FixedRange(0, 100));
const ChartScale _y = LinearScale(range: FixedRange(0, 100));
const int _white = 0xFFFFFFFF;
const Color _red = Color(0xFFFF0000);
const Duration _second = Duration(seconds: 1);
const Duration _half = Duration(milliseconds: 500);

/// One bar around x = 50 (180 to 220 px) with the value 80 (y = 60 px).
ChartData _bar([double value = 80]) => ChartData.fromXY(<double>[50], <double>[value]);

BarSeries _series(ChartData data, {Axis direction = Axis.vertical}) => BarSeries(
  data: data,
  step: 10,
  widthFactor: 1,
  color: _red,
  direction: direction,
  isolate: false,
);

ChartAppear _appear(
  Widget child, {
  ChartAppearEffect effect = ChartAppearEffect.growY,
  Duration delay = Duration.zero,
}) => ChartAppear(
  duration: _second,
  curve: Curves.linear,
  delay: delay,
  effect: effect,
  child: child,
);

void main() {
  testWidgets('growY: a bar grows from zero, while ranges and hits are final at once', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(
        controller: c,
        x: _x,
        y: const LinearScale(range: FitDataRange(includeZero: true)),
        children: <Widget>[_appear(_series(_bar()))],
      ),
    );
    // The first frame: nothing of the bar, but the scale already fits it.
    expect(pixel(200, 295), _white);
    expect(c.y.range, const ChartRange(0, 80));
    expect(c.hitsAt(50).single.y, 80);

    await tester.pump(_half);
    pixel = await capturePixels(tester);
    // Half grown: the bar fills the plot from 300 px up to 150 px.
    expect(pixel(200, 160), _red.toARGB32());
    expect(pixel(200, 140), _white);
    expect(pixel(182, 290), _red.toARGB32());
    expect(pixel(175, 290), _white, reason: 'the bar is as wide as ever');
    expect(c.y.range, const ChartRange(0, 80));

    await tester.pump(_half);
    pixel = await capturePixels(tester);
    expect(pixel(200, 5), _red.toARGB32());
    // Done: nothing keeps ticking.
    await tester.pump(_half);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('growY grows from the zero line, or from the edge of the plot nearest to it', (
    WidgetTester tester,
  ) async {
    // Zero is at y = 150 px; the bar reaches down to -60 (330 px is 60 * 3).
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(
        x: _x,
        y: const LinearScale(range: FixedRange(-50, 50)),
        children: <Widget>[_appear(_series(_bar(-40)))],
      ),
    );
    await tester.pump(_half);
    pixel = await capturePixels(tester);
    // Half of the way from 150 px down to 270 px.
    expect(pixel(200, 200), _red.toARGB32());
    expect(pixel(200, 220), _white);
    expect(pixel(200, 140), _white);
    await tester.pump(_second);

    // Zero is below the window from 40 to 100: the bar rises from the bottom.
    pixel = await renderPixels(
      tester,
      Chart(
        key: const Key('second'),
        x: _x,
        y: const LinearScale(range: FixedRange(40, 100)),
        children: <Widget>[_appear(_series(_bar()))],
      ),
    );
    await tester.pump(_half);
    pixel = await capturePixels(tester);
    // The bar ends at 80, which is 100 px from the top; half grown it ends
    // half way up from the bottom of the plot.
    expect(pixel(200, 210), _red.toARGB32());
    expect(pixel(200, 190), _white);
  });

  testWidgets('growX: a bar that lies grows from zero to the right', (WidgetTester tester) async {
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(
        x: _x,
        y: const LinearScale(range: FixedRange(0, 100)),
        children: <Widget>[
          _appear(_series(_bar(), direction: Axis.horizontal), effect: ChartAppearEffect.growX),
        ],
      ),
    );
    expect(pixel(10, 150), _white);
    await tester.pump(_half);
    pixel = await capturePixels(tester);
    // The bar reaches 80 (320 px); half grown, 160 px.
    expect(pixel(150, 150), _red.toARGB32());
    expect(pixel(170, 150), _white);
  });

  testWidgets('reveal: a line is uncovered from the left', (WidgetTester tester) async {
    final ChartData flat = ChartData.fromXY(<double>[0, 100], <double>[50, 50]);
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(
        x: _x,
        y: _y,
        children: <Widget>[
          _appear(
            LineSeries(data: flat, color: _red, width: 6, isolate: false),
            effect: ChartAppearEffect.reveal,
          ),
        ],
      ),
    );
    expect(pixel(20, 150), _white);
    await tester.pump(_half);
    pixel = await capturePixels(tester);
    expect(pixel(190, 150), _red.toARGB32());
    expect(pixel(210, 150), _white);
    await tester.pump(_half);
    pixel = await capturePixels(tester);
    expect(pixel(390, 150), _red.toARGB32());
  });

  testWidgets('fade: the series comes in through transparency', (WidgetTester tester) async {
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(
        x: _x,
        y: _y,
        children: <Widget>[_appear(_series(_bar()), effect: ChartAppearEffect.fade)],
      ),
    );
    expect(pixel(200, 200), _white);
    await tester.pump(_half);
    pixel = await capturePixels(tester);
    final int half = pixel(200, 200);
    expect((half >> 16) & 0xFF, 0xFF);
    expect((half >> 8) & 0xFF, inInclusiveRange(0x7C, 0x84));
    await tester.pump(_half);
    pixel = await capturePixels(tester);
    expect(pixel(200, 200), _red.toARGB32());
  });

  testWidgets('a delay holds the series back', (WidgetTester tester) async {
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(
        x: _x,
        y: _y,
        children: <Widget>[_appear(_series(_bar()), delay: _second)],
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    pixel = await capturePixels(tester);
    expect(pixel(200, 295), _white);
    await tester.pump(const Duration(milliseconds: 600));
    pixel = await capturePixels(tester);
    // Half a second into the animation.
    expect(pixel(200, 190), _red.toARGB32());
    expect(pixel(200, 170), _white);
    await tester.pump(_second);
  });

  testWidgets('around a whole chart: every series appears, the grid and rules do not', (
    WidgetTester tester,
  ) async {
    const Color grid = Color(0xFF0000FF);
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      _appear(
        Chart(
          x: _x,
          y: _y,
          children: <Widget>[
            const ChartGrid(color: grid, width: 3, vertical: false),
            _series(_bar()),
            const ChartReferenceLine.y(90, color: grid, width: 3),
            ChartPaint(painter: _Block()),
          ],
        ),
      ),
    );
    // The first frame: the grid line at 40 and the rule at 90 are there.
    expect(pixel(20, 180), grid.toARGB32());
    expect(pixel(20, 30), grid.toARGB32());
    // The bar and the series of its own are not yet.
    expect(pixel(200, 295), _white);
    expect(pixel(350, 295), _white);
    await tester.pump(_second);
    final int Function(int x, int y) done = await capturePixels(tester);
    expect(done(200, 100), _red.toARGB32());
    expect(done(350, 100), _red.toARGB32());
    await tester.pump(_half);
  });

  testWidgets('around one series: the others are there from the start', (
    WidgetTester tester,
  ) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      Chart(
        x: _x,
        y: _y,
        children: <Widget>[
          _series(ChartData.fromXY(<double>[20], <double>[80])),
          _appear(_series(_bar())),
        ],
      ),
    );
    expect(pixel(80, 100), _red.toARGB32());
    expect(pixel(200, 295), _white);
    await tester.pump(_second);
    await tester.pump(_half);
  });

  testWidgets('with reduced motion the series are in place on the first frame', (
    WidgetTester tester,
  ) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Chart(x: _x, y: _y, children: <Widget>[_appear(_series(_bar()))]),
      ),
    );
    expect(pixel(200, 100), _red.toARGB32());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a new key plays it again; a rebuild does not', (WidgetTester tester) async {
    Widget build(Key key) => Chart(
      x: _x,
      y: _y,
      children: <Widget>[
        ChartAppear(key: key, duration: _second, curve: Curves.linear, child: _series(_bar())),
      ],
    );
    await renderPixels(tester, build(const Key('a')));
    await tester.pump(_second);
    await tester.pump(_half);
    int Function(int x, int y) pixel = await renderPixels(tester, build(const Key('a')));
    expect(pixel(200, 100), _red.toARGB32());
    pixel = await renderPixels(tester, build(const Key('b')));
    expect(pixel(200, 295), _white);
    await tester.pump(_second);
    await tester.pump(_half);
  });
}

/// A series of its own: a block around x = 350 px, from the bottom to 80.
class _Block extends ChartSeriesPainter {
  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) => null;

  @override
  void paint(ChartPaintContext context) => context.canvas.drawRect(
    Rect.fromLTRB(340, context.view.y.toPixel(80), 360, context.view.size.height),
    Paint()..color = _red,
  );

  @override
  bool shouldRepaint(_Block oldDelegate) => false;
}

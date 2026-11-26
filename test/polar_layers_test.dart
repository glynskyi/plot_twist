import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// In the 400 x 300 host a polar chart is a circle of radius 150 around
// (200, 150). The angle scale shows 0 to 100 (ticks every 10) and the radius
// scale 0 to 10 (ticks at 0, 5 and 10), unless a test says otherwise.
const ChartScale _percent = LinearScale(range: FixedRange(0, 100));
const ChartScale _ten = LinearScale(range: FixedRange(0, 10));
const ChartScale _four = ChartScale.band(labels: <String>['N', 'E', 'S', 'W']);
const int _white = 0xFFFFFFFF;
const Color _red = Color(0xFFFF0000);
const Color _green = Color(0xFF00FF00);
const TextStyle _style = TextStyle(fontSize: 10, height: 1, color: Color(0xFF000000));

/// A series that draws nothing and gives a band scale its four bands.
Widget _fourBands() => RadarSeries(
  data: ChartData.fromValues(<double>[1, 1, 1, 1]),
  width: 0,
  pointRadius: 0,
  fill: false,
);

/// What the layer of [type] draws: where its texts start, and its lines.
/// The layer lets go of a text as soon as it is drawn, so its size cannot be
/// read here: in these tests it is 10 px per character and 10 px high.
({List<Offset> texts, List<(Offset, Offset)> lines}) _drawn(WidgetTester tester, Type type) {
  final RenderObject layer = tester.renderObject(
    find.descendant(of: find.byType(type), matching: find.byType(ChartPaint)),
  );
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  layer.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  final List<Offset> texts = <Offset>[];
  final List<(Offset, Offset)> lines = <(Offset, Offset)>[];
  for (final RecordedInvocation call in canvas.invocations) {
    final List<dynamic> arguments = call.invocation.positionalArguments;
    if (call.invocation.memberName == #drawParagraph) {
      texts.add(arguments[1] as Offset);
    } else if (call.invocation.memberName == #drawLine) {
      lines.add((arguments[0] as Offset, arguments[1] as Offset));
    }
  }
  return (texts: texts, lines: lines);
}

Matcher _at(double left, double top) => within<Offset>(distance: 0.01, from: Offset(left, top));

void main() {
  group('ChartPolarGrid', () {
    Widget chart(ChartPolarGrid grid, {ChartScale angle = _percent, bool bands = false}) =>
        PolarChart(angle: angle, radius: _ten, children: <Widget>[if (bands) _fourBands(), grid]);

    testWidgets('a ring at every tick of the radius scale, a spoke at every tick of the angle', (
      WidgetTester tester,
    ) async {
      int Function(int x, int y) pixel = await renderPixels(
        tester,
        chart(const ChartPolarGrid(color: _red, width: 4)),
      );
      expect(pixel(275, 150), _red.toARGB32(), reason: 'the ring at 5, 75 px out');
      expect(pixel(253, 203), _red.toARGB32(), reason: 'it is round');
      expect(pixel(200, 100), _red.toARGB32(), reason: 'the spoke at 0');
      expect(pixel(200, 200), _red.toARGB32(), reason: 'the spoke at 50');
      expect(pixel(215, 110), _white, reason: 'between two spokes');

      pixel = await renderPixels(
        tester,
        chart(const ChartPolarGrid(color: _red, width: 4, rings: false)),
      );
      expect(pixel(253, 203), _white);
      expect(pixel(200, 100), _red.toARGB32());

      pixel = await renderPixels(
        tester,
        chart(const ChartPolarGrid(color: _red, width: 4, spokes: false)),
      );
      expect(pixel(200, 100), _white);
      expect(pixel(253, 203), _red.toARGB32());
    });

    testWidgets('polygon rings run straight from spoke to spoke', (WidgetTester tester) async {
      int Function(int x, int y) pixel = await renderPixels(
        tester,
        chart(
          const ChartPolarGrid(color: _red, width: 4, shape: ChartPolarGridShape.polygon),
          angle: _four,
          bands: true,
        ),
      );
      // The ring at 5 is a diamond through (200, 75) and (275, 150).
      expect(pixel(237, 112), _red.toARGB32());
      expect(pixel(253, 97), _white, reason: 'where a circle would pass');
      expect(pixel(275, 150), _red.toARGB32());

      pixel = await renderPixels(
        tester,
        chart(const ChartPolarGrid(color: _red, width: 4), angle: _four, bands: true),
      );
      expect(pixel(253, 97), _red.toARGB32());
      expect(pixel(237, 112), _white);
    });

    testWidgets('on part of a circle the rings are arcs, and spokes start at the inner radius', (
      WidgetTester tester,
    ) async {
      // The upper half of a circle of radius 200 around (200, 250), with a
      // hole of 100: the ring at 5 is 150 px out.
      final int Function(int x, int y) pixel = await renderPixels(
        tester,
        PolarChart(
          angle: _percent,
          radius: _ten,
          startAngle: math.pi,
          sweepAngle: math.pi,
          innerRadius: 0.5,
          children: const <Widget>[ChartPolarGrid(color: _red, width: 4)],
        ),
      );
      expect(pixel(200, 100), _red.toARGB32(), reason: 'the ring at 5');
      expect(pixel(94, 144), _red.toARGB32(), reason: 'the ring, half way up on the left');
      // The arc is 628 px long, so the angle scale has a tick every 20.
      expect(pixel(50, 250), _red.toARGB32(), reason: 'the spoke at 0, to nine o\'clock');
      expect(pixel(146, 84), _red.toARGB32(), reason: 'the spoke at 40');
      expect(pixel(200, 60), _white, reason: 'no tick at 50, so no spoke straight up');
      expect(pixel(150, 250), _white, reason: 'inside the inner radius');
    });

    testWidgets('lines can be dashed', (WidgetTester tester) async {
      final int Function(int x, int y) pixel = await renderPixels(
        tester,
        chart(const ChartPolarGrid(color: _red, width: 4, rings: false, dash: <double>[10, 10])),
      );
      // The spoke at 0 runs up from the centre: 10 px drawn, 10 px not.
      expect(pixel(200, 144), _red.toARGB32());
      expect(pixel(200, 134), _white);
      expect(pixel(200, 124), _red.toARGB32());
    });
  });

  group('ChartPolarAxis', () {
    // With a margin of 30 the circle has a radius of 120. A label is a
    // square of 10 px per character.
    Widget chart(Widget axis, {ChartScale angle = _four}) => host(
      PolarChart(
        angle: angle,
        radius: _ten,
        margin: const EdgeInsets.all(30),
        children: <Widget>[if (angle == _four) _fourBands(), axis],
      ),
    );

    testWidgets('angle: the labels stand around the circle, outside it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(chart(const ChartPolarAxis.angle(style: _style)));
      final List<Offset> texts = _drawn(tester, ChartPolarAxis).texts;
      // 6 px away from the circle: above, right of, below and left of it.
      expect(texts, hasLength(4));
      expect(texts[0], _at(195, 14));
      expect(texts[1], _at(326, 145));
      expect(texts[2], _at(195, 276));
      expect(texts[3], _at(64, 145));
    });

    testWidgets('angle: inside the circle, with tick marks, and with texts of your own', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(chart(const ChartPolarAxis.angle(style: _style, inside: true)));
      expect(_drawn(tester, ChartPolarAxis).texts.first, _at(195, 36));
      // In a chart with a hole they stand inside the ring: here it starts 60
      // px from the centre.
      await tester.pumpWidget(
        host(
          PolarChart(
            angle: _four,
            radius: _ten,
            innerRadius: 0.5,
            margin: const EdgeInsets.all(30),
            children: <Widget>[
              _fourBands(),
              const ChartPolarAxis.angle(style: _style, inside: true, tickLength: 4),
            ],
          ),
        ),
      );
      final ({List<Offset> texts, List<(Offset, Offset)> lines}) ring = _drawn(
        tester,
        ChartPolarAxis,
      );
      expect(ring.lines.first.$1, within<Offset>(distance: 1e-6, from: const Offset(200, 90)));
      expect(ring.lines.first.$2, within<Offset>(distance: 1e-6, from: const Offset(200, 94)));
      expect(ring.texts.first, _at(195, 100));

      await tester.pumpWidget(chart(const ChartPolarAxis.angle(style: _style, tickLength: 8)));
      ({List<Offset> texts, List<(Offset, Offset)> lines}) drawn = _drawn(tester, ChartPolarAxis);
      expect(drawn.lines, hasLength(4));
      expect(drawn.lines.first.$1, within<Offset>(distance: 1e-6, from: const Offset(200, 30)));
      expect(drawn.lines.first.$2, within<Offset>(distance: 1e-6, from: const Offset(200, 22)));
      expect(drawn.texts.first, _at(195, 6), reason: 'beyond the mark');

      await tester.pumpWidget(
        chart(
          ChartPolarAxis.angle(
            style: _style,
            format: (ChartTick tick) => tick.value == 2 ? '' : '${tick.label}!',
          ),
        ),
      );
      drawn = _drawn(tester, ChartPolarAxis);
      expect(drawn.texts, hasLength(3), reason: 'an empty text leaves a tick without a label');
      expect(drawn.texts.first, _at(190, 14));
    });

    testWidgets('angle: a label that would cover another is left out', (WidgetTester tester) async {
      await tester.pumpWidget(chart(const ChartPolarAxis.angle(style: _style), angle: _percent));
      // 754 px around: a tick every 20, and the one at 100 falls on the one at 0.
      expect(_drawn(tester, ChartPolarAxis).texts, hasLength(5));

      // A tick every 5 puts the labels 40 px apart.
      const ChartScale dense = LinearScale(
        range: FixedRange(0, 100),
        ticks: LinearTicks(spacing: 20),
      );
      await tester.pumpWidget(chart(const ChartPolarAxis.angle(style: _style), angle: dense));
      expect(_drawn(tester, ChartPolarAxis).texts, hasLength(20));
      // At three times the size, labels of 60 px do not all fit.
      await tester.pumpWidget(
        chart(const ChartPolarAxis.angle(style: TextStyle(fontSize: 30, height: 1)), angle: dense),
      );
      final int shown = _drawn(tester, ChartPolarAxis).texts.length;
      expect(shown, lessThan(20));
      expect(shown, greaterThan(5));
    });

    testWidgets('radius: the labels run along a line from the centre, beside it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(chart(const ChartPolarAxis.radius(style: _style)));
      // Up from the centre at (200, 150), 4 px right of the line.
      expect(_drawn(tester, ChartPolarAxis).texts, <Matcher>[
        _at(204, 145), // 0
        _at(204, 85), // 5
        _at(204, 25), // 10
      ]);

      // To three o'clock: below the line.
      await tester.pumpWidget(chart(const ChartPolarAxis.radius(style: _style, angle: 0)));
      expect(_drawn(tester, ChartPolarAxis).texts, <Matcher>[
        _at(195, 154),
        _at(255, 154),
        _at(310, 154),
      ]);
    });
  });

  group('ChartNeedle', () {
    Widget gauge(ChartNeedle needle, {double sweep = 2 * math.pi}) =>
        PolarChart(angle: _percent, sweepAngle: sweep, children: <Widget>[needle]);

    testWidgets('points from the centre at a value of the angle scale', (
      WidgetTester tester,
    ) async {
      // 25 is three o'clock; 80% of the radius is 120 px.
      int Function(int x, int y) pixel = await renderPixels(
        tester,
        gauge(const ChartNeedle(value: 25, color: _red, width: 10, length: 0.8, hubRadius: 0)),
      );
      expect(pixel(260, 150), _red.toARGB32());
      expect(pixel(205, 153), _red.toARGB32(), reason: '10 px wide at the centre');
      expect(pixel(310, 153), _white, reason: 'it tapers');
      expect(pixel(330, 150), _white, reason: 'beyond its point');
      expect(pixel(185, 150), _white, reason: 'no tail');

      pixel = await renderPixels(
        tester,
        gauge(
          const ChartNeedle(
            value: 25,
            color: _red,
            width: 10,
            tail: 0.2,
            hubRadius: 12,
            hubColor: _green,
          ),
        ),
      );
      expect(pixel(260, 150), _red.toARGB32());
      expect(pixel(178, 150), _red.toARGB32(), reason: 'the tail, 30 px behind the centre');
      expect(pixel(200, 141), _green.toARGB32(), reason: 'the cap over the centre');
    });

    testWidgets('a value beyond the scale points at its end', (WidgetTester tester) async {
      // Half a circle from twelve to six o'clock, with a radius of 150
      // around (125, 150).
      int Function(int x, int y) pixel = await renderPixels(
        tester,
        gauge(const ChartNeedle(value: 180, color: _red, width: 10, hubRadius: 0), sweep: math.pi),
      );
      expect(pixel(125, 220), _red.toARGB32());
      pixel = await renderPixels(
        tester,
        gauge(const ChartNeedle(value: -40, color: _red, width: 10, hubRadius: 0), sweep: math.pi),
      );
      expect(pixel(125, 80), _red.toARGB32());
      expect(pixel(125, 220), _white);
    });
  });

  testWidgets('ChartPolarPositioned places a widget by an angle and a radius', (
    WidgetTester tester,
  ) async {
    Widget chart(Widget positioned) =>
        host(PolarChart(angle: _percent, radius: _ten, children: <Widget>[positioned]));
    const Widget marker = SizedBox(key: Key('marker'), width: 6, height: 6);

    await tester.pumpWidget(chart(const ChartPolarPositioned(angle: 25, radius: 5, child: marker)));
    expect(markerCenter(tester), const Offset(275, 150));

    // Without a radius: a fraction of the outer one.
    await tester.pumpWidget(
      chart(const ChartPolarPositioned(angle: 75, radiusFactor: 0.6, child: marker)),
    );
    expect(markerCenter(tester), within<Offset>(distance: 1e-6, from: const Offset(110, 150)));

    await tester.pumpWidget(
      chart(
        const ChartPolarPositioned(
          angle: 50,
          radius: 10,
          alignment: Alignment.bottomCenter,
          offset: Offset(0, -4),
          child: marker,
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const Key('marker'))).bottom, closeTo(296, 1e-6));
  });

  testWidgets('a PolarChart docks widgets, has a size of its own, and can be described', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: UnconstrainedBox(
          child: PolarChart(
            semanticLabel: 'Spending by category',
            top: const <Widget>[SizedBox(key: Key('marker'), height: 20)],
            children: <Widget>[
              PieSeries(data: ChartData.fromValues(<double>[1, 2])),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PolarChart)), const Size(240, 240));
    expect(tester.getSize(find.byKey(const Key('marker'))), const Size(240, 20));
    expect(tester.getSize(find.byType(ChartStack)), const Size(240, 220));
    expect(find.bySemanticsLabel('Spending by category'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a polar layer outside a PolarChart says where it belongs', (
    WidgetTester tester,
  ) async {
    for (final Widget layer in const <Widget>[
      ChartPolarGrid(),
      ChartPolarAxis.angle(),
      ChartNeedle(value: 1),
      ChartPolarPositioned(angle: 1, child: SizedBox()),
    ]) {
      await tester.pumpWidget(host(Chart(children: <Widget>[layer])));
      expect(tester.takeException().toString(), contains('must be placed in a PolarChart'));
    }
  });
}

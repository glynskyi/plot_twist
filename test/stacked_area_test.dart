import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// In the 400 x 300 host, a value of 1 is 4 px along x and 3 px along y.
const ChartScale _x = LinearScale(range: FixedRange(0, 100));
const ChartScale _y = LinearScale(range: FixedRange(0, 100));
const int _white = 0xFFFFFFFF;
const Color _red = Color(0xFFFF0000);
const Color _green = Color(0xFF00FF00);

/// A store with a top and a base column over x = 0, 10, … 100.
ChartData _band(double Function(double x) top, double Function(double x) base) {
  final ChartData data = ChartData(valueColumns: 2);
  for (double x = 0; x <= 100; x += 10) {
    data.addRow(x, <double>[top(x), base(x)]);
  }
  return data;
}

void main() {
  group('ChartData.stacked', () {
    test('diverging stacks negative values downwards from zero', () {
      final List<ChartData> layers = ChartData.stacked(<ChartData>[
        ChartData.fromValues(<double>[3, -2, 4, double.nan]),
        ChartData.fromValues(<double>[1, -1, -5, 2]),
        ChartData.fromValues(<double>[2, 2, 2, -1]),
      ], diverging: true);
      List<(double, double)> rows(ChartData layer) => <(double, double)>[
        for (int i = 0; i < layer.length; i++) (layer.value(i, 0), layer.value(i, 1)),
      ];
      // (top, base) of every row.
      expect(rows(layers[0]), <(double, double)>[(3, 0), (-2, 0), (4, 0), (0, 0)]);
      expect(rows(layers[1]), <(double, double)>[(4, 3), (-3, -2), (-5, 0), (2, 0)]);
      expect(rows(layers[2]), <(double, double)>[(6, 4), (2, 0), (6, 4), (-1, 0)]);
    });

    test('without it, every value is added to one running total', () {
      final List<ChartData> layers = ChartData.stacked(<ChartData>[
        ChartData.fromValues(<double>[3, -2]),
        ChartData.fromValues(<double>[1, -1]),
      ]);
      expect(layers[1].value(0, 0), 4);
      expect(layers[1].value(1, 0), -3);
      expect(layers[1].value(1, 1), -2);
    });
  });

  group('LineSeries(baseColumn:)', () {
    testWidgets('fills between the line and the base column', (WidgetTester tester) async {
      // The line at 60 (y = 120 px), the base at 20 (y = 240 px).
      final int Function(int x, int y) pixel = await renderPixels(
        tester,
        Chart(
          x: _x,
          y: _y,
          children: <Widget>[
            LineSeries(
              data: _band((_) => 60, (_) => 20),
              baseColumn: 1,
              fillColor: _red,
              width: 0,
              isolate: false,
            ),
          ],
        ),
      );
      expect(pixel(200, 180), _red.toARGB32());
      expect(pixel(10, 125), _red.toARGB32());
      expect(pixel(390, 235), _red.toARGB32());
      expect(pixel(200, 110), _white, reason: 'above the line');
      expect(pixel(200, 250), _white, reason: 'below the base');
      expect(pixel(200, 295), _white, reason: 'at the bottom of the plot');
    });

    testWidgets('fills between them where they cross, for every curve', (
      WidgetTester tester,
    ) async {
      for (final LineCurve curve in LineCurve.values) {
        // The line falls from 90 to 10 and the base rises from 10 to 90.
        final int Function(int x, int y) pixel = await renderPixels(
          tester,
          Chart(
            x: _x,
            y: _y,
            children: <Widget>[
              LineSeries(
                data: _band((double x) => 90 - 0.8 * x, (double x) => 10 + 0.8 * x),
                baseColumn: 1,
                curve: curve,
                fillColor: _red,
                width: 0,
                isolate: false,
              ),
            ],
          ),
        );
        // At x = 10 (40 px) the band spans 82 down to 18; at x = 90 the same.
        expect(pixel(42, 150), _red.toARGB32(), reason: '${curve.name}: left of the crossing');
        expect(pixel(358, 150), _red.toARGB32(), reason: '${curve.name}: right of the crossing');
        expect(pixel(42, 20), _white, reason: '${curve.name}: above the band');
        expect(pixel(42, 280), _white, reason: '${curve.name}: below the band');
        expect(pixel(358, 280), _white, reason: '${curve.name}: below the band');
      }
    });

    testWidgets('without a fill colour the band takes half the colour of the series', (
      WidgetTester tester,
    ) async {
      final int Function(int x, int y) pixel = await renderPixels(
        tester,
        Chart(
          x: _x,
          y: _y,
          children: <Widget>[
            LineSeries(
              data: _band((_) => 60, (_) => 20),
              baseColumn: 1,
              color: _red,
              width: 0,
              isolate: false,
            ),
          ],
        ),
      );
      final int band = pixel(200, 180);
      expect((band >> 16) & 0xFF, 0xFF);
      expect((band >> 8) & 0xFF, inInclusiveRange(0x7E, 0x81));
      expect(band & 0xFF, inInclusiveRange(0x7E, 0x81));
      expect(pixel(200, 250), _white);
    });

    testWidgets('a missing value in either column is a gap', (WidgetTester tester) async {
      final ChartData data = _band((_) => 60, (_) => 20);
      data.setValue(5, double.nan, column: 1);
      final int Function(int x, int y) pixel = await renderPixels(
        tester,
        Chart(
          x: _x,
          y: _y,
          children: <Widget>[
            LineSeries(data: data, baseColumn: 1, fillColor: _red, width: 0, isolate: false),
          ],
        ),
      );
      // Row 5 is at 200 px; the rows next to it are at 160 and 240.
      expect(pixel(180, 180), _white);
      expect(pixel(220, 180), _white);
      expect(pixel(150, 180), _red.toARGB32());
      expect(pixel(250, 180), _red.toARGB32());
    });

    testWidgets('layers from ChartData.stacked sit on each other', (WidgetTester tester) async {
      final List<ChartData> layers = ChartData.stacked(<ChartData>[
        ChartData.fromValues(List<double>.filled(11, 30), step: 10),
        ChartData.fromValues(List<double>.filled(11, 40), step: 10),
      ]);
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final int Function(int x, int y) pixel = await renderPixels(
        tester,
        Chart(
          controller: c,
          x: _x,
          y: _y,
          children: <Widget>[
            LineSeries(
              data: layers[0],
              baseColumn: 1,
              fillColor: _red,
              width: 0,
              isolate: false,
              label: 'lower',
            ),
            LineSeries(
              data: layers[1],
              baseColumn: 1,
              fillColor: _green,
              width: 0,
              isolate: false,
              label: 'upper',
            ),
          ],
        ),
      );
      // 0 to 30 is red (y 300 to 210 px), 30 to 70 green (y 210 to 90 px).
      expect(pixel(200, 250), _red.toARGB32());
      expect(pixel(200, 150), _green.toARGB32());
      expect(pixel(200, 80), _white);

      // A hit carries the base, so a tooltip can show the size of the layer.
      final ChartHit upper = c.hitsAt(50).firstWhere((ChartHit h) => h.series?.label == 'upper');
      expect(upper.value, 70);
      expect(upper.base, 30);
      expect(c.hitsAt(50).firstWhere((ChartHit h) => h.series?.label == 'lower').base, 0);
    });

    testWidgets('automatic ranges cover the base column, and ignore the baseline', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            y: const LinearScale(range: FitDataRange()),
            children: <Widget>[
              LineSeries(data: _band((_) => 60, (_) => 20), baseColumn: 1, baseline: -500),
            ],
          ),
        ),
      );
      expect(c.y.range, const ChartRange(20, 60));
    });

    testWidgets('dense data keeps its band', (WidgetTester tester) async {
      // Far more rows than pixels, which a plain line would reduce.
      final ChartData data = ChartData(valueColumns: 2);
      for (int i = 0; i <= 20000; i++) {
        data.addRow(i / 200, <double>[60, 20]);
      }
      final int Function(int x, int y) pixel = await renderPixels(
        tester,
        Chart(
          x: _x,
          y: _y,
          children: <Widget>[
            LineSeries(data: data, baseColumn: 1, fillColor: _red, width: 0, isolate: false),
          ],
        ),
      );
      expect(pixel(200, 180), _red.toARGB32());
      expect(pixel(200, 250), _white);
      expect(pixel(200, 110), _white);
    });

    test('a change of the base column repaints and re-fits', () {
      final ChartData data = _band((_) => 60, (_) => 20);
      LineSeriesPainter painter(int? baseColumn) =>
          LineSeriesPainter(data: data, baseColumn: baseColumn);
      expect(painter(1).shouldRepaint(painter(null)), isTrue);
      expect(painter(1).shouldRescale(painter(null)), isTrue);
      expect(painter(1).shouldRepaint(painter(1)), isFalse);
      expect(LineSeries(data: data, baseColumn: 1).baseColumn, 1);
    });
  });
}

// The names that 0.2.0 replaced keep working until 0.3.0.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

void main() {
  final ChartData data = ChartData.fromValues(<double>[1, 2, 3]);
  final ChartData candles = ChartData(valueColumns: 4)..addRow(0, <double>[1, 3, 0, 2]);

  test('BarSeries.width and radius are widthFactor and cornerRadius', () {
    final BarSeries old = BarSeries(data: data, width: 0.5, radius: 8);
    expect(old.widthFactor, 0.5);
    expect(old.cornerRadius, 8);
    expect(old.width, 0.5);
    expect(old.radius, 8);

    final BarSeries fresh = BarSeries(data: data);
    expect(fresh.widthFactor, 0.7);
    expect(fresh.cornerRadius, 0);

    // The new name wins when both are given.
    expect(BarSeries(data: data, widthFactor: 0.3, width: 0.9).widthFactor, 0.3);

    final BarSeriesPainter painter = BarSeriesPainter(
      data: data,
      color: const Color(0xFF000000),
      width: 0.4,
      radius: 2,
    );
    expect(painter.widthFactor, 0.4);
    expect(painter.cornerRadius, 2);
    expect(painter.width, 0.4);
    expect(painter.radius, 2);
  });

  test('CandlestickSeries.width is widthFactor', () {
    final CandlestickSeries old = CandlestickSeries(data: candles, width: 0.5);
    expect(old.widthFactor, 0.5);
    expect(old.width, 0.5);
    expect(CandlestickSeries(data: candles).widthFactor, 0.7);

    final CandlestickSeriesPainter painter = CandlestickSeriesPainter(
      data: candles,
      upColor: const Color(0xFF00FF00),
      downColor: const Color(0xFFFF0000),
      width: 0.4,
    );
    expect(painter.widthFactor, 0.4);
    expect(painter.width, 0.4);
  });

  test('ScatterSeries.radius is pointRadius', () {
    final ScatterSeries old = ScatterSeries(data: data, radius: 5);
    expect(old.pointRadius, 5);
    expect(old.radius, 5);
    expect(ScatterSeries(data: data).pointRadius, 3);

    final ScatterSeriesPainter painter = ScatterSeriesPainter(
      data: data,
      color: const Color(0xFF000000),
      radius: 6,
    );
    expect(painter.pointRadius, 6);
    expect(painter.radius, 6);
  });

  test('the top-level formatNumber and niceStep are on ChartTicks', () {
    expect(formatNumber(2.5, step: 0.5), ChartTicks.formatNumber(2.5, step: 0.5));
    expect(ChartTicks.formatNumber(2.5, step: 0.5), '2.5');
    expect(niceStep(3.7), ChartTicks.niceStep(3.7));
    expect(ChartTicks.niceStep(3.7), 5);
  });

  testWidgets('Chart.scales still adds vertical scales, next to yScales', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          scales: const <Object, ChartScale>{'old': LinearScale(range: FixedRange(0, 10))},
          yScales: const <Object, ChartScale>{'new': LinearScale(range: FixedRange(0, 20))},
          children: <Widget>[
            LineSeries(data: data, yScale: 'old'),
            LineSeries(data: data, yScale: 'new'),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(c.view!.scale('old').direction, Axis.vertical);
    expect(c.view!.scale('old').max, 10);
    expect(c.view!.scale('new').direction, Axis.vertical);
    expect(c.view!.scale('new').max, 20);
  });

  testWidgets('clip reaches the layer of a bar, scatter and candlestick series', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        Chart(
          children: <Widget>[
            BarSeries(data: data, clip: false),
            ScatterSeries(data: data, clip: false),
            CandlestickSeries(data: candles, clip: false),
            BarSeries(data: data),
          ],
        ),
      ),
    );
    final List<bool> clips = tester
        .widgetList<ChartPaint>(find.byType(ChartPaint))
        .map((ChartPaint paint) => paint.clip)
        .toList();
    expect(clips, <bool>[false, false, false, true]);
  });
}

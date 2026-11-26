import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// The code samples of README.md, compiled and run. The last test fails when a
// line of a sample in the README is not in this file.

class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.prices});

  /// For example `ChartData.fromXY(times, values)`.
  final ChartData prices;

  @override
  Widget build(BuildContext context) {
    return Chart(
      x: const .time(),
      y: const .linear(range: .fitVisible()),
      left: const <Widget>[ChartAxis()],
      bottom: const <Widget>[ChartAxis()],
      children: <Widget>[
        const ChartGrid(),
        LineSeries(data: prices, label: 'Price'),
        const ChartPanZoom(),
        const ChartCrosshair(),
        const ChartTooltip(),
      ],
    );
  }
}

/// What a price feed delivers for one period.
typedef Bar = ({DateTime time, double open, double high, double low, double close});

class CandleChart extends StatelessWidget {
  const CandleChart({super.key, required this.candles});

  /// One row per candle, with four value columns: open, high, low, close.
  final ChartData candles;

  @override
  Widget build(BuildContext context) {
    return Chart(
      x: const .time(),
      y: const .linear(range: .fitVisible()),
      right: const <Widget>[ChartAxis()],
      bottom: const <Widget>[ChartAxis()],
      children: <Widget>[
        const ChartGrid(),
        CandlestickSeries(data: candles, label: 'ACME'),
        const ChartPanZoom(),
        const ChartCrosshair(),
        ChartTooltip(
          builder: (BuildContext context, List<ChartHit> hits) {
            final ChartCandle c = hits.first.datum! as ChartCandle;
            return Text('O ${c.open}  H ${c.high}  L ${c.low}  C ${c.close}');
          },
        ),
      ],
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

/// Lollipops: a stem from zero to each value, with a dot on top.
class LollipopPainter extends ChartSeriesPainter {
  const LollipopPainter(this.rows, this.color) : super(data: rows);

  final ChartData rows;
  final Color color;

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (int i = 0; i < rows.length; i++) {
      final Offset top = view.toPixel(rows.x(i), rows.y(i));
      context.canvas
        ..drawLine(view.toPixel(rows.x(i), 0), top, paint)
        ..drawCircle(top, 4, paint);
    }
  }

  // Feeds automatic ranges.
  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) =>
      rows.isEmpty ? null : ChartDataBounds(x: rows.xExtent, y: rows.valueExtent()!.include(0));

  // Feeds tooltips and the crosshair.
  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    if (rows.isEmpty) return;
    final int i = rows.nearestIndex(query.view.x.toValue(query.position.dx));
    final Offset p = query.view.toPixel(rows.x(i), rows.y(i));
    final double distance = (p - query.position).distance;
    if (distance > query.maxDistance) return;
    hits.add(ChartHit(x: rows.x(i), y: rows.y(i), position: p, distance: distance, index: i));
  }

  @override
  bool shouldRepaint(LollipopPainter oldDelegate) =>
      oldDelegate.rows != rows || oldDelegate.color != color;
}

void main() {
  testWidgets('quick start: pans, and Y follows the visible window', (WidgetTester tester) async {
    final double day0 = DateTime.utc(2026).chartValue;
    final ChartData prices = ChartData.generate(200, (int i) => (day0 + i * 86400e3, i.toDouble()));
    await tester.pumpWidget(host(PriceChart(prices: prices)));
    final ChartController chart = ChartScope.of(tester.element(find.byType(ChartGrid))).controller;
    expect(chart.view!.x.min, day0);
    expect(chart.view!.y.max, greaterThanOrEqualTo(199));

    await tester.sendEventToBinding(const PointerAddedEvent(position: Offset(200, 100)));
    await tester.sendEventToBinding(
      const PointerScrollEvent(position: Offset(200, 100), scrollDelta: Offset(0, -400)),
    );
    await tester.pump();
    final double zoomedSpan = chart.view!.x.max - chart.view!.x.min;
    expect(zoomedSpan, lessThan(199 * 86400e3));
    // Values grow with time, so a narrower window has a lower maximum.
    expect(chart.view!.y.max, lessThan(199));

    final double before = chart.view!.x.min;
    await tester.dragFrom(const Offset(200, 100), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(chart.view!.x.min, lessThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the crossing dot stays on the Y axis while the chart scrolls', (
    WidgetTester tester,
  ) async {
    final ChartData temperature = ChartData.generate(11, (int i) => (i.toDouble(), 2.0 * i));
    final ChartController chart = ChartController();
    addTearDown(chart.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: chart,
          y: const .linear(range: .fitVisible()),
          left: const <Widget>[ChartAxis()],
          children: <Widget>[
            LineSeries(id: 'temp', data: temperature),
            const ChartPanZoom(),
            ChartPositioned.resolve(
              // Runs in layout on every view change. The dot itself is never rebuilt.
              position: (ChartView view) {
                final double? y = chart.seriesById('temp')?.valueAt(view.x.min);
                return y == null ? null : view.toPixel(view.x.min, y);
              },
              overflow: .visible, // paint over the axis line
              child: const Dot(),
            ),
          ],
        ),
      ),
    );
    double axisLine() => tester.getTopRight(find.byType(ChartAxis)).dx;
    Offset dot() => tester.getCenter(find.byType(Dot));
    expect(dot().dx, moreOrLessEquals(axisLine()));
    expect(dot().dy, moreOrLessEquals(chart.view!.y.toPixel(0)));

    // The new window has longer labels, so the axis gets wider: the dot follows it.
    final double before = axisLine();
    chart.x.jumpTo(2.5, 8);
    await tester.pump();
    expect(axisLine(), greaterThan(before));
    expect(dot().dx, moreOrLessEquals(axisLine()));
    // Between two rows: the value is read off the drawn line.
    expect(dot().dy, moreOrLessEquals(chart.view!.y.toPixel(5)));

    chart.x.jumpTo(20, 30);
    await tester.pump();
    expect(chart.seriesById('temp')!.valueAt(20), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom series gets automatic ranges and hit testing', (WidgetTester tester) async {
    final ChartData steps = ChartData.fromXY(<double>[0, 1, 2, 3], <double>[40, 90, 60, 75]);
    const Color color = Color(0xFF4E79A7);
    final ChartController chart = ChartController();
    addTearDown(chart.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: chart,
          children: <Widget>[
            // In a chart:
            ChartPaint(
              id: 'steps',
              label: 'Steps',
              color: color,
              painter: LollipopPainter(steps, color),
            ),
            const ChartTooltip(),
          ],
        ),
      ),
    );
    // The stems start at zero, which no row contains.
    expect(chart.view!.y.min, lessThanOrEqualTo(0));
    expect(chart.view!.y.max, greaterThanOrEqualTo(90));
    final ChartHit hit = chart.hitsAt(1.2).single;
    expect((hit.index, hit.y, hit.series?.label), (1, 90, 'Steps'));

    steps.add(4, 300);
    await tester.pump();
    expect(chart.view!.y.max, greaterThanOrEqualTo(300));
  });

  testWidgets('candlesticks: Y fits the visible candles and the tooltip shows four prices', (
    WidgetTester tester,
  ) async {
    final List<Bar> bars = <Bar>[
      for (int i = 0; i < 30; i++)
        (
          time: DateTime.utc(2026, 1, 1 + i),
          open: 100.0 + i,
          high: 103.0 + i,
          low: 99.0 + i,
          close: 102.0 + i,
        ),
    ];
    final double price = 135, time = DateTime.utc(2026, 1, 31).chartValue;
    final double open = 135, high = 136, low = 134, close = 134.5;

    final ChartData candles = ChartData.from<Bar>(
      bars,
      x: (b) => b.time.chartValue,
      y: (b) => b.open,
      more: [(b) => b.high, (b) => b.low, (b) => b.close],
    );
    await tester.pumpWidget(host(CandleChart(candles: candles)));
    final ChartController chart = ChartScope.of(tester.element(find.byType(ChartGrid))).controller;
    // From the lowest low to the highest high, plus the policy's padding.
    expect(chart.view!.y.min, inInclusiveRange(95, 99));
    expect(chart.view!.y.max, inInclusiveRange(132, 136));

    chart.focus.value = ChartFocus(x: candles.x(10));
    await tester.pump();
    expect(find.text('O 110.0  H 113.0  L 109.0  C 112.0'), findsOneWidget);

    candles.setValue(candles.length - 1, price, column: 3); // the last candle is still trading
    candles.addRow(time, <double>[open, high, low, close]); // the next candle opens
    await tester.pump();
    final ChartHit last = chart.hitsAt(time).single;
    expect(last.datum, const ChartCandle(open: 135, high: 136, low: 134, close: 134.5));
    expect(chart.hitsAt(candles.x(29)).single.y, 135);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bars: lying, stacked, labelled, with a legend', (WidgetTester tester) async {
    final ChartController chart = ChartController();
    addTearDown(chart.dispose);
    final ChartData online = ChartData.fromValues(<double>[30, 45, 40, 60]);
    final ChartData retail = ChartData.fromValues(<double>[50, 40, 55, 45]);

    final List<ChartData> layers = ChartData.stacked(<ChartData>[online, retail]);

    await tester.pumpWidget(
      host(
        Chart(
          controller: chart,
          x: const LinearScale(range: FitDataRange(includeZero: true, padding: 0.1)),
          y: const BandScale(labels: <String>['Q1', 'Q2', 'Q3', 'Q4'], reversed: true),
          left: const <Widget>[ChartAxis()],
          top: const <Widget>[ChartLegend()],
          children: <Widget>[
            for (final (int i, String name) in <String>['Online', 'Retail'].indexed)
              BarSeries(
                data: layers[i],
                baseColumn: 1, // where the layer below ends
                direction: Axis.horizontal,
                label: name,
              ),
            // The size of every layer, written in its middle.
            ChartDataLabels(
              position: ChartDataLabelPosition.center,
              format: (ChartHit mark) => '${(mark.value - mark.base!).round()}',
            ),
            const ChartCrosshair(mode: ChartHitMode.nearestY), // picks a row
            const ChartTooltip(),
          ],
        ),
      ),
    );
    // One frame: the legend is complete, in the colours of the palette.
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Retail'), findsOneWidget);
    expect(find.text('Q1'), findsOneWidget);
    expect(chart.series[1].color!.toARGB32(), ChartThemeData.defaultPalette[1].toARGB32());
    // The values run along x, from zero to the longest stack with its padding.
    expect(chart.x.range.min, 0);
    expect(chart.x.range.max, closeTo(105 * 1.1, 1e-9));
    expect(chart.y.range, const ChartRange(-0.5, 3.5));

    // Q1 is the first row, at the top: 30 online, then 50 retail up to 80.
    final ChartView view = chart.view!;
    final List<ChartHit> row = chart.hitTest(
      Offset(view.size.width - 5, view.y.toPixel(0)),
      mode: ChartHitMode.nearestY,
    );
    expect(view.y.toPixel(0), lessThan(view.y.toPixel(3)));
    expect(row.map((ChartHit hit) => (hit.series?.label, hit.value, hit.base)), <Object>{
      ('Online', 30.0, 0.0),
      ('Retail', 80.0, 30.0),
    });

    // Eight layers, eight labels.
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    tester
        .renderObject(
          find.descendant(of: find.byType(ChartDataLabels), matching: find.byType(ChartPaint)),
        )
        .paint(TestRecordingPaintingContext(canvas), Offset.zero);
    expect(
      canvas.invocations.where((RecordedInvocation i) => i.invocation.memberName == #drawParagraph),
      hasLength(8),
    );

    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    final Offset plot = -view.chartRect.topLeft;
    await tester.sendEventToBinding(mouse.hover(plot + Offset(40, view.y.toPixel(2) + 3)));
    await tester.pump();
    expect(chart.focus.value?.y, 2);
    expect(find.text('Retail: '), findsOneWidget);
    expect(find.text('95'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('data: rows can be added at both ends', () {
    final List<({DateTime time, double celsius})> readings = <({DateTime time, double celsius})>[
      for (int i = 0; i < 150; i++) (time: DateTime.utc(2026, 1, 1, i), celsius: 20 + i % 7),
    ];
    final double x = DateTime.utc(2026, 1, 8).chartValue, y = 21;
    final List<double> xs = <double>[DateTime.utc(2025, 12, 31, 22).chartValue];
    final List<double> ys = <double>[19];

    final ChartData data = ChartData.from(
      readings,
      x: (r) => r.time.chartValue,
      y: (r) => r.celsius,
    );
    data.add(x, y); // live data: one notification, no widget rebuild
    data.prependAll(xs, ys); // older history
    data.removeFirst(100); // keep a window

    expect(data.length, 52);
    expect(data.isSorted, isTrue);
    expect(data.x(data.length - 1), x);
    // Row ordinals are stable: one row was prepended, then 100 removed.
    expect(data.firstOrdinal, 99);
  });

  testWidgets('pie, gauge and radar', (WidgetTester tester) async {
    final ChartData spending = ChartData.fromValues(<double>[1200, 640, 310]);
    final ChartData load = ChartData.fromValues(<double>[72]);
    final ChartData modelA = ChartData.fromValues(<double>[8, 6, 7, 4]);
    final ChartData modelB = ChartData.fromValues(<double>[5, 9, 6, 8]);
    final ChartController pie = ChartController();
    final ChartController gauge = ChartController();
    final ChartController radar = ChartController();
    addTearDown(pie.dispose);
    addTearDown(gauge.dispose);
    addTearDown(radar.dispose);
    // The samples, each with a controller to look at it by.
    Widget controlled(PolarChart chart, ChartController controller) => Expanded(
      child: PolarChart(
        controller: controller,
        angle: chart.angle,
        radius: chart.radius,
        startAngle: chart.startAngle,
        sweepAngle: chart.sweepAngle,
        innerRadius: chart.innerRadius,
        margin: chart.margin,
        bottom: chart.bottom,
        children: chart.children,
      ),
    );

    await tester.pumpWidget(
      host(
        size: const Size(900, 320),
        Row(
          children: <Widget>[
            controlled(
              // A doughnut with a total in its hole.
              PolarChart(
                innerRadius: 0.6,
                bottom: const <Widget>[ChartLegend()],
                children: <Widget>[
                  PieSeries(data: spending, labels: const <String>['Rent', 'Food', 'Fun'], gap: 2),
                  const ChartDataLabels(position: ChartDataLabelPosition.center),
                  const Center(child: Text('2,150')),
                  const ChartCrosshair.point(), // follows the slice under the pointer
                  const ChartTooltip(),
                ],
              ),
              pie,
            ),
            controlled(
              // A gauge: 72 of 100 on three quarters of a circle.
              PolarChart(
                angle: const LinearScale(range: FixedRange(0, 100)),
                startAngle: 0.75 * math.pi,
                sweepAngle: 1.5 * math.pi,
                innerRadius: 0.8,
                children: <Widget>[
                  RadialBarSeries(data: load, track: true, cap: StrokeCap.round),
                  const ChartPolarAxis.angle(inside: true),
                ],
              ),
              gauge,
            ),
            controlled(
              // A radar chart: the categories around, the values outwards.
              PolarChart(
                angle: const ChartScale.band(
                  labels: <String>['Speed', 'Range', 'Comfort', 'Price'],
                ),
                radius: const LinearScale(range: FixedRange(0, 10)),
                margin: const EdgeInsets.all(28), // room for the labels
                children: <Widget>[
                  const ChartPolarGrid(shape: ChartPolarGridShape.polygon),
                  const ChartPolarAxis.angle(),
                  RadarSeries(data: modelA, label: 'Model A'),
                  RadarSeries(data: modelB, label: 'Model B'),
                ],
              ),
              radar,
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // The doughnut: a legend item per slice on the first frame, three slices
    // that fill the circle, and the widget in the hole.
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Fun'), findsOneWidget);
    expect(find.text('2,150'), findsOneWidget);
    expect(pie.view!.scale(kChartAngle).range, const ChartRange(0, 2150));
    final List<ChartHit> slices = <ChartHit>[];
    pie.series.single.visitMarks(pie.view!, (ChartHit mark) {
      slices.add(mark);
      return true;
    });
    expect(slices.map((ChartHit mark) => mark.label), <String>['Rent', 'Food', 'Fun']);
    expect(
      slices.fold<double>(0, (double sum, ChartHit mark) => sum + mark.sector!.sweepAngle),
      closeTo(2 * math.pi, 1e-9),
    );
    expect(slices.first.sector!.innerRadius, closeTo(slices.first.sector!.outerRadius * 0.6, 1e-9));
    // Pointing at the first slice names it.
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    final Offset piePlot = tester.getTopLeft(
      find.ancestor(of: find.byType(PieSeries), matching: find.byType(ChartStack)),
    );
    await tester.sendEventToBinding(mouse.hover(piePlot + slices.first.position));
    await tester.pump();
    expect(find.text('Rent: '), findsOneWidget);
    expect(find.text('1200'), findsWidgets);

    // The gauge: 72 hundredths of three quarters of a circle, from the lower left.
    final List<ChartHit> bars = <ChartHit>[];
    gauge.series.single.visitMarks(gauge.view!, (ChartHit mark) {
      bars.add(mark);
      return true;
    });
    expect(bars.single.value, 72);
    expect(bars.single.sector!.startAngle, closeTo(0.75 * math.pi, 1e-9));
    expect(bars.single.sector!.sweepAngle, closeTo(0.72 * 1.5 * math.pi, 1e-9));

    // The radar: two series in two colours, hit at the same category.
    expect(radar.series.map((ChartSeries series) => series.label), <String>['Model A', 'Model B']);
    expect(radar.series[1].color, ChartThemeData.defaultPalette[1]);
    final ChartView view = radar.view!;
    final List<ChartHit> range = radar.hitTest(
      Offset(view.size.width / 2 + 40, view.size.height / 2),
      mode: ChartHitMode.nearest,
    );
    expect(range.map((ChartHit hit) => hit.value).toSet(), <double>{6, 9});
  });

  test('the README shows the code that is tested here', () {
    // Ignores layout: white space, and the commas the formatter adds and removes.
    String normalise(String s) =>
        s.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r',(?=[)\]}])|,$'), '');
    final String tested = normalise(File('test/readme_test.dart').readAsStringSync());
    final Iterable<RegExpMatch> samples = RegExp(
      r'```dart\n(.*?)```',
      dotAll: true,
    ).allMatches(File('README.md').readAsStringSync());
    expect(samples.length, 8);
    final List<String> untested = <String>[
      for (final RegExpMatch sample in samples)
        for (final String line in sample[1]!.split('\n'))
          if (!tested.contains(normalise(line))) line,
    ];
    expect(untested, isEmpty);
  });
}

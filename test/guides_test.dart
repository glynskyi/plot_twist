import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// The plot_twist examples of doc/coming_from_fl_chart.md and
// doc/coming_from_charts_flutter.md, compiled and run. The last test fails
// when a line of one of them is not in this file.

// ------------------------------------------------- coming_from_fl_chart.md

/// [readings] is created once and kept in state: `ChartData.fromXY(xs, ys)`.
Widget lineWithTooltip(ChartData readings) {
  return Chart(
    left: const <Widget>[ChartAxis()],
    bottom: const <Widget>[ChartAxis()],
    children: <Widget>[
      const ChartGrid(),
      LineSeries(data: readings, curve: .smooth),
      const ChartCrosshair(),
      ChartTooltip(
        builder: (BuildContext context, List<ChartHit> hits) => DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF263238)),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              hits.first.y.toStringAsFixed(1),
              style: const TextStyle(color: Color(0xFFFFFFFF)),
            ),
          ),
        ),
      ),
    ],
  );
}

/// One row per day at x = 0, 1, 2…: `ChartData.fromValues(values)`.
Widget rainAndTemperature(ChartData rain, ChartData temperature) {
  return Chart(
    x: const .band(),
    y: const .linear(range: .fit(padding: 0.1)), // temperature
    yScales: const <Object, ChartScale>{
      'rain': LinearScale(range: FitDataRange(includeZero: true)),
    },
    left: const <Widget>[ChartAxis()],
    right: const <Widget>[ChartAxis(scale: 'rain')],
    bottom: const <Widget>[ChartAxis()],
    children: <Widget>[
      const ChartGrid(),
      BarSeries(data: rain, yScale: 'rain', label: 'Rain'),
      LineSeries(data: temperature, label: 'Temperature'),
      const ChartCrosshair(),
      const ChartTooltip(), // one tooltip lists both series
    ],
  );
}

/// [prices]: x is `DateTime.chartValue` (milliseconds), y is the price.
Widget zoomablePrices(ChartData prices, ChartController chart) {
  return Chart(
    controller: chart, // chart.x.min, chart.x.max: the window, in data units
    x: const .time(limits: .data()), // tick units change as you zoom
    y: const .linear(range: .fitVisible()), // Y fits the visible data
    left: const <Widget>[ChartAxis()],
    bottom: const <Widget>[ChartAxis()],
    children: <Widget>[
      const ChartGrid(),
      LineSeries(data: prices),
      const ChartPanZoom(),
    ],
  );
}

/// The visible window, outside the chart. The chart itself is not rebuilt.
Widget visibleRange(ChartController chart) {
  return ListenableBuilder(
    listenable: chart.x,
    builder: (BuildContext context, Widget? child) =>
        Text('${TimeScale.dateOf(chart.x.min)} – ${TimeScale.dateOf(chart.x.max)}'),
  );
}

// -------------------------------------------- coming_from_charts_flutter.md

/// One row per sale, created once and kept in state:
/// `ChartData.from<Sale>(sales, x: (s) => s.day.chartValue, y: (s) => s.amount.toDouble())`.
Widget salesOverTime(ChartData sales, ChartController chart) {
  return ChartAppear(
    effect: .reveal,
    child: Chart(
      controller: chart,
      x: const .time(limits: .data()),
      y: const .linear(range: .fitVisible(padding: 0.1)), // not bound to zero
      left: const <Widget>[ChartAxis()],
      bottom: const <Widget>[ChartAxis()],
      children: <Widget>[
        const ChartGrid(),
        LineSeries(data: sales, label: 'Sales', fillColor: const Color(0x1A4E79A7)),
        const ChartPanZoom(),
        const ChartCrosshair(),
        const ChartTooltip(),
      ],
    ),
  );
}

/// What the user points at, outside the chart: a row of [sales], or null.
Widget selectedSale(ChartController chart, Widget Function(int? row) builder) {
  return ValueListenableBuilder<ChartFocus?>(
    valueListenable: chart.focus,
    builder: (BuildContext context, ChartFocus? focus, Widget? child) =>
        builder(focus == null ? null : chart.hitsFor(focus).firstOrNull?.index),
  );
}

/// [layers] is `ChartData.stacked([online, retail])`, created once and kept
/// in state. Each of the two has one row per quarter:
/// `ChartData.fromValues(amounts)`.
Widget revenueByChannel(List<ChartData> layers) {
  return ChartAppear(
    effect: .growX,
    child: Chart(
      x: const .linear(range: .fit(includeZero: true, padding: 0.1)),
      y: const .band(labels: <String>['Q1', 'Q2', 'Q3', 'Q4'], reversed: true),
      left: const <Widget>[ChartAxis()],
      bottom: const <Widget>[ChartAxis()],
      top: const <Widget>[ChartLegend()],
      children: <Widget>[
        const ChartGrid(horizontal: false),
        BarSeries(data: layers[0], baseColumn: 1, direction: .horizontal, label: 'Online'),
        BarSeries(data: layers[1], baseColumn: 1, direction: .horizontal, label: 'Retail'),
        // The size of every layer, written in its middle.
        ChartDataLabels(
          position: .center,
          format: (ChartHit mark) => '${(mark.value - mark.base!).round()}',
        ),
      ],
    ),
  );
}

/// [amounts] has one row per category: `ChartData.fromValues(values)`.
Widget spendingDoughnut(ChartData amounts, List<String> names) {
  return PolarChart(
    innerRadius: 0.6,
    bottom: const <Widget>[ChartLegend()],
    children: <Widget>[
      ChartAppear(
        effect: .reveal,
        child: PieSeries(data: amounts, labels: names),
      ),
      const ChartDataLabels(position: .center),
      const ChartCrosshair.point(), // follows the slice under the pointer
      const ChartTooltip(),
    ],
  );
}

/// The series the chart of [controller] lists, by label.
List<String?> _labels(ChartController controller) =>
    controller.series.map((ChartSeries series) => series.label).toList();

/// The chart below [root] that draws [series].
ChartController _chartOf(WidgetTester tester, Type series) =>
    ChartScope.of(tester.element(find.byType(series).first)).controller;

void main() {
  final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);

  testWidgets('fl_chart 1: a line with a tooltip that is a widget', (WidgetTester tester) async {
    final ChartData readings = ChartData.fromXY(<double>[0, 1, 2, 3], <double>[1, 3.25, 2, 4]);
    await tester.pumpWidget(host(lineWithTooltip(readings)));
    final ChartController chart = _chartOf(tester, LineSeries);
    final Offset plot = tester.getTopLeft(find.byType(ChartStack));
    await tester.sendEventToBinding(mouse.hover(plot + Offset(chart.view!.x.toPixel(1), 20)));
    await tester.pump();
    expect(find.text('3.3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fl_chart 2: bars and a line on two Y axes, one tooltip for both', (
    WidgetTester tester,
  ) async {
    final ChartData rain = ChartData.fromValues(<double>[4, 0, 12, 7]);
    final ChartData temperature = ChartData.fromValues(<double>[18, 21, 16, 19]);
    await tester.pumpWidget(host(rainAndTemperature(rain, temperature)));
    final ChartController chart = _chartOf(tester, LineSeries);
    expect(_labels(chart), <String>['Rain', 'Temperature']);
    expect(chart.scale('rain').range, const ChartRange(0, 12));
    expect(chart.y.min, lessThan(16));
    final Offset plot = tester.getTopLeft(find.byType(ChartStack));
    await tester.sendEventToBinding(mouse.hover(plot + Offset(chart.view!.x.toPixel(2), 20)));
    await tester.pump();
    expect(find.text('Rain: '), findsOneWidget);
    expect(find.text('Temperature: '), findsOneWidget);
  });

  testWidgets('fl_chart 3: a time series that zooms, and its window outside the chart', (
    WidgetTester tester,
  ) async {
    final ChartController chart = ChartController();
    addTearDown(chart.dispose);
    final DateTime start = DateTime(2026, 3);
    final ChartData prices = ChartData.fromXY(
      <double>[for (int day = 0; day < 60; day++) start.add(Duration(days: day)).chartValue],
      <double>[for (int day = 0; day < 60; day++) 100 + day % 7],
    );
    await tester.pumpWidget(
      host(
        Column(
          children: <Widget>[
            Expanded(child: zoomablePrices(prices, chart)),
            visibleRange(chart),
          ],
        ),
      ),
    );
    final String before = tester.widget<Text>(find.byType(Text).last).data!;
    expect(before, contains('2026-03-01'));
    // Zooming in changes the text, without a rebuild of the chart.
    chart.x.zoomBy(2);
    await tester.pump();
    expect(tester.widget<Text>(find.byType(Text).last).data, isNot(before));
    expect(chart.x.max - chart.x.min, lessThan(const Duration(days: 40).inMilliseconds));
  });

  testWidgets('charts_flutter 1: a time series with a selection that is read outside', (
    WidgetTester tester,
  ) async {
    final ChartController chart = ChartController();
    addTearDown(chart.dispose);
    final DateTime start = DateTime(2026, 3);
    final ChartData sales = ChartData.fromXY(
      <double>[for (int day = 0; day < 10; day++) start.add(Duration(days: day)).chartValue],
      <double>[for (int day = 0; day < 10; day++) 40.0 + 5 * day],
    );
    int? selected;
    await tester.pumpWidget(
      host(
        Column(
          children: <Widget>[
            Expanded(child: salesOverTime(sales, chart)),
            selectedSale(chart, (int? row) {
              selected = row;
              return const SizedBox();
            }),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(selected, isNull);
    // The y scale is not bound to zero: it fits the 40 to 85 that are in view.
    expect(chart.y.min, greaterThan(30));
    final Offset plot = tester.getTopLeft(find.byType(ChartStack));
    await tester.sendEventToBinding(
      mouse.hover(plot + Offset(chart.view!.x.toPixel(sales.x(3)), 30)),
    );
    await tester.pump();
    expect(selected, 3);
    expect(find.text('Sales: '), findsOneWidget);
    expect(find.text('55'), findsOneWidget);
  });

  testWidgets('charts_flutter 2: stacked bars that lie, with labels and a legend', (
    WidgetTester tester,
  ) async {
    final List<ChartData> layers = ChartData.stacked(<ChartData>[
      ChartData.fromValues(<double>[30, 45, 40, 60]),
      ChartData.fromValues(<double>[50, 40, 55, 45]),
    ]);
    await tester.pumpWidget(host(revenueByChannel(layers)));
    await tester.pump(const Duration(seconds: 1));
    final ChartController chart = _chartOf(tester, BarSeries);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Retail'), findsOneWidget);
    expect(find.text('Q1'), findsOneWidget);
    expect(chart.x.min, 0);
    final ChartView view = chart.view!;
    // The first quarter is on top: 30 online, then 50 retail up to 80.
    expect(view.y.toPixel(0), lessThan(view.y.toPixel(3)));
    final List<ChartHit> row = chart.hitTest(
      Offset(view.size.width - 5, view.y.toPixel(0)),
      mode: ChartHitMode.nearestY,
    );
    expect(row.map((ChartHit hit) => (hit.series?.label, hit.value, hit.base)).toSet(), <Object>{
      ('Online', 30.0, 0.0),
      ('Retail', 80.0, 30.0),
    });
  });

  testWidgets('charts_flutter 3: a doughnut with labels, a legend item per slice and a tooltip', (
    WidgetTester tester,
  ) async {
    final ChartData amounts = ChartData.fromValues(<double>[1200, 640, 310]);
    await tester.pumpWidget(host(spendingDoughnut(amounts, const <String>['Rent', 'Food', 'Fun'])));
    await tester.pump(const Duration(seconds: 1));
    final ChartController chart = _chartOf(tester, PieSeries);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Fun'), findsOneWidget);
    final List<ChartHit> slices = <ChartHit>[];
    chart.series.single.visitMarks(chart.view!, (ChartHit mark) {
      slices.add(mark);
      return true;
    });
    expect(slices, hasLength(3));
    expect(slices.first.sector!.innerRadius, closeTo(slices.first.sector!.outerRadius * 0.6, 1e-9));
    final Offset plot = tester.getTopLeft(find.byType(ChartStack));
    await tester.sendEventToBinding(mouse.hover(plot + slices[1].position));
    await tester.pump();
    expect(find.text('Food: '), findsOneWidget);
  });

  test('the guides show the code that is tested here', () {
    // Ignores layout: white space, and the commas the formatter adds and removes.
    String normalise(String s) =>
        s.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r',(?=[)\]}])|,$'), '');
    final String tested = normalise(File('test/guides_test.dart').readAsStringSync());
    final Map<String, int> examples = <String, int>{
      'doc/coming_from_fl_chart.md': 3,
      'doc/coming_from_charts_flutter.md': 3,
    };
    examples.forEach((String path, int count) {
      final Iterable<RegExpMatch> samples = RegExp(
        r'^plot_twist:\n\n```dart\n(.*?)```',
        dotAll: true,
        multiLine: true,
      ).allMatches(File(path).readAsStringSync());
      expect(samples.length, count, reason: path);
      final List<String> untested = <String>[
        for (final RegExpMatch sample in samples)
          for (final String line in sample[1]!.split('\n'))
            if (!tested.contains(normalise(line))) line,
      ];
      expect(untested, isEmpty, reason: path);
    });
  });
}

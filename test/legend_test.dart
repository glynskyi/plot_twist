import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

const List<Color> _palette = ChartThemeData.defaultPalette;
const Color _red = Color(0xFFFF0000);

/// The colours of the swatches of the legend, in order.
List<int> _swatches(WidgetTester tester) => <int>[
  for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
    find.descendant(of: find.byType(ChartLegend), matching: find.byType(DecoratedBox)),
  ))
    (box.decoration as BoxDecoration).color!.toARGB32(),
];

List<String> _texts(WidgetTester tester) => <String>[
  for (final Text text in tester.widgetList<Text>(
    find.descendant(of: find.byType(ChartLegend), matching: find.byType(Text)),
  ))
    text.data!,
];

void main() {
  final ChartData data = ChartData.fromValues(<double>[1, 3, 2, 4]);

  testWidgets('in a slot of the chart, it lists the series on the first frame', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          top: const <Widget>[ChartLegend()],
          children: <Widget>[
            LineSeries(data: data, label: 'North'),
            BarSeries(data: data, label: 'South', color: _red),
            // No label: not in the legend.
            LineSeries(data: data),
            const ChartReferenceLine.y(2),
            ScatterSeries(data: data, label: 'West'),
          ],
        ),
      ),
    );
    // One frame, and the legend is complete and has its room above the plot.
    expect(_texts(tester), <String>['North', 'South', 'West']);
    expect(_swatches(tester), <int>[
      _palette[0].toARGB32(),
      _red.toARGB32(),
      _palette[3].toARGB32(),
    ]);
    final Rect legend = tester.getRect(find.byType(ChartLegend));
    expect(legend.top, 0);
    expect(legend.width, 400);
    expect(legend.height, greaterThan(10));
    expect(c.view!.size.height, 300 - legend.height);
  });

  testWidgets('outside the chart it needs the controller, and is as complete', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Column(
          children: <Widget>[
            ChartLegend(controller: c),
            Expanded(
              child: Chart(
                controller: c,
                children: <Widget>[
                  LineSeries(data: data, label: 'North'),
                  LineSeries(data: data, label: 'South'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    expect(_texts(tester), <String>['North', 'South']);
    expect(_swatches(tester), <int>[_palette[0].toARGB32(), _palette[1].toARGB32()]);

    await tester.pumpWidget(host(const ChartLegend()));
    expect(tester.takeException(), isFlutterError);
  });

  testWidgets('a tap reports the series; a hidden series stays, dimmed', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final Set<Object> hidden = <Object>{};
    final List<Object?> pressed = <Object?>[];
    late StateSetter rebuild;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            rebuild = setState;
            return Chart(
              controller: c,
              bottom: <Widget>[
                ChartLegend(
                  onSeriesTap: (ChartSeries series) => rebuild(() {
                    hidden.contains(series.id) ? hidden.remove(series.id) : hidden.add(series.id!);
                  }),
                  onSeriesLongPress: (ChartSeries series) => pressed.add(series.id),
                ),
              ],
              children: <Widget>[
                for (final String name in <String>['North', 'South'])
                  LineSeries(data: data, id: name, label: name, visible: !hidden.contains(name)),
              ],
            );
          },
        ),
      ),
    );
    double opacityOf(String label) => tester
        .widget<Opacity>(find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first)
        .opacity;
    expect(opacityOf('South'), 1);

    await tester.tap(find.text('South'));
    await tester.pumpAndSettle();
    expect(hidden, <Object>{'South'});
    expect(c.seriesById('South')!.visible, isFalse);
    expect(_texts(tester), <String>['North', 'South']);
    expect(opacityOf('South'), lessThan(0.6));
    expect(opacityOf('North'), 1);

    // The swatch is part of the item.
    await tester.tap(find.byType(DecoratedBox).last);
    await tester.pumpAndSettle();
    expect(hidden, isEmpty);
    expect(opacityOf('South'), 1);

    await tester.longPress(find.text('North'));
    expect(pressed, <Object?>['North']);
  });

  testWidgets('it follows series that come, go and change', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    Widget build(List<String> names) => host(
      Chart(
        controller: c,
        top: const <Widget>[ChartLegend()],
        children: <Widget>[
          for (final String name in names)
            LineSeries(key: ValueKey<String>(name[0]), data: data, label: name),
        ],
      ),
    );
    await tester.pumpWidget(build(<String>['a', 'b']));
    expect(_texts(tester), <String>['a', 'b']);
    await tester.pumpWidget(build(<String>['c', 'a', 'b']));
    await tester.pump();
    expect(_texts(tester), <String>['c', 'a', 'b']);
    expect(_swatches(tester), <int>[for (int i = 0; i < 3; i++) _palette[i].toARGB32()]);
    await tester.pumpWidget(build(<String>['a2']));
    await tester.pump();
    expect(_texts(tester), <String>['a2']);
  });

  testWidgets('items wrap, and the plot gives way', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    Widget build(int count) => host(
      Chart(
        controller: c,
        top: const <Widget>[ChartLegend()],
        children: <Widget>[
          for (int i = 0; i < count; i++) LineSeries(data: data, label: 'Series number $i'),
        ],
      ),
    );
    await tester.pumpWidget(build(1));
    final double one = tester.getRect(find.byType(ChartLegend)).height;
    await tester.pumpWidget(build(6));
    await tester.pump();
    final double many = tester.getRect(find.byType(ChartLegend)).height;
    expect(many, greaterThan(one * 1.9));
    expect(c.view!.size.height, 300 - many);
  });

  testWidgets('beside the plot it is a column', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          right: const <Widget>[ChartLegend()],
          children: <Widget>[
            LineSeries(data: data, label: 'North'),
            LineSeries(data: data, label: 'South'),
          ],
        ),
      ),
    );
    final Rect north = tester.getRect(find.text('North'));
    final Rect south = tester.getRect(find.text('South'));
    expect(south.top, greaterThan(north.bottom - 1));
    expect(south.left, north.left);
    final Rect legend = tester.getRect(find.byType(ChartLegend));
    expect(legend.right, 400);
    expect(c.view!.size.width, 400 - legend.width);

    // In a row all the same, when asked.
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          top: const <Widget>[ChartLegend(direction: Axis.vertical)],
          children: <Widget>[
            LineSeries(data: data, label: 'North'),
            LineSeries(data: data, label: 'South'),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getRect(find.text('South')).top,
      greaterThan(tester.getRect(find.text('North')).top),
    );
  });

  testWidgets('itemBuilder builds the items', (WidgetTester tester) async {
    final List<ChartSeries> tapped = <ChartSeries>[];
    await tester.pumpWidget(
      host(
        Chart(
          top: <Widget>[
            ChartLegend(
              onSeriesTap: tapped.add,
              itemBuilder: (BuildContext context, ChartSeries series) =>
                  Text('[${series.label}]', key: ValueKey<Object?>(series.id)),
            ),
          ],
          children: <Widget>[LineSeries(data: data, id: 'n', label: 'North')],
        ),
      ),
    );
    expect(find.text('[North]'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsNothing);
    await tester.tap(find.text('[North]'));
    expect(tapped.single.id, 'n');
  });

  testWidgets('an item is a button to assistive technologies when it can be tapped', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        Chart(
          top: <Widget>[ChartLegend(onSeriesTap: (ChartSeries series) {})],
          children: <Widget>[LineSeries(data: data, label: 'North')],
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('North')),
      matchesSemantics(label: 'North', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}

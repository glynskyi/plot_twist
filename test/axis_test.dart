import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

void main() {
  testWidgets('axes take their room from the plot and show tick labels', (
    WidgetTester tester,
  ) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: controller,
          x: const LinearScale(range: FixedRange(0, 100)),
          y: const LinearScale(range: FixedRange(0, 50)),
          left: const <Widget>[ChartAxis()],
          bottom: const <Widget>[ChartAxis()],
          children: const <Widget>[ChartGrid()],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final ChartView view = controller.view!;
    final Size leftAxis = tester.getSize(find.byType(ChartAxis).first);
    final Size bottomAxis = tester.getSize(find.byType(ChartAxis).last);
    expect(leftAxis.width, greaterThan(0));
    expect(bottomAxis.height, greaterThan(0));
    // The plot is what is left over, and the axes are exactly as long as it.
    expect(view.size, Size(400 - leftAxis.width, 300 - bottomAxis.height));
    expect(leftAxis.height, view.size.height);
    expect(bottomAxis.width, view.size.width);
    expect(view.chartRect, Rect.fromLTWH(-leftAxis.width, 0, 400, 300));
    expect(find.text('50'), findsWidgets);
    expect(find.text('100'), findsOneWidget);

    // A tick label is centred on its value.
    final double x50 = leftAxis.width + view.x.toPixel(50);
    expect(tester.getCenter(find.text('50').last).dx, moreOrLessEquals(x50, epsilon: 0.5));
  });

  testWidgets('labels slide while panning and rebuild only when the tick set changes', (
    WidgetTester tester,
  ) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    int labelBuilds = 0;
    await tester.pumpWidget(
      host(
        Chart(
          controller: controller,
          x: const LinearScale(range: FixedRange(5, 105)),
          y: const LinearScale(range: FixedRange(0, 50)),
          bottom: <Widget>[
            ChartAxis(
              extent: const ChartAxisExtent.fixed(24),
              labelBuilder: (BuildContext context, ChartTick tick) {
                labelBuilds++;
                return Text('t${tick.label}');
              },
            ),
          ],
        ),
      ),
    );
    final int initial = labelBuilds;
    expect(initial, greaterThan(0));
    final double before = tester.getCenter(find.text('t50')).dx;

    // Pan without any tick entering or leaving: nothing is built.
    for (int i = 1; i <= 10; i++) {
      controller.x.jumpTo(5 + i * 1.0, 105 + i * 1.0);
      await tester.pump();
    }
    expect(labelBuilds, initial, reason: 'the tick set did not change');
    final double after = tester.getCenter(find.text('t50')).dx;
    expect(after, moreOrLessEquals(before - 40, epsilon: 1e-6));

    // Crossing a tick boundary changes the set and builds again.
    controller.x.jumpTo(30, 130);
    await tester.pump();
    expect(labelBuilds, greaterThan(initial));
    expect(find.text('t125'), findsOneWidget);
    expect(find.text('t25'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the gutter follows the width of the labels and layout converges', (
    WidgetTester tester,
  ) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    Widget build(double max) => host(
      Chart(
        controller: controller,
        x: const LinearScale(range: FixedRange(0, 10)),
        y: LinearScale(range: FixedRange(0, max)),
        left: const <Widget>[ChartAxis()],
        bottom: const <Widget>[ChartAxis()],
      ),
    );
    await tester.pumpWidget(build(50));
    final double narrow = tester.getSize(find.byType(ChartAxis).first).width;
    await tester.pumpWidget(build(5000000));
    final double wide = tester.getSize(find.byType(ChartAxis).first).width;
    expect(wide, greaterThan(narrow));
    // The plot and the bottom axis agree on the new width in the same frame.
    expect(controller.view!.size.width, 400 - wide);
    expect(tester.getSize(find.byType(ChartAxis).last).width, 400 - wide);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an axis marker follows its value', (WidgetTester tester) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: controller,
          x: const LinearScale(range: FixedRange(0, 100)),
          y: const LinearScale(range: FixedRange(0, 100)),
          left: <Widget>[
            ChartAxis(
              extent: const ChartAxisExtent.fixed(40),
              markers: <Widget>[
                ChartAxisMarker.resolve(
                  // The value at the left edge of a y = x line.
                  resolver: (ChartView view) => view.x.min,
                  child: const SizedBox(key: Key('marker'), width: 20, height: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final double plotHeight = controller.view!.size.height;
    // y = 0 is at the bottom of the plot; the marker is kept inside the axis.
    expect(markerCenter(tester).dy, plotHeight - 5);

    controller.x.jumpTo(50, 150);
    await tester.pump();
    expect(markerCenter(tester).dy, moreOrLessEquals(plotHeight / 2, epsilon: 1e-6));
  });
}

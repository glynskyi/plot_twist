import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

void main() {
  testWidgets('positions a widget at data coordinates', (WidgetTester tester) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: controller,
          x: const LinearScale(range: FixedRange(0, 100)),
          y: const LinearScale(range: FixedRange(0, 50)),
          children: const <Widget>[
            ChartPositioned(
              x: ChartAnchor.value(25),
              y: ChartAnchor.value(25),
              child: SizedBox(key: Key('marker'), width: 10, height: 10),
            ),
          ],
        ),
      ),
    );
    // Plot is 400x300; x=25 of 0..100 is 100 px, y=25 of 0..50 is the middle.
    expect(markerCenter(tester), const Offset(100, 150));

    controller.x.jumpTo(0, 50);
    await tester.pump();
    expect(markerCenter(tester), const Offset(200, 150));
    expect(controller.view!.x.max, 50);
  });

  testWidgets('panning moves widgets without building or laying them out', (
    WidgetTester tester,
  ) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    final Counter builds = Counter();
    final Counter layouts = Counter();
    final ChartData data = ChartData.generate(200, (int i) => (i.toDouble(), (i % 17).toDouble()));
    await tester.pumpWidget(
      host(
        Chart(
          controller: controller,
          x: const LinearScale(range: FixedRange(0, 100)),
          y: const LinearScale(range: FixedRange(0, 20)),
          children: <Widget>[
            LineSeries(data: data),
            for (int i = 0; i < 30; i++)
              ChartPositioned(
                x: ChartAnchor.value(i * 10.0),
                y: const ChartAnchor.value(10),
                overflow: ChartOverflow.visible,
                child: CountingBox(builds: builds, layouts: layouts, key: ValueKey<int>(i)),
              ),
          ],
        ),
      ),
    );
    final int buildsBefore = builds.value;
    final int layoutsBefore = layouts.value;
    final Offset before = tester.getCenter(find.byKey(const ValueKey<int>(3)));

    for (int frame = 1; frame <= 120; frame++) {
      controller.x.jumpTo(frame * 0.5, 100 + frame * 0.5);
      await tester.pump();
    }

    expect(builds.value, buildsBefore, reason: 'no widget may be rebuilt by a pan');
    expect(layouts.value, layoutsBefore, reason: 'markers keep their layout, only move');
    final Offset after = tester.getCenter(find.byKey(const ValueKey<int>(3)));
    // Window moved by 60 units of 100 over 400 px.
    expect(after.dx, moreOrLessEquals(before.dx - 240, epsilon: 1e-6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lazy builder works under Padding and rebuilds only on selected change', (
    WidgetTester tester,
  ) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    final List<int> built = <int>[];
    await tester.pumpWidget(
      host(
        Chart(
          controller: controller,
          x: const LinearScale(range: FixedRange(0, 10)),
          y: const LinearScale(range: FixedRange(0, 10)),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                child: ChartLayoutBuilder<int>(
                  // Depends only on the whole-number part of the window start.
                  selector: (ChartView view) => view.x.min.floor(),
                  builder: (BuildContext context, int value) {
                    built.add(value);
                    return Text('$value', textDirection: TextDirection.ltr);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    expect(built, <int>[0]);

    controller.x.jumpTo(0.2, 10.2);
    await tester.pump();
    controller.x.jumpTo(0.7, 10.7);
    await tester.pump();
    expect(built, <int>[0], reason: 'selected value did not change');

    controller.x.jumpTo(1.1, 11.1);
    await tester.pump();
    expect(built, <int>[0, 1]);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a derived overlay stays pinned to the plot edge while panning', (
    WidgetTester tester,
  ) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    // y = x, so the line crosses the left edge at y == visible min x.
    final ChartData data = ChartData.generate(101, (int i) => (i.toDouble(), i.toDouble()));
    await tester.pumpWidget(
      host(
        Chart(
          controller: controller,
          x: const LinearScale(range: FixedRange(0, 50)),
          y: const LinearScale(range: FixedRange(0, 100)),
          children: <Widget>[
            LineSeries(data: data, id: 'line'),
            ChartPositioned.resolve(
              position: (ChartView view) {
                final double x = view.x.min;
                final double? y = controller.seriesById('line')?.valueAt(x);
                return y == null ? null : view.toPixel(x, y);
              },
              overflow: ChartOverflow.visible,
              child: const SizedBox(key: Key('marker'), width: 8, height: 8),
            ),
          ],
        ),
      ),
    );
    // At x=0 the line is at y=0: bottom-left corner of the 400x300 plot.
    expect(markerCenter(tester), const Offset(0, 300));

    controller.x.jumpTo(20, 70);
    await tester.pump();
    // Still on the left edge; the line is now at y=20 → 20% up.
    expect(markerCenter(tester).dx, 0);
    expect(markerCenter(tester).dy, moreOrLessEquals(240, epsilon: 1e-6));
  });

  testWidgets('automatic ranges fit the series data', (WidgetTester tester) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    final ChartData data = ChartData.fromXY(<double>[2, 4, 6], <double>[10, 30, 20]);
    await tester.pumpWidget(
      host(
        Chart(
          controller: controller,
          children: <Widget>[LineSeries(data: data)],
        ),
      ),
    );
    expect(controller.x.range, const ChartRange(2, 6));
    expect(controller.y.range, const ChartRange(10, 30));

    data.add(8, 50);
    await tester.pump();
    expect(controller.x.range, const ChartRange(2, 8));
    expect(controller.y.range, const ChartRange(10, 50));

    // Once the user has taken over, new data no longer moves the window.
    controller.x.jumpTo(3, 5);
    data.add(10, 5);
    await tester.pump();
    expect(controller.x.range, const ChartRange(3, 5));
    expect(controller.y.range, const ChartRange(5, 50));
  });

  testWidgets('a rebuild with an equal scale keeps the user window', (WidgetTester tester) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    Widget build() => host(
      Chart(
        controller: controller,
        // Deliberately not const: a new, equal instance on every build.
        x: LinearScale(range: FixedRange(0, 100)),
        children: const <Widget>[],
      ),
    );
    await tester.pumpWidget(build());
    controller.x.jumpTo(40, 60);
    await tester.pumpWidget(build());
    expect(controller.x.range, const ChartRange(40, 60));
    expect(controller.x.isAuto, isFalse);

    // A different policy takes over again.
    await tester.pumpWidget(
      host(
        Chart(
          controller: controller,
          x: const LinearScale(range: FixedRange(0, 10)),
          children: const <Widget>[],
        ),
      ),
    );
    expect(controller.x.range, const ChartRange(0, 10));
  });

  testWidgets('the line series paints a path', (WidgetTester tester) async {
    final ChartData data = ChartData.fromXY(<double>[0, 1, 2], <double>[0, 1, 0]);
    await tester.pumpWidget(host(Chart(children: <Widget>[LineSeries(data: data)])));
    final RenderObject paint = tester.renderObject(find.byType(ChartPaint));
    expect(paint, paints..path());
  });

  testWidgets('listeners may call setState when a scale changes during build', (
    WidgetTester tester,
  ) async {
    final ChartController controller = ChartController();
    addTearDown(controller.dispose);
    int notifications = 0;
    controller.y.addListener(() => notifications++);
    final ChartData data = ChartData.fromXY(<double>[0, 1], <double>[0, 1]);
    await tester.pumpWidget(
      host(
        ListenableBuilder(
          listenable: controller.y,
          builder: (BuildContext context, Widget? child) => Chart(
            controller: controller,
            children: <Widget>[LineSeries(data: data)],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(notifications, greaterThan(0));
  });
}

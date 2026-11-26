import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

const ChartScale _x = LinearScale(range: FixedRange(0, 100));
const ChartScale _y = LinearScale(range: FixedRange(0, 100));

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(800, 600)),
    child: child,
  ),
);

Future<void> _drag(WidgetTester tester, Offset from, Offset slop, Offset rest) async {
  final TestGesture gesture = await tester.startGesture(from);
  await gesture.moveBy(slop);
  await gesture.moveBy(rest);
  await gesture.up();
  // Also lets the double-tap recognizer's minimum-time timer run out.
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('a horizontal drag pans x and leaves y alone', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(controller: c, x: _x, y: _y, children: const <Widget>[ChartPanZoom(inertia: false)]),
      ),
    );
    await _drag(tester, const Offset(200, 150), const Offset(-20, 0), const Offset(-80, 0));
    // 80 px of 400 over 100 units; the slop is not applied as a jump.
    expect(c.x.min, moreOrLessEquals(20, epsilon: 1e-9));
    expect(c.x.max, moreOrLessEquals(120, epsilon: 1e-9));
    expect(c.y.range, const ChartRange(0, 100));
    expect(c.x.isAuto, isFalse);
  });

  testWidgets('a tap does not move the chart', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(Chart(controller: c, x: _x, y: _y, children: const <Widget>[ChartPanZoom()])),
    );
    await tester.tapAt(const Offset(200, 150));
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.x.isAuto, isTrue);
    expect(c.x.range, const ChartRange(0, 100));
  });

  testWidgets('a double tap returns the scales to automatic', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(controller: c, x: _x, y: _y, children: const <Widget>[ChartPanZoom(inertia: false)]),
      ),
    );
    for (final PointerDeviceKind kind in <PointerDeviceKind>[
      PointerDeviceKind.touch,
      PointerDeviceKind.mouse,
    ]) {
      await _drag(tester, const Offset(200, 150), const Offset(-20, 0), const Offset(-80, 0));
      expect(c.x.isAuto, isFalse);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(200, 150), kind: kind);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(200, 150), kind: kind);
      await tester.pumpAndSettle();
      expect(c.x.isAuto, isTrue, reason: '$kind');
      expect(c.x.range, const ChartRange(0, 100), reason: '$kind');
    }
  });

  testWidgets('2D pan moves both scales', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: _x,
          y: _y,
          children: const <Widget>[ChartPanZoom(panY: true, inertia: false)],
        ),
      ),
    );
    await _drag(tester, const Offset(200, 150), const Offset(-20, 0), const Offset(-40, 30));
    expect(c.x.min, moreOrLessEquals(10, epsilon: 1e-9));
    // Dragging down by 30 of 300 px shows values 10 units higher.
    expect(c.y.min, moreOrLessEquals(10, epsilon: 1e-9));
    expect(c.y.max, moreOrLessEquals(110, epsilon: 1e-9));
  });

  testWidgets('a pinch zooms around the fingers', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(Chart(controller: c, x: _x, y: _y, children: const <Widget>[ChartPanZoom()])),
    );
    final TestGesture a = await tester.startGesture(const Offset(150, 150), pointer: 1);
    final TestGesture b = await tester.startGesture(const Offset(250, 150), pointer: 2);
    await a.moveBy(const Offset(-50, 0));
    await b.moveBy(const Offset(50, 0));
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 50));
    // Fingers went from 100 px apart to 200 px apart around x = 200 px (value 50).
    expect(c.x.min, moreOrLessEquals(25, epsilon: 1e-6));
    expect(c.x.max, moreOrLessEquals(75, epsilon: 1e-6));
    expect(c.y.range, const ChartRange(0, 100));
  });

  testWidgets('inside a vertical list: vertical drags scroll the list, horizontal pan the chart', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    final ScrollController scroll = ScrollController();
    addTearDown(c.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _app(
        ListView(
          controller: scroll,
          children: <Widget>[
            SizedBox(
              height: 300,
              child: Chart(
                controller: c,
                x: _x,
                y: _y,
                children: const <Widget>[ChartPanZoom(inertia: false)],
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await _drag(tester, const Offset(200, 150), const Offset(0, -20), const Offset(0, -80));
    expect(scroll.offset, greaterThan(50));
    expect(c.x.range, const ChartRange(0, 100));
    scroll.jumpTo(0);
    await tester.pump();

    await _drag(tester, const Offset(200, 150), const Offset(-20, 0), const Offset(-80, 0));
    expect(scroll.offset, 0);
    expect(c.x.min, greaterThan(5));

    // A pinch goes to the chart even though the list is listening too.
    c.x.jumpTo(0, 100);
    await tester.pump();
    final TestGesture a = await tester.startGesture(const Offset(350, 140), pointer: 1);
    final TestGesture b = await tester.startGesture(const Offset(450, 160), pointer: 2);
    await a.moveBy(const Offset(-40, -30));
    await b.moveBy(const Offset(40, 30));
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(scroll.offset, 0);
    expect(c.x.max - c.x.min, lessThan(100));
  });

  testWidgets('inside a PageView: the chart pans, and yields only at its limits', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    final PageController pages = PageController();
    addTearDown(c.dispose);
    addTearDown(pages.dispose);
    Widget build({required bool yieldAtLimits}) => _app(
      PageView(
        controller: pages,
        children: <Widget>[
          Chart(
            controller: c,
            x: const LinearScale(range: FixedRange(0, 100), limits: ChartLimits(min: 0, max: 200)),
            y: _y,
            children: <Widget>[ChartPanZoom(inertia: false, yieldAtLimits: yieldAtLimits)],
          ),
          const SizedBox.expand(),
        ],
      ),
    );
    await tester.pumpWidget(build(yieldAtLimits: true));
    // There is room to pan towards larger values: the chart takes the drag.
    await _drag(tester, const Offset(400, 300), const Offset(-20, 0), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(pages.page, 0);
    expect(c.x.min, greaterThan(10));

    // At the right limit the drag is handed to the PageView.
    c.x.jumpTo(100, 200);
    await tester.pump();
    await _drag(tester, const Offset(400, 300), const Offset(-20, 0), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(pages.page, 1);
  });

  testWidgets('the mouse wheel zooms around the pointer and yields at the zoom limit', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    final ScrollController scroll = ScrollController();
    addTearDown(c.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _app(
        ListView(
          controller: scroll,
          children: <Widget>[
            SizedBox(
              height: 300,
              child: Chart(
                controller: c,
                x: const LinearScale(
                  range: FixedRange(0, 100),
                  limits: ChartLimits(minSpan: 20, maxSpan: 100),
                ),
                y: _y,
                children: const <Widget>[ChartPanZoom()],
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(200, 150)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -300)));
    await tester.pump();
    // Zoomed in by e around x = 25 (200 of 800 px); the list did not scroll.
    final double span = 100 / math.e;
    expect(c.x.max - c.x.min, moreOrLessEquals(span, epsilon: 1e-6));
    expect(c.x.min, moreOrLessEquals(25 - span * 0.25, epsilon: 1e-6));
    expect(scroll.offset, 0);

    // Zooming out past the limit does nothing, so the list takes the wheel.
    c.x.jumpTo(0, 100);
    await tester.pump();
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
    await tester.pump();
    expect(c.x.range, const ChartRange(0, 100));
    expect(scroll.offset, greaterThan(0));
  });

  testWidgets('lifting a moving finger flings', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 300,
            child: Chart(controller: c, x: _x, y: _y, children: const <Widget>[ChartPanZoom()]),
          ),
        ),
      ),
    );
    await tester.flingFrom(const Offset(300, 150), const Offset(-150, 0), 1500);
    final double atRelease = c.x.min;
    expect(atRelease, greaterThan(0));
    expect(c.x.isInteracting, isTrue);
    await tester.pump(); // The ticker takes its start time from this frame.
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.x.min, greaterThan(atRelease), reason: 'the fling keeps moving the window');
    await tester.pumpAndSettle();
    expect(c.x.isInteracting, isFalse);
  });

  testWidgets('dragging on an axis zooms only that scale', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: _x,
          y: _y,
          left: const <Widget>[ChartAxis(extent: ChartAxisExtent.fixed(40))],
          children: const <Widget>[ChartPanZoom()],
        ),
      ),
    );
    await _drag(tester, const Offset(20, 150), const Offset(0, -20), const Offset(0, -80));
    final double span = 100 / math.exp(80 / 160);
    expect(c.y.max - c.y.min, moreOrLessEquals(span, epsilon: 1e-6));
    expect(c.x.range, const ChartRange(0, 100));
  });

  testWidgets('a trackpad gesture pans and zooms', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(controller: c, x: _x, y: _y, children: const <Widget>[ChartPanZoom(inertia: false)]),
      ),
    );
    final TestGesture pad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await pad.panZoomStart(const Offset(200, 150));
    await pad.panZoomUpdate(const Offset(200, 150), pan: const Offset(-30, 0));
    await pad.panZoomUpdate(const Offset(200, 150), pan: const Offset(-110, 0));
    await pad.panZoomEnd();
    await tester.pump();
    // Alone in the gesture arena, the trackpad pans from the first pixel.
    expect(c.x.min, moreOrLessEquals(27.5, epsilon: 1e-9));

    c.x.jumpTo(0, 100);
    await pad.panZoomStart(const Offset(200, 150));
    await pad.panZoomUpdate(const Offset(200, 150), scale: 1.2);
    await pad.panZoomUpdate(const Offset(200, 150), scale: 2.4);
    await pad.panZoomEnd();
    await tester.pump();
    expect(c.x.max - c.x.min, moreOrLessEquals(100 / 2.4, epsilon: 1e-6));
  });

  testWidgets('a drag that starts on an interactive marker still pans; its tap still works', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    int taps = 0;
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: _x,
          y: _y,
          children: <Widget>[
            const ChartPanZoom(inertia: false, doubleTapToReset: false),
            ChartPositioned(
              x: const ChartAnchor.value(50),
              y: const ChartAnchor.value(50),
              child: GestureDetector(
                onTap: () => taps++,
                child: const ColoredBox(
                  color: Color(0xFF00FF00),
                  child: SizedBox(width: 40, height: 40),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(200, 150));
    await tester.pump();
    expect(taps, 1);
    expect(c.x.range, const ChartRange(0, 100));

    await _drag(tester, const Offset(200, 150), const Offset(-20, 0), const Offset(-80, 0));
    expect(taps, 1);
    expect(c.x.min, moreOrLessEquals(20, epsilon: 1e-9));
  });

  testWidgets('removing ChartPanZoom in the middle of a drag releases its scales', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    Widget chart({required bool panZoom}) => host(
      Chart(
        controller: c,
        x: _x,
        y: _y,
        children: <Widget>[if (panZoom) const ChartPanZoom(panY: true)],
      ),
    );
    await tester.pumpWidget(chart(panZoom: true));
    final TestGesture gesture = await tester.startGesture(const Offset(200, 150));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(c.x.isInteracting, isTrue);
    expect(c.y.isInteracting, isTrue);

    // For example, a setting that turns panning off while a finger is down.
    await tester.pumpWidget(chart(panZoom: false));
    expect(c.x.isInteracting, isFalse);
    expect(c.y.isInteracting, isFalse);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chart without behaviors is transparent to pointers', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++),
            ),
            const Positioned.fill(child: Chart()),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);
  });
}

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// In the 400 x 300 host, a value of 1 is 4 px along x and 3 px along y.
const ChartScale _x = LinearScale(range: FixedRange(0, 100));
const ChartScale _y = LinearScale(range: FixedRange(0, 100));
const Color _red = Color(0xFFFF0000);
const List<Color> _palette = ChartThemeData.defaultPalette;

List<RecordedInvocation> _callsOf(RenderObject object) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  object.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return canvas.invocations
      .where(
        (RecordedInvocation i) =>
            i.invocation.memberName == #drawLine || i.invocation.memberName == #drawRawPoints,
      )
      .toList();
}

/// The render object of the line of the first reference line.
RenderObject _line(WidgetTester tester) => tester.renderObject(
  find.descendant(of: find.byType(ChartReferenceLine), matching: find.byType(ChartPaint)),
);

void main() {
  final ChartData data = ChartData.fromXY(<double>[0, 50, 100], <double>[10, 20, 15]);

  testWidgets('a line at a y value runs across the plot', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        const Chart(
          x: _x,
          y: _y,
          children: <Widget>[ChartReferenceLine.y(40, color: _red, width: 3)],
        ),
      ),
    );
    final Invocation call = _callsOf(_line(tester)).single.invocation;
    expect(call.memberName, #drawLine);
    expect(call.positionalArguments[0], const Offset(0, 180));
    expect(call.positionalArguments[1], const Offset(400, 180));
    final Paint paint = call.positionalArguments[2] as Paint;
    expect(paint.color.toARGB32(), _red.toARGB32());
    expect(paint.strokeWidth, 3);
  });

  testWidgets('a line at an x value runs from top to bottom, on the scale it names', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Chart(
          x: _x,
          y: _y,
          xScales: <Object, ChartScale>{'top': LinearScale(range: FixedRange(0, 10))},
          children: <Widget>[ChartReferenceLine.x(2.5, scale: 'top')],
        ),
      ),
    );
    final Invocation call = _callsOf(_line(tester)).single.invocation;
    expect(call.positionalArguments[0], const Offset(100, 0));
    expect(call.positionalArguments[1], const Offset(100, 300));
  });

  testWidgets('a dashed line, and nothing outside the window', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          x: _x,
          y: _y,
          children: const <Widget>[
            ChartReferenceLine.y(40, dash: <double>[6, 4], label: Text('limit')),
          ],
        ),
      ),
    );
    final Invocation call = _callsOf(_line(tester)).single.invocation;
    expect(call.memberName, #drawRawPoints);
    final Float32List points = call.positionalArguments[1] as Float32List;
    expect(points.length, 40 * 4);
    expect(<double>[points[0], points[1], points[2], points[3]], <double>[0, 180, 6, 180]);
    expect(find.text('limit').hitTestable(), findsOneWidget);

    c.y.jumpTo(50, 150);
    await tester.pump();
    expect(_callsOf(_line(tester)), isEmpty);
    expect(
      tester.getRect(find.text('limit')).overlaps(const Rect.fromLTWH(0, 0, 400, 300)),
      isTrue,
    );
    expect(tester.renderObject(find.text('limit')).debugNeedsPaint, isFalse);
    expect(find.text('limit').hitTestable(), findsNothing);
  });

  testWidgets('includeInRange widens an automatic range to the line', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    Widget build({required bool include, double value = 50, ChartScale y = const LinearScale()}) =>
        host(
          Chart(
            controller: c,
            y: y,
            children: <Widget>[
              LineSeries(data: data),
              ChartReferenceLine.y(value, includeInRange: include),
            ],
          ),
        );
    await tester.pumpWidget(build(include: false));
    expect(c.y.range.max, lessThan(30));

    await tester.pumpWidget(build(include: true));
    await tester.pump();
    expect(c.y.range.max, greaterThanOrEqualTo(50));
    expect(c.x.range.min, lessThanOrEqualTo(0));
    expect(c.x.range.max, greaterThanOrEqualTo(100));

    await tester.pumpWidget(build(include: true, value: 80));
    await tester.pump();
    expect(c.y.range.max, greaterThanOrEqualTo(80));

    // A value the scale cannot show is not included.
    await tester.pumpWidget(build(include: true, value: 0, y: const LogScale()));
    await tester.pump();
    expect(c.y.range.min, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reference line is no series: no legend entry, no palette colour', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          children: <Widget>[
            LineSeries(data: data, id: 'a'),
            const ChartReferenceLine.y(15, includeInRange: true),
            LineSeries(data: data, id: 'b'),
          ],
        ),
      ),
    );
    expect(c.series.map((ChartSeries s) => s.id), <String>['a', 'b']);
    expect(c.series[1].color!.toARGB32(), _palette[1].toARGB32());
    expect(c.hitsAt(50), hasLength(2));
  });

  group('the label', () {
    Future<void> pump(WidgetTester tester, Widget line, {ChartController? controller}) => tester
        .pumpWidget(host(Chart(controller: controller, x: _x, y: _y, children: <Widget>[line])));
    const Widget label = SizedBox(key: Key('label'), width: 40, height: 10);
    Rect rect(WidgetTester tester) => tester.getRect(find.byKey(const Key('label')));

    testWidgets('of a y line sits above its right end by default', (WidgetTester tester) async {
      await pump(
        tester,
        const ChartReferenceLine.y(40, label: label, labelPadding: EdgeInsets.zero),
      );
      expect(rect(tester), const Rect.fromLTWH(360, 170, 40, 10));
    });

    testWidgets('of a y line can sit at the left, below or on the line', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const ChartReferenceLine.y(
          40,
          label: label,
          labelAlignment: Alignment.bottomLeft,
          labelPadding: EdgeInsets.zero,
        ),
      );
      expect(rect(tester), const Rect.fromLTWH(0, 180, 40, 10));
      await pump(
        tester,
        const ChartReferenceLine.y(
          40,
          label: label,
          labelAlignment: Alignment.center,
          labelPadding: EdgeInsets.zero,
        ),
      );
      expect(rect(tester), const Rect.fromLTWH(180, 175, 40, 10));
    });

    testWidgets('of an x line sits at the top, right of the line by default', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const ChartReferenceLine.x(25, label: label, labelPadding: EdgeInsets.zero),
      );
      expect(rect(tester), const Rect.fromLTWH(100, 0, 40, 10));
      await pump(
        tester,
        const ChartReferenceLine.x(
          25,
          label: label,
          labelAlignment: Alignment.bottomLeft,
          labelPadding: EdgeInsets.zero,
        ),
      );
      expect(rect(tester), const Rect.fromLTWH(60, 290, 40, 10));
    });

    testWidgets('has padding, the style of axis labels and stays inside the plot', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      await pump(tester, const ChartReferenceLine.y(40, label: Text('limit')), controller: c);
      final Rect text = tester.getRect(find.text('limit'));
      expect(text.right, 396);
      expect(text.bottom, 176);
      final RichText rich = tester.widget(
        find.descendant(of: find.text('limit'), matching: find.byType(RichText)),
      );
      expect(rich.text.style?.fontSize, 11);

      // Near the top there is no room above the line: the label goes below.
      c.y.jumpTo(0, 41);
      await tester.pump();
      final double line = c.view!.y.toPixel(40);
      expect(line, lessThan(10));
      expect(tester.getRect(find.text('limit')).top, greaterThanOrEqualTo(line));
    });

    testWidgets('follows the line without being rebuilt', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final Counter builds = Counter();
      final Counter layouts = Counter();
      await pump(
        tester,
        ChartReferenceLine.y(
          40,
          label: CountingBox(builds: builds, layouts: layouts),
          labelPadding: EdgeInsets.zero,
        ),
        controller: c,
      );
      final double before = tester.getRect(find.byType(CountingBox)).bottom;
      expect(before, 180);
      c.y.jumpTo(10, 110);
      await tester.pump();
      expect(tester.getRect(find.byType(CountingBox)).bottom, 210);
      expect(builds.value, 1);
    });
  });

  group('ChartPaint(listed: false)', () {
    testWidgets('counts for ranges and hits, but is not one of the series', (
      WidgetTester tester,
    ) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      final ChartData high = ChartData.fromXY(<double>[0, 100], <double>[500, 600]);
      Widget build({required bool listed}) => host(
        Chart(
          controller: c,
          children: <Widget>[
            LineSeries(data: data, id: 'a'),
            ChartPaint(
              painter: LineSeriesPainter(data: high),
              id: 'helper',
              listed: listed,
            ),
            LineSeries(data: data, id: 'b'),
          ],
        ),
      );
      await tester.pumpWidget(build(listed: false));
      expect(c.series.map((ChartSeries s) => s.id), <String>['a', 'b']);
      expect(c.seriesById('helper'), isNotNull);
      expect(c.seriesById('helper')!.listed, isFalse);
      expect(c.y.range.max, greaterThanOrEqualTo(600));
      expect(c.hitsAt(0).map((ChartHit h) => h.series?.id), contains('helper'));
      expect(c.series[1].color!.toARGB32(), _palette[1].toARGB32());

      // Listing it moves the series after it along the palette.
      await tester.pumpWidget(build(listed: true));
      expect(c.series.map((ChartSeries s) => s.id), <String>['a', 'helper', 'b']);
      expect(c.series[2].color!.toARGB32(), _palette[2].toARGB32());
    });
  });
}

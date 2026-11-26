import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// In the 400 x 300 host a polar chart is a circle of radius 150 around
// (200, 150). The slices of [_three] are a quarter from twelve to three
// o'clock, a quarter from three to six, and the left half.
const int _white = 0xFFFFFFFF;
const Color _red = Color(0xFFFF0000);
const Color _green = Color(0xFF00FF00);
const Color _blue = Color(0xFF0000FF);
const List<Color> _colors = <Color>[_red, _green, _blue];
const Offset _centre = Offset(200, 150);
const TextStyle _style = TextStyle(fontSize: 10, height: 1, color: Color(0xFF000000));

ChartData _three() => ChartData.fromValues(<double>[1, 1, 2]);

Color? _colorOf(int index, double value) => _colors[index % 3];

PieSeries _pie(
  ChartData data, {
  List<String>? labels,
  double gap = 0,
  double cornerRadius = 0,
  double Function(int index)? offsetOf,
}) => PieSeries(
  data: data,
  labels: labels,
  colorOf: _colorOf,
  gap: gap,
  cornerRadius: cornerRadius,
  offsetOf: offsetOf,
  isolate: false,
);

/// The point at [degrees] clockwise from three o'clock, [radius] from the
/// centre.
Offset _at(double degrees, double radius) =>
    _centre + Offset(math.cos(degrees * math.pi / 180), math.sin(degrees * math.pi / 180)) * radius;

/// Where the labels layer of the chart draws its texts.
List<Rect> _labels(WidgetTester tester) {
  final RenderObject layer = tester.renderObject(
    find.descendant(of: find.byType(ChartDataLabels), matching: find.byType(ChartPaint)),
  );
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  layer.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return <Rect>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawParagraph)
        (call.invocation.positionalArguments[1] as Offset) &
            Size(
              (call.invocation.positionalArguments[0] as ui.Paragraph).longestLine,
              (call.invocation.positionalArguments[0] as ui.Paragraph).height,
            ),
  ];
}

Matcher _near(Offset point) => within<Offset>(distance: 0.01, from: point);

void main() {
  testWidgets('slices follow each other clockwise from twelve o\'clock, as wide as their values', (
    WidgetTester tester,
  ) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(children: <Widget>[_pie(_three())]),
    );
    expect(pixel(250, 100), _red.toARGB32());
    expect(pixel(205, 10), _red.toARGB32(), reason: 'it starts at twelve o\'clock');
    expect(pixel(250, 200), _green.toARGB32());
    expect(pixel(150, 150), _blue.toARGB32());
    expect(pixel(195, 10), _blue.toARGB32());
    expect(pixel(205, 145), _red.toARGB32(), reason: 'a full pie reaches the centre');
    expect(pixel(20, 20), _white, reason: 'outside the circle');
  });

  testWidgets('each slice takes the next colour of the palette', (WidgetTester tester) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(children: <Widget>[PieSeries(data: _three(), isolate: false)]),
    );
    expect(pixel(250, 100), ChartThemeData.defaultPalette[0].toARGB32());
    expect(pixel(250, 200), ChartThemeData.defaultPalette[1].toARGB32());
    expect(pixel(150, 150), ChartThemeData.defaultPalette[2].toARGB32());
  });

  testWidgets('the inner radius of the chart is the hole of a doughnut', (
    WidgetTester tester,
  ) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(innerRadius: 0.5, children: <Widget>[_pie(_three())]),
    );
    expect(pixel(200, 150), _white);
    expect(pixel(250, 110), _white, reason: '64 px from the centre, inside the hole of 75');
    expect(pixel(300, 100), _red.toARGB32());
  });

  testWidgets('a row without a positive value has no slice', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(
        controller: c,
        children: <Widget>[
          PieSeries(
            data: ChartData.fromValues(<double>[1, double.nan, 0, -3, 1]),
            colorOf: (int index, double value) => index == 0 ? _red : _blue,
            labels: const <String>['a', 'b', 'c', 'd', 'e'],
            isolate: false,
          ),
        ],
      ),
    );
    // Two slices of the same size: the right half and the left half.
    expect(pixel(300, 150), _red.toARGB32());
    expect(pixel(100, 150), _blue.toARGB32());
    expect(c.view!.scale(kChartAngle).range, const ChartRange(0, 2));
    expect(c.series.single.entries.map((ChartSeriesEntry entry) => entry.visible), <bool>[
      true,
      false,
      false,
      false,
      true,
    ]);
  });

  testWidgets('the angle scale fits the sum; on a fixed one the slices cover their share', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(host(PolarChart(controller: c, children: <Widget>[_pie(_three())])));
    expect(c.view!.scale(kChartAngle).range, const ChartRange(0, 4));

    // 25 and 25 of 100: the two quarters on the right, and nothing else.
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(
        angle: const LinearScale(range: FixedRange(0, 100)),
        children: <Widget>[
          _pie(ChartData.fromValues(<double>[25, 25])),
        ],
      ),
    );
    expect(pixel(250, 100), _red.toARGB32());
    expect(pixel(250, 200), _green.toARGB32());
    expect(pixel(150, 150), _white);

    // What lies beyond the scale is cut off: 80, then 20 of the 40.
    pixel = await renderPixels(
      tester,
      PolarChart(
        angle: const LinearScale(range: FixedRange(0, 100)),
        children: <Widget>[
          _pie(ChartData.fromValues(<double>[80, 40])),
        ],
      ),
    );
    expect(pixel(150, 200), _red.toARGB32());
    expect(pixel(150, 60), _green.toARGB32(), reason: 'the last fifth of the circle');
    expect(pixel(190, 20), _green.toARGB32());
  });

  testWidgets('a gap separates the slices; corners are rounded', (WidgetTester tester) async {
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(
        children: <Widget>[
          _pie(ChartData.fromValues(<double>[1, 1]), gap: 10),
        ],
      ),
    );
    // The two halves meet on the line x = 200; each gives up 5 px.
    expect(pixel(203, 250), _white);
    expect(pixel(197, 250), _white);
    expect(pixel(207, 250), _red.toARGB32());
    expect(pixel(193, 250), _green.toARGB32());
    expect(pixel(203, 140), _white, reason: 'as wide near the centre');
    expect(pixel(207, 140), _red.toARGB32());

    pixel = await renderPixels(tester, PolarChart(children: <Widget>[_pie(_three())]));
    expect(pixel(202, 3), _red.toARGB32(), reason: 'a sharp corner at twelve o\'clock');
    pixel = await renderPixels(
      tester,
      PolarChart(children: <Widget>[_pie(_three(), cornerRadius: 12)]),
    );
    expect(pixel(202, 3), _white, reason: 'the corner is cut off');
    expect(pixel(212, 13), _red.toARGB32());
  });

  testWidgets('offsetOf pulls a slice out along its middle', (WidgetTester tester) async {
    final Offset beyond = _at(-45, 160);
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      PolarChart(children: <Widget>[_pie(_three())]),
    );
    expect(pixel(beyond.dx.round(), beyond.dy.round()), _white);
    expect(pixel(204, 146), _red.toARGB32());

    pixel = await renderPixels(
      tester,
      PolarChart(children: <Widget>[_pie(_three(), offsetOf: (int index) => index == 0 ? 20 : 0)]),
    );
    expect(pixel(beyond.dx.round(), beyond.dy.round()), _red.toARGB32());
    expect(pixel(204, 146), _white, reason: 'its point left the centre');
    expect(pixel(250, 200), _green.toARGB32(), reason: 'the others stay');
  });

  testWidgets('a pie is hit by position: the slice, its value, its name and its colour', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        PolarChart(
          controller: c,
          children: <Widget>[
            _pie(_three(), labels: const <String>['a', 'b', 'c']),
          ],
        ),
      ),
    );
    final ChartHit hit = c.hitTest(const Offset(250, 100), mode: ChartHitMode.nearest).single;
    expect(hit.index, 0);
    expect(hit.value, 1);
    expect(hit.label, 'a');
    expect(hit.color, _red);
    expect(hit.distance, 0);
    expect(hit.valueAxis, Axis.horizontal);
    expect(hit.sector!.outerRadius, 150);
    expect(hit.sector!.sweepAngle, closeTo(math.pi / 2, 1e-9));
    expect(hit.position, _near(_at(-45, 75)));
    expect(identical(hit.series, c.series.single), isTrue);

    // Beside the pie: the nearest slice, as far away as it is.
    final ChartHit far = c.hitTest(const Offset(20, 20), mode: ChartHitMode.nearest).single;
    expect(far.index, 2);
    expect(far.distance, closeTo(const Offset(180, 130).distance - 150, 1e-6));
    expect(c.hitTest(const Offset(20, 20), mode: ChartHitMode.nearest, maxDistance: 8), isEmpty);
    // A pie has no points at an x or at a y.
    expect(c.hitTest(const Offset(250, 100)), isEmpty);
    expect(c.hitTest(const Offset(250, 100), mode: ChartHitMode.nearestY), isEmpty);
  });

  testWidgets('data labels: in the middle of a slice, at its rim, or outside it', (
    WidgetTester tester,
  ) async {
    Widget chart(ChartDataLabelPosition position) => host(
      PolarChart(
        children: <Widget>[
          _pie(_three()),
          ChartDataLabels(position: position, style: _style),
        ],
      ),
    );
    // Every label is one character: a square of 10 px. The first slice
    // points to half past one.
    final Offset out = Offset(math.sqrt1_2, -math.sqrt1_2);

    await tester.pumpWidget(chart(ChartDataLabelPosition.center));
    List<Rect> labels = _labels(tester);
    expect(labels, hasLength(3));
    expect(labels[0].center, _near(_at(-45, 75)));
    expect(labels[1].center, _near(_at(45, 75)));
    expect(labels[2].center, _near(_at(180, 75)));

    // At the rim: the outer side of the label is 4 px inside the circle.
    await tester.pumpWidget(chart(ChartDataLabelPosition.inside));
    labels = _labels(tester);
    expect(labels[0].center, _near(_at(-45, 146) - out * 5));
    expect(labels[2].center, _near(_at(180, 146) + const Offset(5, 0)));

    // Outside: the inner side of the label is 4 px outside the circle.
    await tester.pumpWidget(chart(ChartDataLabelPosition.outside));
    labels = _labels(tester);
    expect(labels[0].center, _near(_at(-45, 154) + out * 5));
    expect(labels[2].center, _near(_at(180, 154) - const Offset(5, 0)));
  });

  testWidgets('data labels: no room outside puts it inside; too small a slice has none', (
    WidgetTester tester,
  ) async {
    // The middle slice points straight down, where the plot ends at the rim.
    await tester.pumpWidget(
      host(
        PolarChart(
          children: <Widget>[
            _pie(ChartData.fromValues(<double>[1, 2, 1])),
            const ChartDataLabels(style: _style),
          ],
        ),
      ),
    );
    final List<Rect> labels = _labels(tester);
    expect(labels, hasLength(3));
    expect(labels[1].center, _near(const Offset(200, 291)));

    // A label of 60 px does not fit a slice of a twentieth of the circle.
    await tester.pumpWidget(
      host(
        PolarChart(
          children: <Widget>[
            _pie(ChartData.fromValues(<double>[19, 1])),
            ChartDataLabels(
              position: ChartDataLabelPosition.center,
              style: _style,
              format: (ChartHit mark) => 'slice ${mark.index}',
            ),
          ],
        ),
      ),
    );
    expect(_labels(tester), hasLength(1));
  });

  testWidgets('a legend shows one item per named slice and reports taps on them', (
    WidgetTester tester,
  ) async {
    final List<(ChartSeries, int)> taps = <(ChartSeries, int)>[];
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        PolarChart(
          controller: c,
          bottom: <Widget>[
            ChartLegend(
              onEntryTap: (ChartSeries series, ChartSeriesEntry entry) =>
                  taps.add((series, entry.index)),
            ),
          ],
          children: <Widget>[
            PieSeries(
              data: ChartData.fromValues(<double>[1, 0, 2, 3]),
              labels: const <String>['Rent', 'Food', 'Fun'],
              colorOf: _colorOf,
            ),
          ],
        ),
      ),
    );
    // Complete on the first frame. The fourth slice has no name, so no item.
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Fun'), findsOneWidget);
    expect(find.byType(Opacity), findsNWidgets(3));
    // A slice without a value is listed, dimmed.
    double opacityOf(String label) => tester
        .widget<Opacity>(find.ancestor(of: find.text(label), matching: find.byType(Opacity)))
        .opacity;
    expect(opacityOf('Rent'), 1);
    expect(opacityOf('Food'), 0.4);
    // The dots are in the colours of the slices.
    final List<Color?> dots = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((DecoratedBox box) => (box.decoration as BoxDecoration).color)
        .toList();
    expect(dots, <Color?>[_red, _green, _blue]);

    await tester.tap(find.text('Fun'));
    expect(taps, <(ChartSeries, int)>[(c.series.single, 2)]);
  });

  testWidgets('a legend: entryBuilder builds the items of the slices', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        PolarChart(
          top: <Widget>[
            ChartLegend(
              entryBuilder: (BuildContext context, ChartSeries series, ChartSeriesEntry entry) =>
                  Text('${entry.index}: ${entry.label}'),
            ),
          ],
          children: <Widget>[
            _pie(_three(), labels: const <String>['a', 'b', 'c']),
          ],
        ),
      ),
    );
    expect(find.text('0: a'), findsOneWidget);
    expect(find.text('2: c'), findsOneWidget);
  });

  testWidgets('ChartCrosshair.point and a tooltip name the slice under the pointer', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        PolarChart(
          controller: c,
          innerRadius: 0.5,
          children: <Widget>[
            _pie(_three(), labels: const <String>['a', 'b', 'c']),
            const ChartCrosshair.point(),
            const ChartTooltip(),
          ],
        ),
      ),
    );
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(310, 210)));
    await tester.pump();
    expect(find.text('b: '), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(c.hitsFor(c.focus.value!).single.index, 1);
    // The crosshair draws nothing: no lines, and no dot on a slice.
    final RenderObject crosshair = tester.renderObject(
      find.descendant(of: find.byType(ChartCrosshair), matching: find.byType(ChartPaint)),
    );
    expect(crosshair, isNot(paints..line()));
    expect(crosshair, isNot(paints..circle()));

    await tester.sendEventToBinding(mouse.hover(const Offset(120, 150)));
    await tester.pump();
    expect(find.text('c: '), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('b: '), findsNothing);

    // In the hole, more than 8 px from every slice, nothing is pointed at.
    await tester.sendEventToBinding(mouse.hover(const Offset(200, 150)));
    await tester.pump();
    expect(find.text('c: '), findsNothing);
    expect(c.hitsFor(c.focus.value!), isEmpty);
  });

  testWidgets('ChartAppear: reveal draws the pie in around its centre, grow from the centre', (
    WidgetTester tester,
  ) async {
    Widget chart(ChartAppearEffect effect) => PolarChart(
      children: <Widget>[
        ChartAppear(
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
          effect: effect,
          child: _pie(_three()),
        ),
      ],
    );
    int Function(int x, int y) pixel = await renderPixels(tester, chart(ChartAppearEffect.reveal));
    expect(pixel(250, 100), _white);
    await tester.pump(const Duration(milliseconds: 500));
    pixel = await capturePixels(tester);
    // Half way: the half from twelve to six o'clock.
    expect(pixel(250, 100), _red.toARGB32());
    expect(pixel(250, 200), _green.toARGB32());
    expect(pixel(150, 150), _white);
    await tester.pump(const Duration(milliseconds: 500));
    pixel = await capturePixels(tester);
    expect(pixel(150, 150), _blue.toARGB32());

    await tester.pumpWidget(const SizedBox());
    pixel = await renderPixels(tester, chart(ChartAppearEffect.growY));
    await tester.pump(const Duration(milliseconds: 500));
    pixel = await capturePixels(tester);
    // Half way: a pie of half the radius.
    expect(pixel(230, 130), _red.toARGB32());
    expect(pixel(300, 100), _white);
    expect(pixel(110, 150), _white);
    await tester.pump(const Duration(milliseconds: 500));
    pixel = await capturePixels(tester);
    expect(pixel(300, 100), _red.toARGB32());
  });

  testWidgets('AnimatedChartData moves the slices to new values', (WidgetTester tester) async {
    Widget chart(ChartData data) => PolarChart(
      children: <Widget>[
        AnimatedChartData(
          data: data,
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
          animateOnMount: false,
          builder: (BuildContext context, ChartData animated) => _pie(animated),
        ),
      ],
    );
    // A quarter and three quarters.
    int Function(int x, int y) pixel = await renderPixels(
      tester,
      chart(ChartData.fromValues(<double>[1, 3])),
    );
    expect(pixel(250, 200), _green.toARGB32());
    await tester.pumpWidget(
      host(
        RepaintBoundary(
          key: const Key('shot'),
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: chart(ChartData.fromValues(<double>[3, 1])),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    pixel = await capturePixels(tester);
    // Half way they are two halves.
    expect(pixel(250, 200), _red.toARGB32());
    expect(pixel(150, 200), _green.toARGB32());
    await tester.pump(const Duration(milliseconds: 500));
    pixel = await capturePixels(tester);
    expect(pixel(150, 200), _red.toARGB32());
    expect(pixel(150, 100), _green.toARGB32());
  });

  testWidgets('outside a PolarChart a pie says where it belongs', (WidgetTester tester) async {
    await tester.pumpWidget(host(Chart(children: <Widget>[_pie(_three())])));
    final Object? error = tester.takeException();
    expect(error, isFlutterError);
    expect(error.toString(), contains('must be placed in a PolarChart'));
  });

  testWidgets('a pie in a chart of your own, with its scales registered by hand', (
    WidgetTester tester,
  ) async {
    final int Function(int x, int y) pixel = await renderPixels(
      tester,
      ChartPolarScope(
        polar: const ChartPolar(angleScale: 'share', radiusScale: 'depth'),
        child: Chart(
          xScales: const <Object, ChartScale>{'share': LinearScale()},
          yScales: const <Object, ChartScale>{'depth': LinearScale()},
          children: <Widget>[_pie(_three())],
        ),
      ),
    );
    expect(pixel(250, 100), _red.toARGB32());
    expect(pixel(150, 150), _blue.toARGB32());
  });
}

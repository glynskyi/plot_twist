import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

// In the 400 x 300 host, a value of 1 is 4 px along x and 3 px along y. The
// test font draws every character as a square of the font size, so a label
// of 2 characters at 10 px is 20 px wide and 10 px high.
const ChartScale _x = LinearScale(range: FixedRange(0, 100));
const ChartScale _y = LinearScale(range: FixedRange(0, 100));
const TextStyle _style = TextStyle(fontSize: 10, height: 1, color: Color(0xFF000000));

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

/// Bars at x = 20, 50 and 80 (80, 200 and 320 px) with the values 50, 25
/// and 75, each 20 px wide.
ChartData _three() => ChartData.fromXY(<double>[20, 50, 80], <double>[50, 25, 75]);

Widget _chart(
  List<Widget> children, {
  ChartController? controller,
  ChartScale x = _x,
  ChartScale y = _y,
}) => host(Chart(controller: controller, x: x, y: y, children: children));

void main() {
  testWidgets('every bar gets its value above its end', (WidgetTester tester) async {
    await tester.pumpWidget(
      _chart(<Widget>[
        BarSeries(data: _three(), step: 10, widthFactor: 0.5),
        const ChartDataLabels(style: _style),
      ]),
    );
    // "50" above the bar that ends at y = 150 px, with 4 px in between.
    expect(_labels(tester), <Rect>[
      const Rect.fromLTWH(70, 136, 20, 10),
      const Rect.fromLTWH(190, 211, 20, 10),
      const Rect.fromLTWH(310, 61, 20, 10),
    ]);
  });

  testWidgets('below a bar that points down, and beside one that lies', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _chart(<Widget>[
        BarSeries(data: ChartData.fromXY(<double>[50], <double>[-20]), step: 10, widthFactor: 0.5),
        const ChartDataLabels(style: _style),
      ], y: const LinearScale(range: FixedRange(-50, 50))),
    );
    // The bar runs from y = 150 px (zero) down to 210 px; "-20" is 3 characters.
    expect(_labels(tester).single, const Rect.fromLTWH(185, 214, 30, 10));

    await tester.pumpWidget(
      _chart(
        <Widget>[
          BarSeries(
            data: ChartData.fromXY(<double>[2, 8], <double>[25, -50]),
            direction: Axis.horizontal,
            step: 1,
            widthFactor: 0.5,
          ),
          const ChartDataLabels(style: _style),
        ],
        x: const LinearScale(range: FixedRange(-100, 100)),
        y: const LinearScale(range: FixedRange(0, 10)),
      ),
    );
    // Row 2 (y = 240 px) ends at x = 250 px, row 8 (y = 60 px) at 100 px.
    expect(_labels(tester), <Rect>[
      const Rect.fromLTWH(254, 235, 20, 10),
      const Rect.fromLTWH(66, 55, 30, 10),
    ]);
  });

  testWidgets('inside the end of a bar, or in its middle, when it fits', (
    WidgetTester tester,
  ) async {
    Widget build(ChartDataLabelPosition position, {double widthFactor = 0.5}) => _chart(<Widget>[
      BarSeries(data: _three(), step: 10, widthFactor: widthFactor),
      ChartDataLabels(style: _style, position: position),
    ]);
    await tester.pumpWidget(build(ChartDataLabelPosition.inside));
    expect(_labels(tester).first, const Rect.fromLTWH(70, 154, 20, 10));
    await tester.pumpWidget(build(ChartDataLabelPosition.center));
    // The bar spans y = 150 to 300 px.
    expect(_labels(tester).first, const Rect.fromLTWH(70, 220, 20, 10));

    // A bar 12 px wide has no room for a label of 20 px.
    await tester.pumpWidget(build(ChartDataLabelPosition.inside, widthFactor: 0.3));
    expect(_labels(tester), isEmpty);
    await tester.pumpWidget(build(ChartDataLabelPosition.center, widthFactor: 0.3));
    expect(_labels(tester), isEmpty);
    await tester.pumpWidget(build(ChartDataLabelPosition.outside, widthFactor: 0.3));
    expect(_labels(tester), hasLength(3));
  });

  testWidgets('points of a line and of a scatter series, and candles', (WidgetTester tester) async {
    await tester.pumpWidget(
      _chart(<Widget>[LineSeries(data: _three()), const ChartDataLabels(style: _style)]),
    );
    expect(_labels(tester).first, const Rect.fromLTWH(70, 136, 20, 10));
    await tester.pumpWidget(
      _chart(<Widget>[
        ScatterSeries(data: _three()),
        const ChartDataLabels(style: _style, position: ChartDataLabelPosition.center),
      ]),
    );
    expect(_labels(tester).first, const Rect.fromLTWH(70, 145, 20, 10));

    final ChartData candles = ChartData(valueColumns: 4)..addRow(50, <double>[40, 80, 30, 60]);
    await tester.pumpWidget(
      _chart(<Widget>[
        CandlestickSeries(data: candles, step: 10),
        const ChartDataLabels(style: _style),
      ]),
    );
    // The close, above the high at y = 60 px.
    expect(_labels(tester).single, const Rect.fromLTWH(190, 46, 20, 10));
  });

  testWidgets('format writes the text, and no text is no label', (WidgetTester tester) async {
    final List<ChartHit> seen = <ChartHit>[];
    await tester.pumpWidget(
      _chart(<Widget>[
        BarSeries(data: _three(), step: 10, widthFactor: 0.5, label: 'sales'),
        ChartDataLabels(
          style: _style,
          format: (ChartHit mark) {
            seen.add(mark);
            return mark.index == 1 ? null : '${mark.value.round()} %';
          },
        ),
      ]),
    );
    final List<Rect> labels = _labels(tester);
    expect(labels, hasLength(2));
    expect(labels.first.width, 40);
    expect(seen.first.series?.label, 'sales');
    expect(seen.first.rect, const Rect.fromLTRB(70, 150, 90, 300));
    expect(seen.first.base, 0);
  });

  testWidgets('series: labels only that one; a hidden series has none', (
    WidgetTester tester,
  ) async {
    Widget build({Object? series, bool visible = true}) => _chart(<Widget>[
      BarSeries(data: _three(), step: 10, widthFactor: 0.5, id: 'bars', visible: visible),
      LineSeries(data: ChartData.fromXY(<double>[35, 65], <double>[90, 90]), id: 'line'),
      ChartDataLabels(style: _style, series: series),
    ]);
    await tester.pumpWidget(build());
    expect(_labels(tester), hasLength(5));
    await tester.pumpWidget(build(series: 'line'));
    expect(_labels(tester), hasLength(2));
    await tester.pumpWidget(build(series: 'bars'));
    expect(_labels(tester), hasLength(3));
    await tester.pumpWidget(build(visible: false));
    expect(_labels(tester), hasLength(2));
  });

  testWidgets('with more marks than maxLabels there are no labels at all', (
    WidgetTester tester,
  ) async {
    final ChartData many = ChartData.generate(40, (int i) => (i * 2.5, 50));
    Widget build(int maxLabels) => _chart(<Widget>[
      ScatterSeries(data: many),
      ChartDataLabels(style: _style, maxLabels: maxLabels, hideOverlapping: false),
    ]);
    await tester.pumpWidget(build(40));
    expect(_labels(tester), hasLength(40));
    await tester.pumpWidget(build(39));
    expect(_labels(tester), isEmpty);
    expect(const ChartDataLabels().maxLabels, 250);
  });

  testWidgets('a label that would cover another one is left out', (WidgetTester tester) async {
    // Points 12 px apart: labels of 20 px overlap their neighbours.
    final ChartData close = ChartData.fromXY(<double>[40, 43, 46, 49], <double>[50, 50, 50, 50]);
    Widget build({required bool hideOverlapping}) => _chart(<Widget>[
      ScatterSeries(data: close),
      ChartDataLabels(style: _style, hideOverlapping: hideOverlapping),
    ]);
    await tester.pumpWidget(build(hideOverlapping: true));
    expect(_labels(tester).map((Rect r) => r.left), <double>[150, 174]);
    await tester.pumpWidget(build(hideOverlapping: false));
    expect(_labels(tester), hasLength(4));
  });

  testWidgets('labels follow the data and the window in the same frame', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = _three();
    await tester.pumpWidget(
      _chart(<Widget>[
        BarSeries(data: data, step: 10, widthFactor: 0.5),
        const ChartDataLabels(style: _style),
      ], controller: c),
    );
    final RenderObject layer = tester.renderObject(
      find.descendant(of: find.byType(ChartDataLabels), matching: find.byType(ChartPaint)),
    );
    expect(layer.debugNeedsPaint, isFalse);
    data.setValue(0, 98);
    expect(layer.debugNeedsPaint, isTrue, reason: 'repainted with the bars, not a frame later');
    await tester.pump();
    // The bar now ends 6 px below the top of the plot. There is no room
    // above it, so its label moves inside its end.
    expect(_labels(tester).first, const Rect.fromLTWH(70, 10, 20, 10));

    c.x.jumpTo(10, 110);
    await tester.pump();
    expect(_labels(tester).first.left, 30);

    // Marks outside the plot have no label.
    c.x.jumpTo(40, 140);
    await tester.pump();
    expect(_labels(tester), hasLength(2));
  });

  testWidgets('a series of your own is labelled through visitMarks', (WidgetTester tester) async {
    await tester.pumpWidget(
      _chart(<Widget>[ChartPaint(painter: _MarksOnly()), const ChartDataLabels(style: _style)]),
    );
    expect(_labels(tester), <Rect>[
      const Rect.fromLTWH(90, 88, 20, 10),
      const Rect.fromLTWH(290, 187, 20, 10),
    ]);
  });

  testWidgets('the default style is the label style of the theme; inside a bar it contrasts', (
    WidgetTester tester,
  ) async {
    // The test font draws a digit as a filled square, so the middle of a
    // label has the colour of its text.
    Future<int> textPixel(ChartDataLabelPosition position, Color bar, int y) async {
      final int Function(int x, int y) pixel = await renderPixels(
        tester,
        Chart(
          x: _x,
          y: _y,
          children: <Widget>[
            BarSeries(data: _three(), step: 10, color: bar, isolate: false),
            ChartDataLabels(position: position),
          ],
        ),
      );
      return pixel(80, y);
    }

    int red(int argb) => (argb >> 16) & 0xFF;
    // Above the first bar, which ends at y = 150 px: the grey of axis labels.
    final int outside = await textPixel(
      ChartDataLabelPosition.outside,
      const Color(0xFF3060C0),
      139,
    );
    expect(red(outside), inInclusiveRange(0x40, 0x80));
    // Inside it: light on a dark bar, dark on a light one.
    expect(
      red(await textPixel(ChartDataLabelPosition.inside, const Color(0xFF101010), 161)),
      greaterThan(0xD0),
    );
    expect(
      red(await textPixel(ChartDataLabelPosition.inside, const Color(0xFFF0F0F0), 161)),
      lessThan(0x40),
    );
  });
}

/// A series that draws nothing and reports two marks.
class _MarksOnly extends ChartSeriesPainter {
  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) => null;

  @override
  void paint(ChartPaintContext context) {}

  @override
  bool shouldRepaint(_MarksOnly oldDelegate) => false;

  @override
  void visitMarks(ChartView view, bool Function(ChartHit mark) visit) {
    for (final (double x, double y) in <(double, double)>[(25, 66), (75, 33)]) {
      final bool more = visit(
        ChartHit(x: x, y: y, position: Offset(view.x.toPixel(x), view.y.toPixel(y)), distance: 0),
      );
      if (!more) return;
    }
  }
}

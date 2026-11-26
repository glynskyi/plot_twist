import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

const List<Color> _palette = ChartThemeData.defaultPalette;
const Color _red = Color(0xFFFF0000);
const Color _blue = Color(0xFF0000FF);

/// The colour the [index]th painted layer of the chart draws with.
Color? _painted(WidgetTester tester, int index) {
  final RenderObject layer = tester.renderObjectList(find.byType(ChartPaint)).elementAt(index);
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  layer.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  for (final RecordedInvocation call in canvas.invocations) {
    for (final Object? argument in call.invocation.positionalArguments) {
      if (argument is Paint) return argument.color;
    }
  }
  return null;
}

void _expectColor(Color? actual, Color expected) {
  expect(actual, isNotNull);
  expect(actual!.toARGB32(), expected.toARGB32());
}

/// Records the colour its paint context offers.
class _ProbePainter extends ChartSeriesPainter {
  _ProbePainter(this.seen);

  final List<Color> seen;

  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) => null;

  @override
  void paint(ChartPaintContext context) => seen.add(context.seriesColor);

  @override
  bool shouldRepaint(_ProbePainter oldDelegate) => false;
}

class _PlainPainter extends ChartPainter {
  _PlainPainter(this.seen);

  final List<Color> seen;

  @override
  void paint(ChartPaintContext context) => seen.add(context.seriesColor);

  @override
  bool shouldRepaint(_PlainPainter oldDelegate) => false;
}

void main() {
  final ChartData data = ChartData.fromValues(<double>[1, 3, 2, 4]);

  testWidgets('series without a colour take the palette colours in paint order', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          children: <Widget>[
            LineSeries(data: data),
            BarSeries(data: data),
            ScatterSeries(data: data),
          ],
        ),
      ),
    );
    for (int i = 0; i < 3; i++) {
      _expectColor(_painted(tester, i), _palette[i]);
      _expectColor(c.series[i].color, _palette[i]);
    }
  });

  testWidgets('a series with a colour of its own keeps it, and still takes a place', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          children: <Widget>[
            LineSeries(data: data),
            LineSeries(data: data, color: _red),
            LineSeries(data: data),
          ],
        ),
      ),
    );
    _expectColor(_painted(tester, 0), _palette[0]);
    _expectColor(_painted(tester, 1), _red);
    _expectColor(_painted(tester, 2), _palette[2]);
    _expectColor(c.series[1].color, _red);
  });

  testWidgets('hiding a series changes no colour', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    Widget build({required bool second}) => host(
      Chart(
        controller: c,
        children: <Widget>[
          LineSeries(data: data),
          LineSeries(data: data, visible: second),
          LineSeries(data: data),
        ],
      ),
    );
    await tester.pumpWidget(build(second: true));
    await tester.pumpWidget(build(second: false));
    _expectColor(_painted(tester, 0), _palette[0]);
    expect(_painted(tester, 1), isNull);
    _expectColor(_painted(tester, 2), _palette[2]);
    // A legend still shows the hidden series in its colour.
    _expectColor(c.series[1].color, _palette[1]);
  });

  testWidgets('series are listed in paint order, also when one is added in front', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    int notified = 0;
    c.seriesListenable.addListener(() => notified++);
    Widget build({required bool withFirst}) => host(
      Chart(
        controller: c,
        children: <Widget>[
          if (withFirst) LineSeries(key: const ValueKey<String>('n'), data: data, id: 'n'),
          LineSeries(key: const ValueKey<String>('a'), data: data, id: 'a'),
          LineSeries(key: const ValueKey<String>('b'), data: data, id: 'b'),
        ],
      ),
    );
    await tester.pumpWidget(build(withFirst: false));
    await tester.pump();
    expect(c.series.map((ChartSeries s) => s.id), <String>['a', 'b']);
    _expectColor(_painted(tester, 0), _palette[0]);
    _expectColor(_painted(tester, 1), _palette[1]);

    notified = 0;
    await tester.pumpWidget(build(withFirst: true));
    expect(c.series.map((ChartSeries s) => s.id), <String>['n', 'a', 'b']);
    for (int i = 0; i < 3; i++) {
      _expectColor(_painted(tester, i), _palette[i]);
      _expectColor(c.series[i].color, _palette[i]);
    }
    // The layers whose colour changed are painted again.
    final List<RenderObject> layers = tester.renderObjectList(find.byType(ChartPaint)).toList();
    expect(layers[1].debugNeedsPaint || layers[2].debugNeedsPaint, isFalse);
    await tester.pump();
    expect(notified, 1);

    await tester.pumpWidget(build(withFirst: false));
    expect(c.series.map((ChartSeries s) => s.id), <String>['a', 'b']);
    _expectColor(_painted(tester, 0), _palette[0]);
    _expectColor(_painted(tester, 1), _palette[1]);
  });

  testWidgets('a series moved in front is painted again in its new colour', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final List<Color> seenA = <Color>[];
    final List<Color> seenB = <Color>[];
    Widget build({required bool withFirst}) => host(
      Chart(
        controller: c,
        children: <Widget>[
          if (withFirst) LineSeries(key: const ValueKey<String>('n'), data: data),
          ChartPaint(key: const ValueKey<String>('a'), painter: _ProbePainter(seenA)),
          ChartPaint(key: const ValueKey<String>('b'), painter: _ProbePainter(seenB)),
        ],
      ),
    );
    await tester.pumpWidget(build(withFirst: false));
    expect(seenA.last.toARGB32(), _palette[0].toARGB32());
    expect(seenB.last.toARGB32(), _palette[1].toARGB32());
    await tester.pumpWidget(build(withFirst: true));
    expect(seenA.last.toARGB32(), _palette[1].toARGB32());
    expect(seenB.last.toARGB32(), _palette[2].toARGB32());
  });

  testWidgets('the palette of the chart theme is used, wraps around and can change', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    Widget build(List<Color> palette) => host(
      ChartTheme(
        data: ChartThemeData.fallback().copyWith(palette: palette),
        child: Chart(
          controller: c,
          children: <Widget>[
            LineSeries(data: data),
            LineSeries(data: data),
            LineSeries(data: data),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build(const <Color>[_red, _blue]));
    _expectColor(_painted(tester, 0), _red);
    _expectColor(_painted(tester, 1), _blue);
    _expectColor(_painted(tester, 2), _red);

    await tester.pumpWidget(build(const <Color>[_blue, _red]));
    _expectColor(_painted(tester, 0), _blue);
    _expectColor(c.series[1].color, _red);
  });

  testWidgets('a painter of its own reads the colour from the paint context', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final List<Color> first = <Color>[];
    final List<Color> second = <Color>[];
    final List<Color> coloured = <Color>[];
    final List<Color> plain = <Color>[];
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          children: <Widget>[
            ChartPaint(painter: _ProbePainter(first)),
            // Not a series: it takes no place and gets the first colour.
            ChartPaint(painter: _PlainPainter(plain)),
            ChartPaint(painter: _ProbePainter(second)),
            ChartPaint(painter: _ProbePainter(coloured), color: _red),
          ],
        ),
      ),
    );
    expect(c.series, hasLength(3));
    expect(first.single.toARGB32(), _palette[0].toARGB32());
    expect(second.single.toARGB32(), _palette[1].toARGB32());
    expect(coloured.single.toARGB32(), _red.toARGB32());
    expect(plain.single.toARGB32(), _palette[0].toARGB32());
  });

  testWidgets('a chart inside a chart counts its own series', (WidgetTester tester) async {
    final ChartController outer = ChartController();
    final ChartController inner = ChartController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: outer,
          children: <Widget>[
            LineSeries(data: data, id: 'outer 1'),
            Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 120,
                height: 80,
                child: Chart(
                  controller: inner,
                  children: <Widget>[LineSeries(data: data, id: 'inner')],
                ),
              ),
            ),
            LineSeries(data: data, id: 'outer 2'),
          ],
        ),
      ),
    );
    expect(outer.series.map((ChartSeries s) => s.id), <String>['outer 1', 'outer 2']);
    expect(inner.series.map((ChartSeries s) => s.id), <String>['inner']);
    _expectColor(outer.series[1].color, _palette[1]);
    _expectColor(inner.series[0].color, _palette[0]);
  });

  testWidgets('a hit carries the palette colour of its series', (WidgetTester tester) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Chart(
          controller: c,
          children: <Widget>[
            LineSeries(data: data, label: 'first'),
            LineSeries(data: data, label: 'second'),
          ],
        ),
      ),
    );
    final List<ChartHit> hits = c.hitTest(const Offset(100, 100));
    expect(hits, hasLength(2));
    for (final ChartHit hit in hits) {
      _expectColor(hit.series!.color, hit.series!.label == 'first' ? _palette[0] : _palette[1]);
    }
  });
}

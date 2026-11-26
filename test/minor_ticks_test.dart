import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

ChartTickContext _context(double min, double max, {double extent = 400}) =>
    ChartTickContext(min: min, max: max, extent: extent, direction: Axis.horizontal);

List<double> _minor(ChartTicks ticks, ChartTickContext context) =>
    ticks.generateMinor(context, ticks.generate(context));

/// The lines the [index]th `RenderChartAxis` or `ChartPaint` layer draws.
List<(Offset, Offset)> _linesOf(RenderObject object) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  object.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return <(Offset, Offset)>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawLine)
        (
          call.invocation.positionalArguments[0] as Offset,
          call.invocation.positionalArguments[1] as Offset,
        ),
  ];
}

List<Color> _lineColorsOf(RenderObject object) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  object.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return <Color>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawLine)
        (call.invocation.positionalArguments[2] as Paint).color,
  ];
}

void main() {
  group('minor ticks', () {
    test('ticks have none unless asked', () {
      expect(_minor(const LinearTicks(), _context(0, 100)), isEmpty);
      expect(_minor(const LogTicks(), _context(1, 1000)), isEmpty);
      expect(_minor(const BandTicks(), _context(-0.5, 4.5)), isEmpty);
      expect(_minor(const FixedTicks(<double>[1, 2]), _context(0, 3)), isEmpty);
      expect(_minor(const TimeTicks(), _context(0, 86400000)), isEmpty);
    });

    test('LinearTicks(minorCount:) divides every step, also before the first tick', () {
      const LinearTicks ticks = LinearTicks(minorCount: 4);
      // Major ticks are 25 apart, so minor ones are 5 apart.
      expect(ticks.generate(_context(0, 100)).map((ChartTick t) => t.value), <double>[
        0,
        25,
        50,
        75,
        100,
      ]);
      expect(_minor(ticks, _context(0, 100)), <double>[
        for (double v = 5; v < 100; v += 5)
          if (v % 25 != 0) v,
      ]);
      // A window that starts and ends between two major ticks, which are 20
      // apart here: minor ticks come before the first one too.
      expect(_minor(ticks, _context(12, 61)), <double>[12, 16, 24, 28, 32, 36, 44, 48, 52, 56]);
      // One major tick only: the step is known all the same.
      expect(_minor(const LinearTicks(minorCount: 1), _context(20, 30, extent: 100)), isNotEmpty);
    });

    test('minor ticks closer than 3 px are left out', () {
      // 40 px for 100 units: major ticks 50 apart, 9 minor ones in between
      // would be 2 px apart.
      expect(_minor(const LinearTicks(minorCount: 9), _context(0, 100, extent: 40)), isEmpty);
      expect(_minor(const LinearTicks(minorCount: 4), _context(0, 100, extent: 40)), isNotEmpty);
      expect(_minor(const BandTicks(minor: true), _context(0, 1000)), isEmpty);
    });

    test('LogTicks(minor:) marks the multiples between the labelled values', () {
      const LogTicks ticks = LogTicks(minor: true);
      expect(ticks.generate(_context(1, 1000)).map((ChartTick t) => t.value), <double>[
        1,
        10,
        100,
        1000,
      ]);
      expect(_minor(ticks, _context(1, 1000)), <double>[
        for (final double decade in <double>[1, 10, 100])
          for (double m = 2; m <= 9; m++) m * decade,
      ]);
      // With room for 1, 2 and 5, those are labelled and the rest is minor.
      final ChartTickContext wide = _context(1, 100, extent: 800);
      final List<double> major = ticks.generate(wide).map((ChartTick t) => t.value).toList();
      expect(major, containsAll(<double>[2, 5, 20, 50]));
      expect(_minor(ticks, wide), <double>[3, 4, 6, 7, 8, 9, 30, 40, 60, 70, 80, 90]);
    });

    test('LogTicks(minor:) marks the powers that are too many to label', () {
      const LogTicks ticks = LogTicks(minor: true);
      final ChartTickContext context = _context(1, 1e12);
      final List<double> major = ticks.generate(context).map((ChartTick t) => t.value).toList();
      expect(major.length, lessThan(13));
      final List<double> minor = _minor(ticks, context);
      expect(<double>{...major, ...minor}, <double>{for (int e = 0; e <= 12; e++) _pow10(e)});
      expect(minor.toSet().intersection(major.toSet()), isEmpty);
    });

    test('BandTicks(minor:) marks the borders between the bands', () {
      expect(_minor(const BandTicks(minor: true), _context(-0.5, 4.5)), <double>[
        -0.5,
        0.5,
        1.5,
        2.5,
        3.5,
        4.5,
      ]);
      expect(_minor(const BandTicks(minor: true), _context(0.2, 2.2)), <double>[0.5, 1.5]);
    });

    test('the option is part of the equality of the ticks', () {
      expect(const LinearTicks(minorCount: 4) == const LinearTicks(minorCount: 4), isTrue);
      expect(const LinearTicks(minorCount: 4) == const LinearTicks(), isFalse);
      expect(const LogTicks(minor: true) == const LogTicks(), isFalse);
      expect(const BandTicks(minor: true) == const BandTicks(), isFalse);
    });

    testWidgets('a scale view has the minor ticks of its scale', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: const LinearScale(range: FixedRange(0, 100), ticks: LinearTicks(minorCount: 4)),
            y: const LinearScale(range: FixedRange(0, 100)),
          ),
        ),
      );
      expect(c.view!.x.minorTicks, hasLength(16));
      expect(c.view!.x.minorTicks.first, 5);
      expect(c.view!.y.minorTicks, isEmpty);
    });
  });

  group('minor ticks on the chart', () {
    const ChartScale x = LinearScale(range: FixedRange(0, 100), ticks: LinearTicks(minorCount: 4));
    const ChartScale y = LinearScale(range: FixedRange(0, 100));

    testWidgets('an axis draws a short mark at every minor tick', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      Widget build({double minorTickLength = 2, ChartTicks? ticks}) => host(
        Chart(
          controller: c,
          x: ticks == null ? x : const LinearScale(range: FixedRange(0, 100)),
          y: y,
          bottom: <Widget>[
            ChartAxis(
              tickLength: 6,
              minorTickLength: minorTickLength,
              showLine: false,
              ticks: ticks,
            ),
          ],
        ),
      );
      await tester.pumpWidget(build());
      final RenderObject axis = tester.renderObject(find.byType(ChartAxis));
      final ChartView view = c.view!;
      List<double> marks(double length) => <double>[
        for (final (Offset from, Offset to) in _linesOf(axis))
          if ((to.dy - from.dy - length).abs() < 1e-9) from.dx,
      ];
      expect(marks(6), <double>[for (final ChartTick t in view.x.ticks) view.x.toPixel(t.value)]);
      expect(marks(2), <double>[for (final double v in view.x.minorTicks) view.x.toPixel(v)]);
      expect(marks(2), hasLength(16));

      // They follow the window without the axis being rebuilt.
      c.x.jumpTo(2, 102);
      await tester.pump();
      expect(marks(2).first, c.view!.x.toPixel(5));

      await tester.pumpWidget(build(minorTickLength: 0));
      expect(marks(2), isEmpty);

      // Ticks given to the axis bring their own minor ticks.
      await tester.pumpWidget(build(ticks: const LinearTicks(minorCount: 1)));
      c.x.resetToAuto();
      await tester.pump();
      expect(marks(2), <double>[
        for (final double v in <double>[12.5, 37.5, 62.5, 87.5]) c.view!.x.toPixel(v),
      ]);
    });

    testWidgets('a grid draws minor lines when asked, in their own colour', (
      WidgetTester tester,
    ) async {
      const Color major = Color(0xFF112233);
      const Color minor = Color(0xFF445566);
      Widget build({required bool showMinor, Color? minorColor}) => host(
        Chart(
          x: x,
          y: y,
          children: <Widget>[
            ChartGrid(color: major, minor: showMinor, minorColor: minorColor, horizontal: false),
          ],
        ),
      );
      await tester.pumpWidget(build(showMinor: false));
      RenderObject grid() => tester.renderObject(find.byType(ChartPaint));
      expect(_linesOf(grid()), hasLength(5));

      await tester.pumpWidget(build(showMinor: true, minorColor: minor));
      expect(_linesOf(grid()), hasLength(21));
      final List<Color> colors = _lineColorsOf(grid());
      expect(colors.where((Color c) => c.toARGB32() == minor.toARGB32()), hasLength(16));
      expect(colors.where((Color c) => c.toARGB32() == major.toARGB32()), hasLength(5));
      // Minor lines are drawn first, so major ones lie on top.
      expect(colors.first.toARGB32(), minor.toARGB32());
      expect(_linesOf(grid()).first, (const Offset(20, 0), const Offset(20, 300)));

      // Without a colour of their own they are a fainter major line.
      await tester.pumpWidget(build(showMinor: true));
      final Color faint = _lineColorsOf(grid()).first;
      expect(faint.a, closeTo(major.a / 2, 0.01));
      expect(faint.toARGB32() & 0xFFFFFF, major.toARGB32() & 0xFFFFFF);
    });
  });
}

double _pow10(int e) {
  double value = 1;
  for (int i = 0; i < e; i++) {
    value *= 10;
  }
  return value;
}

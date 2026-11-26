import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

const ChartScale _y = LinearScale(range: FixedRange(0, 100));

/// The (start, end) of every dash of [path] along a horizontal line.
List<(double, double)> _dashes(ui.Path path) => <(double, double)>[
  for (final ui.PathMetric metric in path.computeMetrics())
    (
      metric.getTangentForOffset(0)!.position.dx,
      metric.getTangentForOffset(metric.length)!.position.dx,
    ),
];

ui.Path _line(double length) => ui.Path()
  ..moveTo(0, 0)
  ..lineTo(length, 0);

Matcher _closeToAll(List<(double, double)> expected) =>
    pairwiseCompare<(double, double), (double, double)>(
      expected,
      ((double, double) e, (double, double) a) =>
          (e.$1 - a.$1).abs() < 1e-3 && (e.$2 - a.$2).abs() < 1e-3,
      'the dashes',
    );

/// The layers painted by `ChartPaint`, as recorded canvas calls.
List<RecordedInvocation> _callsOf(WidgetTester tester, int layer) {
  final RenderObject object = tester.renderObjectList(find.byType(ChartPaint)).elementAt(layer);
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  object.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return canvas.invocations;
}

/// The dashes a `drawRawPoints(lines)` call draws, as (from, to).
List<(Offset, Offset)> _segments(Iterable<RecordedInvocation> calls) => <(Offset, Offset)>[
  for (final RecordedInvocation call in calls)
    if (call.invocation.memberName == #drawRawPoints)
      for (
        int i = 0;
        i + 3 < (call.invocation.positionalArguments[1] as Float32List).length;
        i += 4
      )
        (
          Offset(
            (call.invocation.positionalArguments[1] as Float32List)[i],
            (call.invocation.positionalArguments[1] as Float32List)[i + 1],
          ),
          Offset(
            (call.invocation.positionalArguments[1] as Float32List)[i + 2],
            (call.invocation.positionalArguments[1] as Float32List)[i + 3],
          ),
        ),
];

void main() {
  group('ChartPainter.dashPath', () {
    test('cuts a path into dashes and gaps', () {
      expect(
        _dashes(ChartPainter.dashPath(_line(40), const <double>[10, 5])),
        _closeToAll(<(double, double)>[(0, 10), (15, 25), (30, 40)]),
      );
    });

    test('a phase starts the pattern that far in, and wraps around', () {
      const List<(double, double)> shifted = <(double, double)>[(0, 6), (11, 21), (26, 36)];
      expect(
        _dashes(ChartPainter.dashPath(_line(40), const <double>[10, 5], phase: 4)),
        _closeToAll(shifted),
      );
      expect(
        _dashes(ChartPainter.dashPath(_line(40), const <double>[10, 5], phase: 19)),
        _closeToAll(shifted),
      );
      expect(
        _dashes(ChartPainter.dashPath(_line(40), const <double>[10, 5], phase: -11)),
        _closeToAll(shifted),
      );
      // A phase inside a gap: the path starts with the rest of the gap.
      expect(
        _dashes(ChartPainter.dashPath(_line(40), const <double>[10, 5], phase: 12)),
        _closeToAll(<(double, double)>[(3, 13), (18, 28), (33, 40)]),
      );
    });

    test('a pattern of odd length alternates, and one of zeros still ends', () {
      expect(
        _dashes(ChartPainter.dashPath(_line(25), const <double>[10])),
        _closeToAll(<(double, double)>[(0, 10), (20, 25)]),
      );
      expect(ChartPainter.dashPath(_line(20), const <double>[0, 0]).computeMetrics(), isNotEmpty);
      expect(ChartPainter.dashPath(_line(20), const <double>[]).computeMetrics(), hasLength(1));
    });

    test('every contour starts the pattern again', () {
      final ui.Path two = _line(12)
        ..moveTo(100, 0)
        ..lineTo(112, 0);
      expect(
        _dashes(ChartPainter.dashPath(two, const <double>[10, 5], phase: 4)),
        _closeToAll(<(double, double)>[(0, 6), (11, 12), (100, 106), (111, 112)]),
      );
    });
  });

  test('ChartPainter.drawDashedLine draws the dashes of a straight line in one call', () {
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    final Paint paint = Paint()..strokeWidth = 2;
    ChartPainter.drawDashedLine(
      canvas,
      const Offset(10, 0),
      const Offset(10, 30),
      paint,
      const <double>[10, 5],
      phase: 4,
    );
    expect(canvas.invocations, hasLength(1));
    expect(_segments(canvas.invocations), <(Offset, Offset)>[
      (const Offset(10, 0), const Offset(10, 6)),
      (const Offset(10, 11), const Offset(10, 21)),
      (const Offset(10, 26), const Offset(10, 30)),
    ]);

    // Without a pattern it is a plain line.
    final TestRecordingCanvas plain = TestRecordingCanvas();
    ChartPainter.drawDashedLine(plain, Offset.zero, const Offset(5, 5), paint, const <double>[]);
    expect(plain.invocations.single.invocation.memberName, #drawLine);
  });

  group('a dashed LineSeries', () {
    // Rows one unit apart whose pieces all have another length.
    final ChartData data = ChartData.generate(
      60,
      (int i) => (i.toDouble(), 50 + 37 * ((i * 7) % 5 - 2) / 2 + (i % 3) * 3.0),
    );

    for (final LineCurve curve in LineCurve.values) {
      for (final (String name, double span) in <(String, double)>[
        ('several rows wide', 9),
        ('narrower than the distance between two rows', 0.4),
      ]) {
        testWidgets('${curve.name}: the dashes stay on the line while it is panned, '
            'in a window $name', (WidgetTester tester) async {
          final ChartController c = ChartController();
          addTearDown(c.dispose);
          await tester.pumpWidget(
            host(
              Chart(
                controller: c,
                x: LinearScale(range: FixedRange(20.3, 20.3 + span)),
                y: _y,
                children: <Widget>[
                  LineSeries(data: data, curve: curve, dash: const <double>[7, 4]),
                ],
              ),
            ),
          );

          // Where every dash that starts inside the plot starts, in the data.
          List<Offset> dashStarts() {
            final ChartView view = c.view!;
            final LineSeriesPainter painter =
                tester.widget<ChartPaint>(find.byType(ChartPaint)).painter as LineSeriesPainter;
            final TestRecordingCanvas canvas = TestRecordingCanvas();
            painter.paint(ChartPaintContext(canvas: canvas, view: view));
            final ui.Path path =
                canvas.invocations
                        .firstWhere((RecordedInvocation i) => i.invocation.memberName == #drawPath)
                        .invocation
                        .positionalArguments
                        .first
                    as ui.Path;
            return <Offset>[
              for (final ui.PathMetric metric in path.computeMetrics())
                if (metric.getTangentForOffset(0)!.position case final Offset p
                    when p.dx > 2 && p.dx < view.size.width - 2)
                  Offset(view.x.toValue(p.dx), view.y.toValue(p.dy)),
            ];
          }

          List<Offset> previous = dashStarts();
          double previousMax = c.view!.x.max;
          expect(previous.length, greaterThan(3));
          int compared = 0;
          double shift = 0;
          for (int step = 0; step < 30; step++) {
            // Uneven steps, so rows leave the window at different moments.
            shift += span * (0.07 + 0.03 * (step % 3));
            c.x.jumpTo(20.3 + shift, 20.3 + span + shift);
            await tester.pump();
            final ChartView view = c.view!;
            Offset pixel(Offset data) => Offset(view.x.toPixel(data.dx), view.y.toPixel(data.dy));
            final List<Offset> now = dashStarts();
            // A dash that both windows show starts at the same place on the line.
            final double seenBefore = view.x.toPixel(previousMax) - 4;
            for (final Offset dash in now.where((Offset d) => pixel(d).dx < seenBefore)) {
              compared++;
              final double nearest = previous
                  .map((Offset b) => (pixel(b) - pixel(dash)).distance)
                  .reduce((double a, double b) => a < b ? a : b);
              expect(
                nearest,
                lessThan(0.3),
                reason: 'step $step: the dash at $dash moved $nearest px along the line',
              );
            }
            previous = now;
            previousMax = view.x.max;
          }
          expect(compared, greaterThan(100));
        });
      }
    }
  });

  group('dashed chrome', () {
    testWidgets('a dashed grid moves with the data', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: const LinearScale(range: FixedRange(0, 100)),
            y: _y,
            children: const <Widget>[
              ChartGrid(dash: <double>[6, 4]),
            ],
          ),
        ),
      );
      List<(Offset, Offset)> vertical() =>
          _segments(_callsOf(tester, 0)).where(((Offset, Offset) s) => s.$1.dx == s.$2.dx).toList();
      List<(Offset, Offset)> horizontal() =>
          _segments(_callsOf(tester, 0)).where(((Offset, Offset) s) => s.$1.dy == s.$2.dy).toList();

      final ChartView view = c.view!;
      expect(view.x.ticks, isNotEmpty);
      // Every vertical line is dashed over the height of the plot.
      final double firstX = view.x.toPixel(view.x.ticks.first.value);
      final List<(Offset, Offset)> first = vertical()
          .where(((Offset, Offset) s) => s.$1.dx == firstX)
          .toList();
      expect(first.first.$1.dy, 0);
      expect(first.last.$2.dy, inInclusiveRange(290, 300));
      expect(first[1].$1.dy - first[0].$1.dy, closeTo(10, 1e-3));
      expect(horizontal(), isNotEmpty);

      // Panning along y by 3 px moves the dashes of the vertical lines by 3 px.
      final double before = first[1].$1.dy;
      c.y.jumpTo(1, 101);
      await tester.pump();
      final List<(Offset, Offset)> moved = vertical()
          .where(((Offset, Offset) s) => s.$1.dx == firstX)
          .toList();
      expect(
        moved.any(((Offset, Offset) s) => (s.$1.dy - (before + 3)).abs() < 1e-3),
        isTrue,
        reason: 'dashes start at ${moved.map(((Offset, Offset) s) => s.$1.dy).take(4)}',
      );
    });

    testWidgets('a grid without a dash draws plain lines', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const Chart(
            x: LinearScale(range: FixedRange(0, 100)),
            y: _y,
            children: <Widget>[ChartGrid()],
          ),
        ),
      );
      final Iterable<Symbol> calls = _callsOf(
        tester,
        0,
      ).map((RecordedInvocation i) => i.invocation.memberName);
      expect(calls, contains(#drawLine));
      expect(calls, isNot(contains(#drawRawPoints)));
    });

    testWidgets('a dashed crosshair', (WidgetTester tester) async {
      final ChartController c = ChartController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Chart(
            controller: c,
            x: const LinearScale(range: FixedRange(0, 100)),
            y: _y,
            children: <Widget>[
              LineSeries(data: ChartData.fromXY(<double>[0, 50, 100], <double>[0, 50, 100])),
              const ChartCrosshair(dash: <double>[4, 4], horizontal: true),
            ],
          ),
        ),
      );
      final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(203, 90)));
      await tester.pump();
      final List<(Offset, Offset)> dashes = _segments(_callsOf(tester, 1));
      // The vertical line at x = 50 and the horizontal one under the pointer.
      expect(dashes.first, (const Offset(200, 0), const Offset(200, 4)));
      expect(dashes.where(((Offset, Offset) s) => s.$1.dx == 200 && s.$2.dx == 200).length, 38);
      expect(dashes.where(((Offset, Offset) s) => s.$1.dy == 90 && s.$2.dy == 90).length, 50);
    });
  });
}

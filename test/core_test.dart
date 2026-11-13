import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

List<double> _values(ChartTicks ticks, double min, double max, {double extent = 400}) => ticks
    .generate(ChartTickContext(min: min, max: max, extent: extent, direction: Axis.horizontal))
    .map((ChartTick t) => t.value)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ticks', () {
    test('linear ticks are nice numbers inside the window', () {
      expect(_values(const LinearTicks(), 0, 100), <double>[0, 25, 50, 75, 100]);
      expect(_values(const LinearTicks(), 3, 97), <double>[25, 50, 75]);
      expect(_values(const LinearTicks(), 0, 1), <double>[0, 0.25, 0.5, 0.75, 1]);
      expect(_values(const LinearTicks(), -0.3, 0.3, extent: 600).contains(0), isTrue);
    });

    test('linear tick labels carry just enough decimals', () {
      final List<ChartTick> ticks = const LinearTicks().generate(
        const ChartTickContext(min: 0, max: 1, extent: 400, direction: Axis.horizontal),
      );
      expect(ticks.map((ChartTick t) => t.label), <String>['0.00', '0.25', '0.50', '0.75', '1.00']);
    });

    test('log ticks sit on powers of the base', () {
      expect(_values(const LogTicks(), 1, 10000, extent: 600), <double>[1, 10, 100, 1000, 10000]);
      // Crowded decades are thinned out.
      expect(_values(const LogTicks(), 1, 10000, extent: 300), <double>[1, 100, 10000]);
      expect(_values(const LogTicks(), 1, 10, extent: 600), <double>[1, 2, 5, 10]);
      // Room for every mantissa.
      expect(_values(const LogTicks(), 1, 10, extent: 1000), <double>[
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ]);
      // Small values come out as the exact decimals, with labels to match.
      final List<ChartTick> small = const LogTicks().generate(
        const ChartTickContext(min: 0.001, max: 0.01, extent: 1000, direction: Axis.horizontal),
      );
      expect(small.map((ChartTick t) => t.label), contains('0.003'));
      expect(small.map((ChartTick t) => t.value), contains(0.003));
      // Narrower than the decade structure: linear steps instead of one lonely tick.
      expect(_values(const LogTicks(), 65, 190, extent: 1200), <double>[
        70,
        80,
        90,
        100,
        110,
        120,
        130,
        140,
        150,
        160,
        170,
        180,
        190,
      ]);
    });

    test('band ticks are whole numbers with category labels', () {
      final List<ChartTick> ticks = const BandTicks(labels: <String>['a', 'b', 'c']).generate(
        const ChartTickContext(min: -0.5, max: 2.5, extent: 300, direction: Axis.horizontal),
      );
      expect(ticks.map((ChartTick t) => t.label), <String>['a', 'b', 'c']);
    });

    test('time ticks change unit with the zoom level', () {
      final double start = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch.toDouble();
      const TimeTicks ticks = TimeTicks(utc: true);
      final List<ChartTick> year = ticks.generate(
        ChartTickContext(
          min: start,
          max: start + 365 * 86400e3,
          extent: 800,
          direction: Axis.horizontal,
        ),
      );
      expect(year.first.label, '2026');
      expect(year[1].label, 'Apr');
      final List<ChartTick> day = ticks.generate(
        ChartTickContext(min: start, max: start + 86400e3, extent: 800, direction: Axis.horizontal),
      );
      expect(day.first.label, 'Jan 1');
      expect(day[1].label, '03:00');
    });
  });

  group('scale controller', () {
    test('zoom keeps the anchor value fixed', () {
      final ChartScaleController c = ChartScaleController()
        ..configure(const LinearScale(range: FixedRange(0, 100)));
      c.zoomBy(2, anchor: 25);
      expect(c.range, const ChartRange(12.5, 62.5));
      c.dispose();
    });

    test('pan and zoom are linear in scale space on a log scale', () {
      final ChartScaleController c = ChartScaleController()
        ..configure(const LogScale(range: FixedRange(1, 10000)));
      c.panBy(1); // one decade
      expect(c.min, moreOrLessEquals(10, epsilon: 1e-9));
      expect(c.max, moreOrLessEquals(100000, epsilon: 1e-6));
      c.zoomBy(2, anchor: 1000);
      expect(c.max / c.min, moreOrLessEquals(100, epsilon: 1e-6));
      c.dispose();
    });

    test('limits clamp panning and zooming', () {
      final ChartScaleController c = ChartScaleController()
        ..configure(
          const LinearScale(
            range: FixedRange(0, 100),
            limits: ChartLimits(min: 0, max: 200, minSpan: 10),
          ),
        );
      c.panBy(-50);
      expect(c.range, const ChartRange(0, 100));
      expect(c.canPanBy(-1), isFalse);
      expect(c.canPanBy(1), isTrue);
      c.panBy(500);
      expect(c.range, const ChartRange(100, 200));
      c.zoomBy(1000);
      expect(c.max - c.min, 10);
      expect(c.canZoomBy(2), isFalse);
      c.zoomBy(0.001);
      expect(c.range, const ChartRange(0, 200));
      expect(c.panRoom, (0.0, 0.0));
      c.dispose();
    });

    test('a changed policy returns the scale to automatic; an equal one does not', () {
      final ChartScaleController c = ChartScaleController()
        ..configure(const LinearScale(range: FixedRange(0, 100)));
      c.jumpTo(10, 20);
      c.configure(const LinearScale(range: FixedRange(0, 100)));
      expect(c.isAuto, isFalse);
      c.configure(const LinearScale(range: FixedRange(0, 50)));
      expect(c.isAuto, isTrue);
      expect(c.range, const ChartRange(0, 50));
      // Switching the transform keeps the same data values in view.
      c.jumpTo(10, 1000);
      c.configure(const LogScale(range: FixedRange(0, 50)));
      expect(c.min, moreOrLessEquals(10, epsilon: 1e-9));
      expect(c.max, moreOrLessEquals(1000, epsilon: 1e-9));
      c.dispose();
    });
  });

  group('chart data', () {
    test('rows can be added at both ends with stable ordinals', () {
      final ChartData d = ChartData()
        ..add(10, 1)
        ..add(11, 2);
      expect(d.firstOrdinal, 0);
      d.prependAll(<double>[7, 8, 9], <double>[5, 6, 7]);
      expect(d.length, 5);
      expect(d.x(0), 7);
      expect(d.x(4), 11);
      expect(d.firstOrdinal, -3);
      expect(d.isSorted, isTrue);
      d.removeFirst(2);
      expect(d.x(0), 9);
      expect(d.firstOrdinal, -1);
      d.add(5, 0);
      expect(d.isSorted, isFalse);
    });

    test('a sliding window keeps its storage bounded', () {
      // Live data: append a sample, evict the oldest. Evicted rows must not be
      // carried into every new allocation, or a chart that runs for hours
      // allocates ever larger arrays.
      final ChartData d = ChartData();
      for (int i = 0; i < 1000; i++) {
        d.add(i.toDouble(), 0);
      }
      for (int i = 1000; i < 200000; i++) {
        d
          ..add(i.toDouble(), 0)
          ..removeFirst(1);
      }
      expect(d.length, 1000);
      expect(d.x(0), 199000);
      expect(d.firstOrdinal, 199000);
      expect(d.debugCapacity, lessThan(4 * 1000));
      d.prependAll(<double>[198998, 198999], <double>[0, 0]);
      expect(d.x(0), 198998);
      expect(d.firstOrdinal, 198998);
    });

    test('range queries and interpolation', () {
      final ChartData d = ChartData.fromXY(
        <double>[0, 10, 20, 30],
        <double>[0, 100, double.nan, 300],
      );
      expect(d.indexRange(5, 25, overscan: 0), (1, 3));
      expect(d.indexRange(5, 25), (0, 4));
      expect(d.interpolate(5), 50);
      expect(d.interpolate(15), isNull, reason: 'next to a gap');
      expect(d.interpolate(40), isNull);
      expect(d.nearestIndex(26), 3);
      expect(d.valueExtent(), const ChartRange(0, 300));
    });

    test('the min/max index agrees with a brute-force scan', () {
      final math.Random random = math.Random(7);
      final ChartData d = ChartData();
      final List<double> ys = <double>[];
      void check() {
        for (int k = 0; k < 200; k++) {
          final int a = random.nextInt(d.length);
          final int b = a + random.nextInt(d.length - a) + 1;
          double lo = double.infinity;
          double hi = double.negativeInfinity;
          for (int i = a; i < b; i++) {
            if (ys[i] < lo) lo = ys[i];
            if (ys[i] > hi) hi = ys[i];
          }
          expect(d.minMax(a, b), (lo, hi), reason: 'rows [$a, $b)');
          final (int minIndex, int maxIndex) = d.argMinMax(a, b);
          expect(ys[minIndex], lo);
          expect(ys[maxIndex], hi);
          expect(minIndex >= a && minIndex < b && maxIndex >= a && maxIndex < b, isTrue);
        }
      }

      for (int i = 0; i < 60000; i++) {
        final double v = i % 97 == 0 ? double.nan : random.nextDouble() * 1000 - 500;
        ys.add(v);
        d.add(i.toDouble(), v);
      }
      check();
      // Appending keeps the index up to date incrementally.
      for (int i = 60000; i < 75000; i++) {
        final double v = random.nextDouble() * 5000;
        ys.add(v);
        d.add(i.toDouble(), v);
      }
      check();
      // Prepending rebuilds it.
      d.prependAll(<double>[-2, -1], <double>[9999, -9999]);
      ys.insertAll(0, <double>[9999, -9999]);
      check();
    });

    test('stacked layers carry their base', () {
      final List<ChartData> layers = ChartData.stacked(<ChartData>[
        ChartData.fromValues(<double>[1, 2]),
        ChartData.fromValues(<double>[10, 20]),
      ]);
      expect(layers[1].value(1, 0), 22);
      expect(layers[1].value(1, 1), 2);
    });
  });

  group('decimation', () {
    testWidgets('a decimated line covers the same pixels as the full line', (
      WidgetTester tester,
    ) async {
      final math.Random random = math.Random(3);
      double y = 0;
      final ChartData data = ChartData.generate(200000, (int i) {
        y += random.nextDouble() - 0.5;
        return (i.toDouble(), y);
      });
      Future<Uint8List> render(bool decimate) async {
        await tester.pumpWidget(
          host(
            RepaintBoundary(
              key: ValueKey<bool>(decimate),
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Chart(
                  children: <Widget>[
                    LineSeries(
                      data: data,
                      decimate: decimate,
                      color: const Color(0xFF000000),
                      width: 1,
                      isolate: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final RenderRepaintBoundary boundary = tester.renderObject(
          find.byKey(ValueKey<bool>(decimate)),
        );
        late Uint8List bytes;
        await tester.runAsync(() async {
          final ui.Image image = await boundary.toImage();
          bytes = (await image.toByteData())!.buffer.asUint8List();
          image.dispose();
        });
        return bytes;
      }

      final Uint8List full = await render(false);
      final Uint8List reduced = await render(true);
      expect(reduced.length, full.length);

      // Ground truth: the highest and lowest data pixel in every column.
      const int width = 400;
      const int height = 300;
      final ChartRange range = data.valueExtent()!;
      final List<double> top = List<double>.filled(width, double.infinity);
      final List<double> bottom = List<double>.filled(width, double.negativeInfinity);
      for (int i = 0; i < data.length; i++) {
        final int column = math.min(width - 1, (data.x(i) / (data.length - 1) * width).floor());
        final double pixel = height - (data.y(i) - range.min) / range.span * height;
        if (pixel < top[column]) top[column] = pixel;
        if (pixel > bottom[column]) bottom[column] = pixel;
      }

      void check(Uint8List image, String name) {
        for (int x = 2; x < width - 2; x++) {
          int inkTop = -1;
          int inkBottom = -1;
          for (int y = 0; y < height; y++) {
            if (image[(y * width + x) * 4] < 200) {
              if (inkTop < 0) inkTop = y;
              inkBottom = y;
            }
          }
          expect(inkTop, greaterThanOrEqualTo(0), reason: '$name: column $x has no ink');
          // No extreme is lost...
          expect(inkTop, lessThanOrEqualTo(top[x] + 1.5), reason: '$name: peak lost in column $x');
          expect(
            inkBottom + 1,
            greaterThanOrEqualTo(bottom[x] - 1.5),
            reason: '$name: trough lost in column $x',
          );
          // ...and none is invented: ink stays within what this column and
          // its neighbours (the stroke is a pixel wide) actually contain.
          final double highest = math.min(top[x - 1], math.min(top[x], top[x + 1]));
          final double lowest = math.max(bottom[x - 1], math.max(bottom[x], bottom[x + 1]));
          expect(inkTop, greaterThanOrEqualTo(highest - 1.5), reason: '$name: column $x');
          expect(inkBottom, lessThanOrEqualTo(lowest + 1.5), reason: '$name: column $x');
        }
      }

      check(full, 'full');
      check(reduced, 'decimated');

      // Overall the two renderings are the same picture.
      int difference = 0;
      for (int i = 0; i < full.length; i += 4) {
        difference += (full[i] - reduced[i]).abs();
      }
      expect(difference / (width * height) / 255, lessThan(0.01));
    });
  });

  test('built-in series, layers and behaviors use only the public API', () {
    final RegExp import = RegExp(r'''^import\s+'([^']+)';''', multiLine: true);
    for (final String folder in <String>['series', 'layers', 'behaviors']) {
      for (final FileSystemEntity entity in Directory('lib/src/$folder').listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final RegExpMatch match in import.allMatches(entity.readAsStringSync())) {
          final String uri = match.group(1)!;
          final bool allowed =
              uri.startsWith('dart:') ||
              uri.startsWith('package:flutter/') ||
              uri == '../../plot_twist.dart';
          expect(allowed, isTrue, reason: '${entity.path} imports $uri');
        }
      }
    }
  });

  test('the package does not depend on Material or Cupertino', () {
    for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final String source = entity.readAsStringSync();
      expect(source.contains('package:flutter/material.dart'), isFalse, reason: entity.path);
      expect(source.contains('package:flutter/cupertino.dart'), isFalse, reason: entity.path);
      expect(source.contains('package:material_ui'), isFalse, reason: entity.path);
    }
  });
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';
import 'package:plot_twist_example/demos/a18_accessibility.dart';
import 'package:plot_twist_example/demos/a19_transitions.dart';
import 'package:plot_twist_example/demos/a21_polar.dart';
import 'package:plot_twist_example/demos/a26_candlesticks.dart';
import 'package:plot_twist_example/main.dart';
import 'package:plot_twist_example/shared/fake.dart';
import 'package:plot_twist_example/shared/ui.dart';

/// Where screenshots of every demo are written for visual inspection.
final Directory screenshots = Directory('build/screenshots');

Future<void> _loadFonts() async {
  final String fonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('$fonts/$name').readAsBytes());
  final FontLoader roboto = FontLoader('Roboto')
    ..addFont(read('Roboto-Regular.ttf'))
    ..addFont(read('Roboto-Medium.ttf'))
    ..addFont(read('Roboto-Bold.ttf'));
  final FontLoader icons = FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'));
  await roboto.load();
  await icons.load();
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    screenshots.createSync(recursive: true);
  });

  for (final Demo demo in demos) {
    testWidgets('${demo.id} ${demo.title} runs and survives interaction', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(2000, 1400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final GlobalKey shot = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: shot,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(colorSchemeSeed: const Color(0xFF3F6FB5), fontFamily: 'Roboto'),
            home: DemoPage(demo: demo),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: 'while building');
      expect(find.byType(Chart), findsWidgets);

      // Poke it the way a user would: hover, drag across the plot, scroll.
      final Offset centre = tester.getCenter(find.byType(Chart).first);
      final TestPointer mouse = TestPointer(99, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(centre));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'while hovering');

      final TestGesture drag = await tester.startGesture(centre + const Offset(40, 0));
      await drag.moveBy(const Offset(-24, 4));
      await drag.moveBy(const Offset(-90, 12));
      await tester.pump();
      await drag.up();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'while dragging');

      await tester.sendEventToBinding(mouse.hover(centre + const Offset(30, -10)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -80)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'while scrolling the wheel');

      final RenderRepaintBoundary boundary = tester.renderObject(find.byKey(shot));
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: 2);
        final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${screenshots.path}/${demo.id.toLowerCase()}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });

      // Dispose the demo and let its timers run out.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'while disposing');
    });
  }

  testWidgets('A18: a screen reader can step through the bars; arrow keys move the focus', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: AccessibilityDemo()),
        ),
      ),
    );
    await tester.pump();
    final ChartController chart = ChartScope.of(tester.element(find.byType(ChartGrid))).controller;
    final ChartView view = chart.view!;

    expect(find.bySemanticsLabel(RegExp('^Revenue by month')), findsOneWidget);
    for (final String month in months) {
      expect(find.bySemanticsLabel(RegExp('^$month: ')), findsOneWidget);
    }
    // The node covers its bar: March is band 2.
    final Rect march = tester.getRect(find.bySemanticsLabel('Mar: 4.2 thousand'));
    final Offset plot = tester.getTopLeft(find.byType(ChartGrid));
    expect(march.center.dx, moreOrLessEquals(plot.dx + view.x.toPixel(2), epsilon: 0.01));
    expect(
      march.width,
      moreOrLessEquals(view.x.toPixel(2.35) - view.x.toPixel(1.65), epsilon: 0.01),
    );

    // Activating a node focuses its bar, which is what the tooltip follows.
    tester.semantics.tap(find.semantics.byLabel('Mar: 4.2 thousand'));
    await tester.pump();
    expect(chart.focus.value?.x, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(chart.focus.value?.x, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(chart.focus.value?.x, 1);
    semantics.dispose();
  });

  testWidgets('A19: the button lays the bars down, and every bar keeps its label', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final GlobalKey shot = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: shot,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: const Color(0xFF3F6FB5), fontFamily: 'Roboto'),
          home: const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: TransitionsDemo()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final ChartController chart = ChartScope.of(tester.element(find.byType(ChartGrid))).controller;
    int labels() {
      final TestRecordingCanvas canvas = TestRecordingCanvas();
      tester
          .renderObject(
            find.descendant(of: find.byType(ChartDataLabels), matching: find.byType(ChartPaint)),
          )
          .paint(TestRecordingPaintingContext(canvas), Offset.zero);
      return canvas.invocations
          .where((RecordedInvocation i) => i.invocation.memberName == #drawParagraph)
          .length;
    }

    // Seven columns: the bands run along x and the values up.
    expect(chart.x.range, const ChartRange(-0.5, 6.5));
    expect(chart.hitsAt(2).single.valueAxis, Axis.vertical);
    expect(labels(), 7);

    await tester.tap(find.byIcon(Icons.rotate_90_degrees_cw));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    // The same data, lying: the bands run down y, and the values start at zero on x.
    expect(chart.y.range, const ChartRange(-0.5, 6.5));
    expect(chart.x.range.min, 0);
    final ChartView view = chart.view!;
    expect(view.y.toPixel(0), lessThan(view.y.toPixel(6)), reason: 'the first bar is on top');
    final ChartHit bar = chart
        .hitTest(Offset(10, view.y.toPixel(2)), mode: ChartHitMode.nearestY)
        .single;
    expect(bar.valueAxis, Axis.horizontal);
    expect(bar.index, 2);
    expect(bar.rect!.left, moreOrLessEquals(view.x.toPixel(0), epsilon: 0.01));
    expect(labels(), 7);

    // The transition between periods works lying down too.
    await tester.tap(find.text('Year'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(chart.y.range, const ChartRange(-0.5, 11.5));
    expect(labels(), 12);

    final RenderRepaintBoundary boundary = tester.renderObject(find.byKey(shot));
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 2);
      final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${screenshots.path}/a19_lying.png').writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets('A21: the legend pulls a slice out, the slider moves the gauge, the radar is hit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: const Color(0xFF3F6FB5), fontFamily: 'Roboto'),
        home: const Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: PolarDemo()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    ChartController chartOf(Type series) =>
        ChartScope.of(tester.element(find.byType(series).first)).controller;
    Offset plotOf(Type series) => tester.getTopLeft(
      find.ancestor(of: find.byType(series).first, matching: find.byType(ChartStack)).first,
    );

    // The doughnut: five slices, each with a share and a legend item.
    final ChartController pie = chartOf(PieSeries);
    List<ChartHit> slices() {
      final List<ChartHit> marks = <ChartHit>[];
      pie.series.single.visitMarks(pie.view!, (ChartHit mark) {
        marks.add(mark);
        return true;
      });
      return marks;
    }

    expect(slices().map((ChartHit mark) => mark.label), <String>[
      'Rent',
      'Food',
      'Travel',
      'Savings',
      'Fun',
    ]);
    final Offset before = slices()[1].sector!.center;
    await tester.tap(find.text('Food'));
    await tester.pump();
    expect((slices()[1].sector!.center - before).distance, moreOrLessEquals(8, epsilon: 1e-6));
    expect(slices()[0].sector!.center, before, reason: 'the others stay');

    // Pointing at a slice names it.
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(plotOf(PieSeries) + slices()[0].position));
    await tester.pump();
    expect(find.text('Rent: '), findsOneWidget);

    // The gauge reads 72 and follows the slider.
    final ChartController gauge = chartOf(RadialBarSeries);
    double reading() => gauge.series.single.bounds()!.x!.max;
    expect(find.text('72%'), findsOneWidget);
    expect(reading(), 72);
    final Rect slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(slider.left + slider.width * 0.25, slider.center.dy));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final int value = int.parse(
      tester.widget<Text>(find.textContaining('%').last).data!.replaceAll('%', ''),
    );
    expect(value, inInclusiveRange(20, 30));
    expect(reading(), moreOrLessEquals(value.toDouble(), epsilon: 0.5));

    // The radar: pointing between the centre and "Range" lists both models.
    final ChartController radar = chartOf(RadarSeries);
    final ChartView view = radar.view!;
    final ChartPolarView circle = ChartPolarScope.of(tester.element(find.byType(RadarSeries).first))
        .resolve(view);
    await tester.sendEventToBinding(mouse.hover(plotOf(RadarSeries) + circle.toPixel(1, 3)));
    await tester.pump();
    expect(find.text('Model A: '), findsOneWidget);
    expect(find.text('Model B: '), findsOneWidget);
    expect(radar.hitsFor(radar.focus.value!).map((ChartHit hit) => hit.value).toSet(), <double>{
      6,
      9,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('A26: the window follows the trading candle; zoomed out, a pixel column is one', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: CandlesticksDemo()),
        ),
      ),
    );
    await tester.pump();
    final ChartController chart = ChartScope.of(tester.element(find.byType(ChartGrid))).controller;
    final ChartSeries candles = chart.series.firstWhere((ChartSeries s) => s.label == 'ACME');
    String price(int day) => candles.valueAt(day.toDouble())!.toStringAsFixed(2);

    // 5,000 days are loaded. The window shows the newest 90, with room for
    // two more, and the pill on the axis shows the last close.
    expect(candles.bounds()!.x!.max, 4999.35);
    expect(chart.x.range, const ChartRange(4911.35, 5001.35));
    expect(find.text(price(4999)), findsOneWidget);

    // A trade arrives every 100 ms and a day is 30 trades: the last candle
    // moves, then the next one opens and the window follows it.
    final String before = price(4999);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(price(4999), isNot(before));
    expect(find.text(price(4999)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
    expect(candles.valueAt(5000), isNotNull);
    expect(chart.x.range, const ChartRange(4912.35, 5002.35));

    // Pointing at a candle shows its four prices and its volume.
    chart.focus.value = const ChartFocus(x: 4990);
    await tester.pump();
    final ChartCandle pointed = chart
        .hitsAt(4990)
        .map((ChartHit hit) => hit.datum)
        .whereType<ChartCandle>()
        .single;
    expect(find.textContaining('C ${pointed.close.toStringAsFixed(2)}   Vol '), findsOneWidget);
    chart.focus.value = null;

    // Panning away stops the following until the scale is reset.
    await tester.dragFrom(tester.getCenter(find.byType(ChartGrid)), const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 3000));
    expect(chart.x.isAuto, isFalse);
    expect(chart.x.max, lessThan(5002));

    // All 5,003 days at once: fewer boxes than candles, at most one per
    // pixel column.
    chart.x.jumpTo(-10, 5010);
    await tester.pump();
    final ChartView view = chart.view!;
    final ChartPainter painter = tester
        .widgetList<ChartPaint>(find.byType(ChartPaint))
        .map((ChartPaint paint) => paint.painter)
        .firstWhere((ChartPainter painter) => painter is CandlestickSeriesPainter);
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    painter.paint(ChartPaintContext(canvas: canvas, view: view));
    final int boxes = canvas.invocations.fold(
      0,
      (int sum, RecordedInvocation call) =>
          sum + (call.invocation.positionalArguments.first as ui.Path).computeMetrics().length,
    );
    expect(view.size.width, lessThan(5000));
    expect(boxes, inInclusiveRange(view.size.width * 0.9, view.size.width));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  group('each aspect is easy', () {
    final RegExp import = RegExp(r'''^import\s+'([^']+)'(?:\s+as\s+\w+)?;''', multiLine: true);

    // Lines that are neither blank nor comments.
    int counted(String source) => source
        .split('\n')
        .where((String l) => l.trim().isNotEmpty && !l.trim().startsWith('//'))
        .length;

    test('every demo is one small file written against the public API', () {
      final List<File> files = Directory('lib/demos').listSync().whereType<File>().toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
      expect(files.length, demos.length);
      final StringBuffer report = StringBuffer();
      for (final File file in files) {
        final String source = file.readAsStringSync();
        final int lines = counted(source);
        report.writeln('${file.uri.pathSegments.last.padRight(32)} $lines');
        expect(lines, lessThanOrEqualTo(120), reason: '${file.path} is too long');
        for (final RegExpMatch match in import.allMatches(source)) {
          final String uri = match.group(1)!;
          final bool allowed =
              uri.startsWith('dart:') ||
              uri.startsWith('package:flutter/') ||
              uri == 'package:material_ui/material_ui.dart' ||
              uri == 'package:plot_twist/plot_twist.dart' ||
              uri.startsWith('../shared/');
          expect(allowed, isTrue, reason: '${file.path} imports $uri');
        }
      }
      File('${screenshots.path}/line_counts.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync(report.toString());
    });

    test('the README and doc/aspects.md give the line counts of the demos', () {
      final Map<String, int> lines = <String, int>{
        for (final File file in Directory('lib/demos').listSync().whereType<File>())
          'A${int.parse(RegExp(r'^a(\d+)_').firstMatch(file.uri.pathSegments.last)!.group(1)!)}':
              counted(file.readAsStringSync()),
      };
      // The gallery table of the README: "| A2 | 2D pan and zoom | 54 |".
      final String readme = File('../README.md').readAsStringSync();
      final Map<String, int> inReadme = <String, int>{
        for (final RegExpMatch m in RegExp(r'\| (A\d+) \| [^|\n]+ \| (\d+) ').allMatches(readme))
          m.group(1)!: int.parse(m.group(2)!),
      };
      expect(inReadme, lines);
      // The summary table of doc/aspects.md, whose fifth column is the count,
      // and the sentence with the total.
      final String aspects = File('../doc/aspects.md').readAsStringSync();
      final Map<String, int> inAspects = <String, int>{
        for (final RegExpMatch m in RegExp(
          r'^\| (A\d+) \|[^|\n]+\|[^|\n]+\|[^|\n]+\| (\d+) \|',
          multiLine: true,
        ).allMatches(aspects))
          m.group(1)!: int.parse(m.group(2)!),
      };
      expect(inAspects, lines);
      final int total = lines.values.fold(0, (int sum, int n) => sum + n);
      final String grouped = total.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (Match m) => '${m.group(1)},',
      );
      expect(
        aspects,
        contains(
          'The ${lines.length} demos have $grouped such lines in total, '
          '${(total / lines.length).round()} on average.',
        ),
      );
    });
  });
}

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plot_twist/plot_twist.dart';

import 'test_utils.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF101010);
const Color _red = Color(0xFFCC0000);
const Color _green = Color(0xFF00AA00);
const Color _blue = Color(0xFF0000CC);

/// The theme a chart below [wrap] would get.
Future<ChartThemeData> _themeUnder(WidgetTester tester, Widget Function(Widget child) wrap) async {
  late ChartThemeData theme;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: wrap(
        Builder(
          builder: (BuildContext context) {
            theme = ChartTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return theme;
}

void main() {
  testWidgets('without a ChartTheme, charts follow the ambient text colour', (
    WidgetTester tester,
  ) async {
    // Light text means a dark surface.
    final ChartThemeData onDark = await _themeUnder(
      tester,
      (Widget child) => DefaultTextStyle(
        style: const TextStyle(color: _white, fontSize: 20),
        child: child,
      ),
    );
    expect(onDark.foreground, _white);
    expect(onDark, ChartThemeData.fallback(foreground: _white, brightness: Brightness.dark));
    expect(onDark.labelStyle.fontSize, 11, reason: 'labels keep their own size');
    expect(onDark.tooltipColor.computeLuminance(), greaterThan(0.5));

    final ChartThemeData onLight = await _themeUnder(
      tester,
      (Widget child) => DefaultTextStyle(
        style: const TextStyle(color: _ink),
        child: child,
      ),
    );
    expect(onLight.foreground, _ink);
    expect(onLight.tooltipColor.computeLuminance(), lessThan(0.5));
  });

  testWidgets('with no text colour, the platform brightness decides', (WidgetTester tester) async {
    final ChartThemeData dark = await _themeUnder(
      tester,
      (Widget child) => MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
        child: child,
      ),
    );
    expect(dark, ChartThemeData.fallback(brightness: Brightness.dark));

    final ChartThemeData light = await _themeUnder(tester, (Widget child) => child);
    expect(light, ChartThemeData.fallback());
    expect(light.foreground.computeLuminance(), lessThan(dark.foreground.computeLuminance()));
  });

  testWidgets('a ChartTheme reaches the series, the grid and the axis labels', (
    WidgetTester tester,
  ) async {
    final ChartController c = ChartController();
    addTearDown(c.dispose);
    final ChartData data = ChartData.fromValues(<double>[10, 50, 90]);
    final ChartThemeData theme = ChartThemeData.fallback().copyWith(
      palette: const <Color>[_red],
      gridColor: _green,
      axisColor: _blue,
      labelStyle: const TextStyle(fontSize: 9, color: _blue),
    );
    await tester.pumpWidget(
      host(
        ChartTheme(
          data: theme,
          child: Chart(
            controller: c,
            y: const LinearScale(range: FixedRange(0, 100)),
            left: const <Widget>[ChartAxis()],
            children: <Widget>[
              const ChartGrid(),
              LineSeries(data: data),
              BarSeries(data: data),
              ScatterSeries(data: data),
            ],
          ),
        ),
      ),
    );
    expect(c.series.map((ChartSeries s) => s.color), <Color?>[_red, _red, _red]);

    final RenderParagraph label = tester.renderObject(
      find.descendant(of: find.byType(ChartAxis), matching: find.byType(RichText)).first,
    );
    expect(label.text.style?.color, _blue);
    expect(label.text.style?.fontSize, 9);

    final ChartPainter grid = tester
        .widgetList<ChartPaint>(find.byType(ChartPaint))
        .map((ChartPaint paint) => paint.painter)
        .firstWhere((ChartPainter painter) => painter is! ChartSeriesPainter);
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    grid.paint(ChartPaintContext(canvas: canvas, view: c.view!));
    expect(canvas.invocations, isNotEmpty);
    for (final RecordedInvocation call in canvas.invocations) {
      expect(call.invocation.memberName, #drawLine);
      final Paint paint = call.invocation.positionalArguments[2] as Paint;
      expect(paint.color.toARGB32(), _green.toARGB32());
    }

    // An explicit colour wins over the palette.
    await tester.pumpWidget(
      host(
        ChartTheme(
          data: theme,
          child: Chart(
            controller: c,
            children: <Widget>[LineSeries(data: data, color: _green)],
          ),
        ),
      ),
    );
    expect(c.series.single.color, _green);
  });

  test('themes compare by value, and the palette wraps around', () {
    final ChartThemeData theme = ChartThemeData.fallback();
    expect(theme, ChartThemeData.fallback());
    expect(theme.hashCode, ChartThemeData.fallback().hashCode);
    expect(theme.copyWith(), theme);

    final ChartThemeData changed = theme.copyWith(
      gridColor: _red,
      palette: const <Color>[_red, _blue],
    );
    expect(changed, isNot(theme));
    expect(changed.gridColor, _red);
    expect(changed.axisColor, theme.axisColor, reason: 'the rest is kept');
    expect(changed.seriesColor(0), _red);
    expect(changed.seriesColor(1), _blue);
    expect(changed.seriesColor(2), _red);
    expect(theme.seriesColor(8), ChartThemeData.defaultPalette.first);
  });

  test('a ChartTheme notifies only for a different theme', () {
    final ChartThemeData theme = ChartThemeData.fallback();
    const Widget child = SizedBox();
    final ChartTheme old = ChartTheme(data: theme, child: child);
    expect(
      ChartTheme(data: ChartThemeData.fallback(), child: child).updateShouldNotify(old),
      isFalse,
    );
    expect(
      ChartTheme(
        data: theme.copyWith(gridColor: _red),
        child: child,
      ).updateShouldNotify(old),
      isTrue,
    );
  });
}

# Coming from fl_chart

This page maps the concepts of fl_chart onto plot_twist and shows three
charts written with each. It is meant for porting an existing chart one at a
time.

The fl_chart names on this page were verified against fl_chart 1.3.1 on
13 November 2026, and its three examples compile against that version. The
plot_twist examples compile against plot_twist 0.1.0.

## The differences that matter most

- **One widget instead of chart types.** fl_chart has a widget per chart type,
  each with its own data class: `LineChart` with `LineChartData`, `BarChart`
  with `BarChartData`, and so on. plot_twist has one `Chart`. Series are its
  children, and one chart can hold any mix of them.
- **Data lives in a store you keep.** In fl_chart, each `…ChartData` carries
  its lists of spots, and a rebuild with a new `…ChartData` describes the next
  state. A plot_twist series reads a `ChartData`: typed columns that you
  create once, keep in state and change in place. Appending a row repaints the
  series without rebuilding a widget.
- **A range is a policy, and the window is state.** fl_chart takes `minX`,
  `maxX`, `minY` and `maxY`, or computes them from all spots. A plot_twist
  scale has a range policy (`fit`, `fitVisible`, `fixed` or `follow`), and the
  window on screen lives in a `ChartController`, in data units.
- **Titles are widgets in side slots.** Instead of `FlTitlesData`, a chart has
  four lists of widgets, `left`, `top`, `right` and `bottom`, usually holding
  a `ChartAxis`. An axis measures its labels and sizes its gutter.
- **Interaction is made of children.** `ChartPanZoom`, `ChartCrosshair` and
  `ChartTooltip` are added to `children`. A chart without them has no gesture
  recognizers.

## Concept map

### Charts and data

| fl_chart 1.3.1 | plot_twist 0.1 | Notes |
|---|---|---|
| `LineChart`, `BarChart`, `ScatterChart`, `CandlestickChart` | `Chart` with `LineSeries`, `BarSeries`, `ScatterSeries` or `CandlestickSeries` children | Series of different kinds can share one chart. |
| `LineChartData`, `BarChartData`, `ScatterChartData`, `CandlestickChartData` | the arguments of `Chart`: scales, side slots and children | |
| `PieChart`, `RadarChart`, `GaugeChart` | not built in | A `ChartPainter` in `ChartPaint` can draw one. [A21](https://glynskyi.github.io/plot_twist/#/a21) draws a donut in its demo file. |
| `rotationQuarterTurns` (horizontal bar charts) | not supported in 0.1 | |
| lists of `FlSpot(x, y)` | `ChartData.fromXY(xs, ys)`, `ChartData.fromValues(ys)`, `ChartData.from<T>(items, x:, y:, more:)`, `ChartData.generate` | Change it in place with `add`, `addAll`, `addRow`, `prependAll`, `prependRows`, `removeFirst`, `setValue` or `replaceAll`. |
| `FlSpot.nullSpot` | `double.nan` as a value | A NaN leaves a gap in a line. |
| `CandlestickSpot(x:, open:, high:, low:, close:)` | a `ChartData` with four value columns, read by `CandlestickSeries` | Each hit carries a `ChartCandle` with the four prices. |
| `ScatterSpot` | a row of the `ChartData` of a `ScatterSeries` | `radius` for all dots, or `sizeColumn` per dot. |
| implicit animation (`duration`, `curve` on the chart widget) | `AnimatedChartData` | Moves a series towards new data. |

### Scales and ranges

| fl_chart 1.3.1 | plot_twist 0.1 | Notes |
|---|---|---|
| `minX`, `maxX`, `minY`, `maxY` | the scale's `range`: `.fixed(min, max)`, `.fit()`, `.fitVisible()` or `.follow(span:)` | `.fitVisible()` fits Y to the data inside the visible X window. |
| x values in `millisecondsSinceEpoch` | `ChartScale.time()` and `DateTime.chartValue` | Ticks follow the calendar and change unit with the zoom. |
| `BarChartGroupData.x` and `BarChartAlignment` | `ChartScale.band(labels:)` | Band `i` is centred on `x = i`; every bar sits at its x value. |
| a second Y range, rescaled by hand | `Chart.scales: {'name': ChartScale…}` and `yScale: 'name'` on the series | Any number of named scales; `xScales:` for horizontal ones. |
| `SideTitles.interval`, `FlGridData.horizontalInterval`, `baselineX`, `baselineY` | the scale's `ticks:`: `LinearTicks(spacing:)`, `FixedTicks`, `TimeTicks`, `BandTicks`, `LogTicks` | `spacing` is in logical pixels, so tick density holds at every zoom level. |

### Series styling

| fl_chart 1.3.1 | plot_twist 0.1 |
|---|---|
| `LineChartBarData.color`, `barWidth` | `LineSeries.color`, `width` |
| `isCurved` | `curve: LineCurve.smooth` (monotone: it never overshoots the data) |
| `isStepLineChart` | `curve: LineCurve.step` |
| `dashArray` | `dash` |
| `gradient` | `shader: (view) => …`, built from the current view, so stops can be data values |
| `belowBarData` (`BarAreaData`) | `fillColor`, `fillGradient` and `baseline` |
| `dotData` (`FlDotData`) | `pointRadius`; widget markers with `ChartPositioned` |
| `BarChartRodData.toY` | the value column of a `BarSeries` (`column`) |
| `BarChartRodData.fromY` | `baseline`, or `baseColumn` for floating bars |
| `BarChartRodData.width`, `borderRadius` | `width` (a fraction of `step`), `radius` |
| `rodStackItems` (`BarChartRodStackItem`) | `ChartData.stacked(layers)` and `BarSeries(baseColumn: 1)` |
| several rods per `BarChartGroupData`, `barsSpace` | one `BarSeries` per series, with the same `step` and a different `offset` |
| a colour per rod | `BarSeries.colorOf: (index, x, y) => …` |

### Titles, grid and decorations

| fl_chart 1.3.1 | plot_twist 0.1 | Notes |
|---|---|---|
| `FlTitlesData`, `AxisTitles`, `SideTitles` | a `ChartAxis` in `left`, `top`, `right` or `bottom` | Only the sides you fill have an axis. |
| `SideTitles.getTitlesWidget` and `SideTitleWidget` | `ChartAxis(labelBuilder: (context, tick) => …)`, or `format: (tick) => …` for text | The axis places each label. Labels are built when their tick appears, not on every frame of a pan. |
| `TitleMeta` | `ChartTick`: `value`, `label` and `level` | `label` has as many decimals as the tick spacing needs. |
| `SideTitles.reservedSize` | `ChartAxis(extent:)`: `.auto()` (the default), `.fixed(px)` or `.shared(group)` | `.auto()` measures the labels; `.shared` makes linked charts' axes equally thick. |
| `AxisTitles.axisNameWidget` | another widget in the same side slot | Side slots take any widget. |
| `FlGridData` | `ChartGrid(horizontal:, vertical:, color:, width:)` | Lines sit at the ticks of the scales. |
| `FlBorderData` | the axis lines (`ChartAxis(showLine:)`), or a `DecoratedBox` child | Children that are not positioned fill the plot. |
| `backgroundColor` | a `ColoredBox` around the chart, or as its first child | |
| `ExtraLinesData`, `HorizontalLine`, `VerticalLine` | a `ChartPainter` in `ChartPaint`, or a widget in `ChartPositioned` | [A17](https://glynskyi.github.io/plot_twist/#/a17) draws a threshold the user can drag. |
| `RangeAnnotations` (`HorizontalRangeAnnotation`, `VerticalRangeAnnotation`) | `ChartPositioned.span(y1: .value(a), y2: .value(b), child: …)` | The child can be any widget. |
| `clipData` (`FlClipData`) | `clip:` on `LineSeries` and `ChartPaint`; `overflow:` on `ChartPositioned` | |
| colours given per chart | `ChartTheme` and `ChartThemeData` | Without a theme, colours come from the ambient `DefaultTextStyle`, so charts follow light and dark mode. |

### Touch and tooltips

| fl_chart 1.3.1 | plot_twist 0.1 | Notes |
|---|---|---|
| `LineTouchData`, `BarTouchData`, … with `handleBuiltInTouches` | `ChartCrosshair` and `ChartTooltip` children | Leave them out for a chart without touch handling. |
| `touchTooltipData`, `getTooltipItems`, `LineTooltipItem`, `getTooltipColor` | `ChartTooltip(builder: (context, hits) => …)` | The builder returns any widget. `interactive: true` lets buttons inside it work; `overlay: true` lets it leave the chart. |
| `getTouchedSpotIndicator` (`TouchedSpotIndicatorData`) | `ChartCrosshair(vertical:, horizontal:, showPoints:, color:, width:, pointRadius:)` | |
| `touchCallback` and `LineTouchResponse` | `ChartController.focus` (a `ValueNotifier<ChartFocus?>`), `controller.hitsAt(x)`, `ChartGestureDetector` | The focus is in data space and can be shared between charts. |
| `showingTooltipIndicators` | `controller.focus.value = ChartFocus(x: …)` | The crosshair and the tooltip follow it. |

### Zoom and pan

| fl_chart 1.3.1 | plot_twist 0.1 | Notes |
|---|---|---|
| `FlTransformationConfig` | a `ChartPanZoom` child | |
| `scaleAxis` (`FlScaleAxis.horizontal`, `vertical`, `free`, `none`) | `ChartPanZoom(panX:, panY:, zoomX:, zoomY:)` | |
| `panEnabled`, `scaleEnabled` | the same four flags | |
| `minScale`, `maxScale` | `ChartLimits(minSpan:, maxSpan:)` on the scale | Spans are window widths in scale units. `ChartLimits(min:, max:)` and `ChartLimits.data()` bound panning. |
| `trackpadScrollCausesScale` | `ChartPanZoom(wheel: ChartWheelAction.zoom)`, `.pan` or `.none` | The wheel zooms and trackpad scrolling pans by default. |
| `transformationController` (a `TransformationController` holding a pixel `Matrix4`) | `ChartController`, with one `ChartScaleController` per scale: `chart.x.min`, `chart.x.max`, `jumpTo`, `animateTo`, `panBy`, `zoomBy`, `resetToAuto` | The window is in data units, and each scale controller is a `Listenable`. Give several charts one `ChartScaleController` to link them. |

## Example 1: a line with a tooltip

fl_chart 1.3.1:

```dart
Widget lineWithTooltip(List<double> xs, List<double> ys) {
  return LineChart(
    LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < xs.length; i++) FlSpot(xs[i], ys[i])],
          isCurved: true,
          dotData: const FlDotData(show: false),
        ),
      ],
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(),
        rightTitles: AxisTitles(),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => const Color(0xFF263238),
          getTooltipItems: (spots) => [
            for (final spot in spots)
              LineTooltipItem(
                spot.y.toStringAsFixed(1),
                const TextStyle(color: Color(0xFFFFFFFF)),
              ),
          ],
        ),
      ),
    ),
  );
}
```

plot_twist:

```dart
/// [readings] is created once and kept in state: `ChartData.fromXY(xs, ys)`.
Widget lineWithTooltip(ChartData readings) {
  return Chart(
    left: const <Widget>[ChartAxis()],
    bottom: const <Widget>[ChartAxis()],
    children: <Widget>[
      const ChartGrid(),
      LineSeries(data: readings, curve: .smooth),
      const ChartCrosshair(),
      ChartTooltip(
        builder: (BuildContext context, List<ChartHit> hits) => DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF263238)),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              hits.first.y.toStringAsFixed(1),
              style: const TextStyle(color: Color(0xFFFFFFFF)),
            ),
          ),
        ),
      ),
    ],
  );
}
```

- fl_chart shows titles on all four sides unless told otherwise; a plot_twist
  chart has axes only where you put a `ChartAxis`.
- The tooltip builder returns a widget, so it can hold icons, images or
  buttons. `ChartTooltip(interactive: true)` lets those buttons receive taps.
- `ChartCrosshair` sets the focus on hover and on a long press. Add
  `tap: true` to pin it with a tap.

## Example 2: bars and a line on two Y axes

fl_chart 1.3.1 draws bars and lines with different widgets, so this example
stacks two charts that reserve the same room on every side:

```dart
// Reserves the room of a title without drawing one.
Widget noTitle(double value, TitleMeta meta) => const SizedBox.shrink();

Widget rainAndTemperature(List<double> rain, List<double> temperature) {
  return Stack(
    children: [
      // Rain: bars, labelled on the right.
      BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: [
            for (var i = 0; i < rain.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [BarChartRodData(toY: rain[i])],
              ),
          ],
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: noTitle,
              ),
            ),
          ),
        ),
      ),
      // Temperature: a line, labelled on the left. It reserves the same room
      // on every side, so both plots line up. Only this chart gets touches.
      LineChart(
        LineChartData(
          minX: -0.5,
          maxX: temperature.length - 0.5,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < temperature.length; i++)
                  FlSpot(i.toDouble(), temperature[i]),
              ],
            ),
          ],
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: noTitle,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: noTitle,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
```

plot_twist:

```dart
/// One row per day at x = 0, 1, 2…: `ChartData.fromValues(values)`.
Widget rainAndTemperature(ChartData rain, ChartData temperature) {
  return Chart(
    x: const .band(),
    y: const .linear(range: .fit(padding: 0.1)), // temperature
    scales: const <Object, ChartScale>{
      'rain': LinearScale(range: FitDataRange(includeZero: true)),
    },
    left: const <Widget>[ChartAxis()],
    right: const <Widget>[ChartAxis(scale: 'rain')],
    bottom: const <Widget>[ChartAxis()],
    children: <Widget>[
      const ChartGrid(),
      BarSeries(data: rain, yScale: 'rain', label: 'Rain'),
      LineSeries(data: temperature, label: 'Temperature'),
      const ChartCrosshair(),
      const ChartTooltip(), // one tooltip lists both series
    ],
  );
}
```

- The second Y scale has a name, and the bar series and the right axis refer
  to it. More scales are more entries in `scales:`.
- The crosshair and the tooltip see both series, because they are in one
  chart.
- [A11](https://glynskyi.github.io/plot_twist/#/a11)
  ([source](../example/lib/demos/a11_weather_combo.dart)) adds floating
  min–max bars from a second value column.

## Example 3: a zoomable time series

fl_chart 1.3.1:

```dart
Widget zoomablePrices(
  List<DateTime> times,
  List<double> prices,
  TransformationController transformation,
) {
  return LineChart(
    LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < prices.length; i++)
              FlSpot(times[i].millisecondsSinceEpoch.toDouble(), prices[i]),
          ],
          dotData: const FlDotData(show: false),
        ),
      ],
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 30 * 24 * 60 * 60 * 1000, // a label every 30 days
            getTitlesWidget: (value, meta) {
              final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
              return SideTitleWidget(
                meta: meta,
                child: Text('${date.day}/${date.month}'),
              );
            },
          ),
        ),
      ),
    ),
    transformationConfig: FlTransformationConfig(
      scaleAxis: FlScaleAxis.horizontal,
      maxScale: 25,
      transformationController: transformation, // a Matrix4, in pixels
    ),
  );
}
```

plot_twist:

```dart
/// [prices]: x is `DateTime.chartValue` (milliseconds), y is the price.
Widget zoomablePrices(ChartData prices, ChartController chart) {
  return Chart(
    controller: chart, // chart.x.min, chart.x.max: the window, in data units
    x: const .time(limits: .data()), // tick units change as you zoom
    y: const .linear(range: .fitVisible()), // Y fits the visible data
    left: const <Widget>[ChartAxis()],
    bottom: const <Widget>[ChartAxis()],
    children: <Widget>[
      const ChartGrid(),
      LineSeries(data: prices),
      const ChartPanZoom(),
    ],
  );
}

/// The visible window, outside the chart. The chart itself is not rebuilt.
Widget visibleRange(ChartController chart) {
  return ListenableBuilder(
    listenable: chart.x,
    builder: (BuildContext context, Widget? child) => Text(
      '${TimeScale.dateOf(chart.x.min)} – ${TimeScale.dateOf(chart.x.max)}',
    ),
  );
}
```

- `ChartPanZoom` pans and zooms X by default. `panY: true, zoomY: true` adds
  the vertical dimension, and dragging an axis stretches that scale alone.
- `limits: .data()` keeps the window inside the data. `ChartLimits(minSpan:,
  maxSpan:)` bounds the zoom.
- The window can be set too: `chart.x.jumpTo(a, b)`, `chart.x.animateTo(a, b)`,
  and `chart.x.resetToAuto()` to return to the range policy.
- `.fitVisible()` keeps Y fitted while the user pans. Dragging the Y axis
  switches that scale to manual until `chart.y.resetToAuto()`.

## Things to look at next

These parts of plot_twist have no row in the tables above.

- **Log and custom scales.** `ChartScale.log()`, or a subclass of `ChartScale`: a strictly increasing `transform`, its `invert` and default ticks. [A14](https://glynskyi.github.io/plot_twist/#/a14)
- **Lazy history.** `ChartLoader` asks for older or newer rows as the window
  nears the loaded edge, and prepending rows does not move the view.
  [A5](https://glynskyi.github.io/plot_twist/#/a5)
- **Widgets in data space.** `ChartPositioned` places any widget by a data
  value, a fraction of the plot or pixels, chosen per axis;
  `ChartLayoutBuilder` builds widgets only for what is visible.
  [A3](https://glynskyi.github.io/plot_twist/#/a3),
  [A6](https://glynskyi.github.io/plot_twist/#/a6)
- **Custom series.** A `ChartSeriesPainter` implements `paint`, `bounds` and
  `collectHits`, and gets automatic ranges, the crosshair, the tooltip and a
  legend entry. [A8](https://glynskyi.github.io/plot_twist/#/a8)
- **Live data.** `.follow(span:)` keeps the newest data in view until the user
  pans. [A15](https://glynskyi.github.io/plot_twist/#/a15)
- **Linked charts.** Charts that share a `ChartScaleController` and a focus
  move and point together. [A16](https://glynskyi.github.io/plot_twist/#/a16)

[aspects.md](aspects.md) describes all 26 aspects, and
[architecture.md](architecture.md) explains the design.

## Not included yet

- Horizontal bars, and pie, radar and gauge charts as built-in types. The
  donut in A21 is a custom painter, and there is no polar coordinate system.
- Hollow candles, open-high-low-close bars and financial indicators.
- A Material theme adapter. The example's `MaterialChartTheme` helper shows
  the mapping in about 25 lines.
- The API is 0.x and can still change. plot_twist needs Flutter 3.41 or later.
- Nothing has been measured or tried on a phone, and accessibility has been
  checked by widget tests only, not with a screen reader.

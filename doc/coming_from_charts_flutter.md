# Coming from charts_flutter

This page maps the concepts of `charts_flutter` onto plot_twist and shows
three charts written with each. It also applies to the forks that continue
it under the same API, such as `community_charts_flutter` and
`nimble_charts`. It is meant for porting an existing chart one at a time.

The charts_flutter names on this page were verified against
community_charts_flutter 1.0.4 on 27 November 2026, and its three examples
compile against that version. The plot_twist examples are compiled and run by
`test/guides_test.dart`.

## The differences that matter most

- **One widget instead of a chart per domain type.** charts_flutter has
  `BarChart` for a `String` domain, `LineChart` for a numeric one and
  `TimeSeriesChart` for `DateTime`, and mixes renderers through
  `customSeriesRenderers` and a renderer id on each series. plot_twist has one
  `Chart`. The kind of domain is its x scale, and series are its children:
  any mix of them shares one chart.
- **Columns instead of accessor functions.** A `Series<T, D>` reads your
  objects through `domainFn` and `measureFn` on every draw. A plot_twist
  series reads a `ChartData`: typed columns of numbers that you fill once
  (`ChartData.from<T>(items, x: …, y: …)`), keep in state and change in place.
  Appending a row repaints the series without rebuilding a widget.
- **Behaviors are children.** The `behaviors` list becomes widgets in
  `children` (`ChartPanZoom`, `ChartCrosshair`, `ChartTooltip`) and in the
  side slots (`ChartLegend`, a title). A chart without them has no gesture
  recognizers.
- **A tooltip is built in, and it is a widget.** charts_flutter reports a
  selection and leaves the tooltip to the app. `ChartTooltip` shows any widget
  next to the data the user points at.
- **A range is a policy, and the window is state.** Instead of a `viewport`
  on an axis spec, a scale has a range policy (`fit`, `fitVisible`, `fixed`
  or `follow`), and the window on screen lives in a `ChartController`, in
  data units. Both axes can be panned and zoomed, also with a wheel or a
  trackpad.
- **Colours are Flutter colours.** There is no `charts.Color`. A series
  without a colour takes the next one of the palette of `ChartTheme`.

## Concept map

### Charts and data

| charts_flutter | plot_twist 0.3 | Notes |
|---|---|---|
| `LineChart`, `BarChart`, `TimeSeriesChart`, `ScatterPlotChart` | `Chart` with `LineSeries`, `BarSeries` or `ScatterSeries` children | |
| `OrdinalComboChart`, `NumericComboChart`, `customSeriesRenderers` with `rendererIdKey` | several series in one `Chart` | There are no renderer ids: each series is a widget with its own parameters. |
| `PieChart` | `PolarChart` with a `PieSeries` | A gauge is a `RadialBarSeries`. |
| `Series<T, D>(id:, data:, domainFn:, measureFn:)` | `ChartData.from<T>(items, x:, y:, more:)`, `ChartData.fromXY`, `ChartData.fromValues`; a series widget with `id:` | Change the store in place with `add`, `addAll`, `prependAll`, `removeFirst`, `setValue` or `replaceAll`. |
| `displayName` | `label` | Legends and tooltips show it. |
| a `String` domain | a band scale: `ChartScale.band(labels:)` | Row `i` of the data is band `i`, so `ChartData.fromValues(values)` is enough. |
| a `DateTime` domain | a time scale: `ChartScale.time()` | The x of a row is `dateTime.chartValue`, in milliseconds. |
| `measureLowerBoundFn`, `measureUpperBoundFn` | a second value column and `baseColumn:` | On a `LineSeries` it is a band between two curves, on a `BarSeries` a floating bar. |
| `colorFn`, `fillColorFn` | `color:`, `BarSeries.colorOf`, `LineSeries.shader` | `colorOf` picks a colour per bar; a shader colours a line by its values. |
| `charts.Color`, `MaterialPalette`, `ColorUtil.fromDartColor` | `Color`, `ChartThemeData.palette` | |
| `dashPatternFn`, `strokeWidthPxFn`, `radiusPxFn` | `LineSeries(dash:, width:)`, `ScatterSeries(pointRadius:, sizeColumn:)` | They belong to the series, not to a datum. A size per point comes from a data column. |

### Renderers

| charts_flutter | plot_twist 0.3 | Notes |
|---|---|---|
| `LineRendererConfig(includeArea: true)` | `LineSeries(fillColor:)` or `fillGradient:` | |
| `LineRendererConfig(stacked: true)` | `ChartData.stacked(layers)` and `LineSeries(baseColumn: 1)` | `stacked` returns a store per layer with its top and its base. |
| `LineRendererConfig(includePoints: true, radiusPx:)` | `LineSeries(pointRadius:)` | |
| `LineRendererConfig(dashPattern:)` | `LineSeries(dash:)` | The dashes stay in place while the chart is panned. |
| `BarChart(vertical: false)` | `BarSeries(direction: Axis.horizontal)` | The rows then run along the y scale. Use `ChartCrosshair(mode: ChartHitMode.nearestY)` with it. |
| `BarGroupingType.grouped` | the same `step` and a different `offset` per `BarSeries` | |
| `BarGroupingType.stacked` | `ChartData.stacked(layers)` and `BarSeries(baseColumn: 1)` | |
| `BarGroupingType.groupedStacked` with `seriesCategory` | `offset` for the group and `baseColumn` for the stack | |
| `BarRendererConfig(cornerStrategy: ConstCornerStrategy(4))` | `BarSeries(cornerRadius: 4)` | |
| `BarLabelDecorator` with `labelAccessorFn` | `ChartDataLabels(format:, position:)` | One layer labels every series, whichever way its bars point. |
| `ArcRendererConfig(arcWidth:, startAngle:, arcLength:)` | `PolarChart(innerRadius:, startAngle:, sweepAngle:)` | `arcWidth` is in pixels; `innerRadius` is a fraction of the radius. Angles are in radians in both. |
| `ArcLabelDecorator` | `ChartDataLabels` | In the middle of a slice, at its rim or outside it. There are no leader lines. |
| `PointRendererConfig` | `ScatterSeries` | |

### Axes

| charts_flutter | plot_twist 0.3 | Notes |
|---|---|---|
| `domainAxis`, `primaryMeasureAxis` | `Chart(x:, y:)` and a `ChartAxis` in a side slot | An axis measures its labels and sizes its gutter. Without a `ChartAxis` there is no axis. |
| `secondaryMeasureAxis`, `disjointMeasureAxes`, `measureAxisIdKey` | `Chart(yScales: {'id': …})`, `ChartAxis(scale: 'id')`, `yScale: 'id'` on the series | |
| `NumericAxisSpec(viewport: NumericExtents(0, 100))` | `LinearScale(range: FixedRange(0, 100))` | |
| `BasicNumericTickProviderSpec(zeroBound: false)` | `FitDataRange()` | Zero is part of the window only with `includeZero: true`. |
| `desiredTickCount` | `LinearTicks(spacing:)` | The density of ticks is a distance in pixels, so it holds while zooming. |
| `tickFormatterSpec` | `ChartAxis(format:)`, or `format:` on the ticks of the scale | |
| `DateTimeAxisSpec`, `AutoDateTimeTickFormatterSpec` | `TimeScale` with `TimeTicks(format:)` | The unit of the ticks changes with the zoom. |
| `OrdinalAxisSpec(viewport: OrdinalViewport('2018', 4))` | `chart.x.jumpTo(min, max)` in band units | |
| `renderSpec: GridlineRendererSpec()` | `ChartGrid()` as a child | |
| `renderSpec: NoneRenderSpec()` | leave the `ChartAxis` out | |
| a label style or rotation in a render spec | `ChartAxis(labelStyle:)`, `ChartAxis(labelBuilder:)` | A label is a widget, so a rotated one is a `RotatedBox`. |
| `flipVerticalAxis` | `reversed: true` on the scale | |

### Behaviors and selection

| charts_flutter | plot_twist 0.3 | Notes |
|---|---|---|
| `PanAndZoomBehavior`, `PanBehavior` | `ChartPanZoom()` | `zoomX: false` pans only; `panY` and `zoomY` add the other axis. |
| `SelectNearest`, `LinePointHighlighter`, `DomainHighlighter` | `ChartCrosshair()` | Hover, long press or `tap: true` set the focus. `mode` picks the points at an x, at a y, or the single nearest point. |
| `SelectionModelConfig(changedListener:)` | `ChartController.focus` and `hitsFor` | The focus is a `ValueListenable` in data units; `hitsFor(focus)` lists the points it stands for. |
| `InitialSelection` | `chart.focus.value = ChartFocus(x: …)` | |
| `SlidingViewport` | `chart.x.animateTo(min, max)`, or a `FollowRange` for live data | |
| `SeriesLegend` | `ChartLegend()` in a side slot | It reports taps through `onSeriesTap`; which series is `visible` is your state. |
| `DatumLegend` | `ChartLegend()` | A `PieSeries` with `labels` gets one item per slice. |
| `ChartTitle` | a `Text` in a side slot | Any widget can be docked beside the plot. |
| `RangeAnnotation` with `RangeAnnotationSegment` | `ChartPositioned.span(x1:, x2:)` | Any widget, stretched over a range of data. |
| `LineAnnotationSegment` | `ChartReferenceLine.x(…)`, `ChartReferenceLine.y(…)` | With an optional label. |
| `Slider` | a `ChartPositioned` widget that is dragged | [A17](https://glynskyi.github.io/plot_twist/#/a17) |
| `DomainA11yExploreBehavior` | `Chart(semanticLabel:)` and `Semantics` nodes over the bars | [A18](https://glynskyi.github.io/plot_twist/#/a18) |
| `animate: true`, `animationDuration` | `ChartAppear` around a series or a chart; `AnimatedChartData` | `ChartAppear` plays when the chart is first shown. `AnimatedChartData` moves the series from one data set to the next. |
| `UserManagedState` | `ChartController` | The window, the focus and the series are read and set through it. |

## Example 1: a time series with a selection

A line over time with an area under it, that pans and zooms and reports the
point the user selects.

charts_flutter:

```dart
class Sale {
  const Sale(this.day, this.amount);
  final DateTime day;
  final int amount;
}

Widget salesOverTime(List<Sale> sales, void Function(Sale? sale) onSelected) {
  return charts.TimeSeriesChart(
    <charts.Series<Sale, DateTime>>[
      charts.Series<Sale, DateTime>(
        id: 'Sales',
        data: sales,
        domainFn: (Sale sale, _) => sale.day,
        measureFn: (Sale sale, _) => sale.amount,
      ),
    ],
    animate: true,
    defaultRenderer: charts.LineRendererConfig<DateTime>(includeArea: true),
    primaryMeasureAxis: const charts.NumericAxisSpec(
      tickProviderSpec: charts.BasicNumericTickProviderSpec(zeroBound: false),
    ),
    behaviors: <charts.ChartBehavior<DateTime>>[charts.PanAndZoomBehavior<DateTime>()],
    selectionModels: <charts.SelectionModelConfig<DateTime>>[
      charts.SelectionModelConfig<DateTime>(
        type: charts.SelectionModelType.info,
        changedListener: (charts.SelectionModel<DateTime> model) => onSelected(
          model.hasDatumSelection ? model.selectedDatum.first.datum as Sale : null,
        ),
      ),
    ],
  );
}
```

plot_twist:

```dart
/// One row per sale, created once and kept in state:
/// `ChartData.from<Sale>(sales, x: (s) => s.day.chartValue, y: (s) => s.amount.toDouble())`.
Widget salesOverTime(ChartData sales, ChartController chart) {
  return ChartAppear(
    effect: .reveal,
    child: Chart(
      controller: chart,
      x: const .time(limits: .data()),
      y: const .linear(range: .fitVisible(padding: 0.1)), // not bound to zero
      left: const <Widget>[ChartAxis()],
      bottom: const <Widget>[ChartAxis()],
      children: <Widget>[
        const ChartGrid(),
        LineSeries(data: sales, label: 'Sales', fillColor: const Color(0x1A4E79A7)),
        const ChartPanZoom(),
        const ChartCrosshair(),
        const ChartTooltip(),
      ],
    ),
  );
}

/// What the user points at, outside the chart: a row of [sales], or null.
Widget selectedSale(ChartController chart, Widget Function(int? row) builder) {
  return ValueListenableBuilder<ChartFocus?>(
    valueListenable: chart.focus,
    builder: (BuildContext context, ChartFocus? focus, Widget? child) =>
        builder(focus == null ? null : chart.hitsFor(focus).firstOrNull?.index),
  );
}
```

What changes:

- The data is a store, not a list read through functions. `sales.add(x, y)`
  appends a row and the line repaints.
- The selection is `chart.focus`. It is in data units, so it survives a pan,
  and it can be read anywhere, also outside the chart.
- The y scale fits the data that is visible (`fitVisible`), so it follows a
  pan and a zoom. With `fit` it would fit all data and stand still.
- The tooltip is part of the chart. Give `ChartTooltip` a `builder` to show a
  widget of your own.

## Example 2: stacked bars that lie, with labels and a legend

charts_flutter:

```dart
class Revenue {
  const Revenue(this.quarter, this.amount);
  final String quarter;
  final int amount;
}

Widget revenueByChannel(List<Revenue> online, List<Revenue> retail) {
  charts.Series<Revenue, String> series(String id, List<Revenue> data) =>
      charts.Series<Revenue, String>(
        id: id,
        data: data,
        domainFn: (Revenue revenue, _) => revenue.quarter,
        measureFn: (Revenue revenue, _) => revenue.amount,
        labelAccessorFn: (Revenue revenue, _) => '${revenue.amount}',
      );
  return charts.BarChart(
    <charts.Series<Revenue, String>>[series('Online', online), series('Retail', retail)],
    animate: true,
    vertical: false,
    barGroupingType: charts.BarGroupingType.stacked,
    barRendererDecorator: charts.BarLabelDecorator<String>(),
    behaviors: <charts.ChartBehavior<String>>[charts.SeriesLegend<String>()],
  );
}
```

plot_twist:

```dart
/// [layers] is `ChartData.stacked([online, retail])`, created once and kept
/// in state. Each of the two has one row per quarter:
/// `ChartData.fromValues(amounts)`.
Widget revenueByChannel(List<ChartData> layers) {
  return ChartAppear(
    effect: .growX,
    child: Chart(
      x: const .linear(range: .fit(includeZero: true, padding: 0.1)),
      y: const .band(labels: <String>['Q1', 'Q2', 'Q3', 'Q4'], reversed: true),
      left: const <Widget>[ChartAxis()],
      bottom: const <Widget>[ChartAxis()],
      top: const <Widget>[ChartLegend()],
      children: <Widget>[
        const ChartGrid(horizontal: false),
        BarSeries(data: layers[0], baseColumn: 1, direction: .horizontal, label: 'Online'),
        BarSeries(data: layers[1], baseColumn: 1, direction: .horizontal, label: 'Retail'),
        // The size of every layer, written in its middle.
        ChartDataLabels(
          position: .center,
          format: (ChartHit mark) => '${(mark.value - mark.base!).round()}',
        ),
      ],
    ),
  );
}
```

What changes:

- Stacking is data. `ChartData.stacked` gives every layer its top and its
  base, and each series draws from the base in column 1. Negative values can
  go down from zero with `diverging: true`.
- The direction belongs to the series. The scales keep their names: x is
  horizontal and y is vertical, so here the values are on x and the quarters
  on y.
- The names of the bands are on the scale, not in the data.
- The legend is a widget in a side slot. It is complete on the first frame.

## Example 3: a doughnut with labels and a legend

charts_flutter:

```dart
class Share {
  const Share(this.name, this.amount);
  final String name;
  final int amount;
}

Widget spendingDoughnut(List<Share> shares) {
  return charts.PieChart<String>(
    <charts.Series<Share, String>>[
      charts.Series<Share, String>(
        id: 'Spending',
        data: shares,
        domainFn: (Share share, _) => share.name,
        measureFn: (Share share, _) => share.amount,
        labelAccessorFn: (Share share, _) => '${share.amount}',
      ),
    ],
    animate: true,
    defaultRenderer: charts.ArcRendererConfig<String>(
      arcWidth: 60,
      arcRendererDecorators: [charts.ArcLabelDecorator<String>()],
    ),
    behaviors: <charts.ChartBehavior<String>>[
      charts.DatumLegend<String>(position: charts.BehaviorPosition.bottom),
    ],
  );
}
```

plot_twist:

```dart
/// [amounts] has one row per category: `ChartData.fromValues(values)`.
Widget spendingDoughnut(ChartData amounts, List<String> names) {
  return PolarChart(
    innerRadius: 0.6,
    bottom: const <Widget>[ChartLegend()],
    children: <Widget>[
      ChartAppear(
        effect: .reveal,
        child: PieSeries(data: amounts, labels: names),
      ),
      const ChartDataLabels(position: .center),
      const ChartCrosshair.point(), // follows the slice under the pointer
      const ChartTooltip(),
    ],
  );
}
```

What changes:

- A pie is a series in a `PolarChart`, and its layers are the ones of the
  other charts: the same legend, labels, tooltip and appear animation.
- The hole is `innerRadius`, a fraction of the radius, so it scales with the
  chart. A widget for the hole is one more child, such as a `Center`.
- Each slice takes the next colour of the palette. `colorOf` picks one per
  slice.

## Things to look at next

- **Any widget in the chart.** A marker, a label or a tooltip is a widget
  placed by a data value. [A4](https://glynskyi.github.io/plot_twist/#/a4),
  [A6](https://glynskyi.github.io/plot_twist/#/a6)
- **Large and live data.** A line of a million points pans and zooms, and
  `.follow(span:)` keeps the newest data in view.
  [A10](https://glynskyi.github.io/plot_twist/#/a10),
  [A15](https://glynskyi.github.io/plot_twist/#/a15)
- **History that loads as you scroll back.** `ChartLoader` asks for more when
  the window nears the edge of the data.
  [A5](https://glynskyi.github.io/plot_twist/#/a5)
- **Custom series.** A `ChartSeriesPainter` takes the place of a custom
  renderer: it implements `paint`, `bounds` and `collectHits`, and gets
  automatic ranges, the crosshair, the tooltip and a legend entry.
  [A8](https://glynskyi.github.io/plot_twist/#/a8)
- **Candlesticks**, which charts_flutter does not have.
  [A26](https://glynskyi.github.io/plot_twist/#/a26)

[aspects.md](aspects.md) describes all 26 aspects, and
[architecture.md](architecture.md) explains the design.

## Not included yet

- Bar target lines (`BarTargetLineRendererConfig`), symbol annotations and
  comparison points as built-in series. A `ChartSeriesPainter` can draw them.
- `PercentInjector`: compute the shares in your data.
- Legends that show the selected measures (`showMeasures`). An `itemBuilder`
  can read `ChartController.focus`.
- Leader lines from a pie to labels outside it.
- Right-to-left layout (`RTLSpec`) and tick labels that follow a locale.
- A Material theme adapter. The example's `MaterialChartTheme` helper shows
  the mapping in about 25 lines.
- The API is 0.x and can still change. plot_twist needs Flutter 3.41 or later.
- Nothing has been measured or tried on a phone, and accessibility has been
  checked by widget tests only, not with a screen reader.

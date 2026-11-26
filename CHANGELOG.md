## 0.2.0

### Renamed

The old names keep working and are marked as deprecated. They are removed in
0.3.0. After this, `width` always means a stroke width in logical pixels.

| Old | New |
|---|---|
| `BarSeries.width`, `CandlestickSeries.width` | `widthFactor` |
| `BarSeries.radius` | `cornerRadius` |
| `ScatterSeries.radius` | `pointRadius` |
| `Chart.scales` | `Chart.yScales` |
| `formatNumber`, `niceStep` | `ChartTicks.formatNumber`, `ChartTicks.niceStep` |

The painters of the three series are renamed in the same way.

### Changed

- A series without a `color` takes the colour the palette of the chart theme
  has for its place in the chart: the first series the first colour, the
  second the next, whether a series is visible or not. Until now every such
  series took the first colour, so a chart with several of them changes its
  colours. Give a series a `color` to keep it.
- `ChartController.series` lists the series in paint order. A series added in
  front of others on a rebuild used to come last.
- `ChartSeries.color` of a series without a colour is its palette colour, also
  for a `ChartPaint` with a painter of your own, where it used to be null.
- `color` of `LineSeriesPainter`, `BarSeriesPainter` and `ScatterSeriesPainter`
  is optional and nullable. Null paints with `ChartPaintContext.seriesColor`.

- `ChartHitMode` has a third value, `nearestY`. A `switch` over the modes in a
  series of your own needs a case for it; a series whose rows run along x
  adds no hit there.
- The default tooltip shows `ChartHit.value`, which is `y` for everything
  except horizontal bars.

### Fixed

- A dashed `LineSeries` keeps its dashes in place while it is panned. They
  used to jump along the line whenever a row left the window.

### New

- `ChartCrosshair(mode:)`: `ChartHitMode.nearest` snaps to the closest point
  in both dimensions, so a tooltip on a scatter plot shows the dot under the
  pointer. `ChartHitMode.nearestY` snaps along y, for horizontal bars. The
  mode is stored in `ChartFocus.mode`, and `ChartController.hitsFor(focus)`
  returns the data points a focus stands for. `snapDistance` limits how far
  the focus snaps.
- `CandlestickSeries(style:)`: `CandleStyle.hollow` outlines the candles that
  close at or above their open, `CandleStyle.ohlc` draws OHLC bars. Both are
  still two draw calls per frame.
- `ChartLegend`: the colour and label of every series, for a side slot of
  the chart or anywhere else with the chart's controller. It is complete on
  the first frame, wraps, dims hidden series and reports taps
  (`onSeriesTap`), so your state keeps deciding which series is visible.
- `ChartDataLabels`: a layer that writes the value next to every visible
  data point of bars in both directions, lines, scatter plots and
  candlesticks, with `format`, `position` (outside, inside or centred),
  overlap hiding and a limit (`maxLabels`, 250) above which it draws none.
  A series of your own gets labels by overriding
  `ChartSeriesPainter.visitMarks`.
- `ChartController.seriesRepaint`: notifies at once when a series changes
  what it shows, as the `repaint` of a painter that draws what the series
  show.
- Horizontal bars: `BarSeries(direction: Axis.horizontal)`. The rows run
  along the vertical scale and the values along the horizontal one; stacks,
  offsets, rounded ends and per-bar colours work as for columns. Use
  `ChartCrosshair(mode: ChartHitMode.nearestY)` with it. With only y to pan,
  `ChartWheelAction.pan` scrolls the rows.
- Stacked areas: `LineSeries(baseColumn:)` fills between the line and
  another value column, and takes the layers of `ChartData.stacked` as
  `BarSeries` does. Such a series draws every visible row; it is not reduced
  to the extremes of each pixel column.
- `ChartData.stacked(layers, diverging: true)` stacks negative values
  downwards from zero, for stacks with gains and losses.
- `ChartReferenceLine.y(value)` and `.x(value)`: a line across the plot at a
  threshold, a target or an average, with an optional dash pattern and a
  label widget that follows the line. `includeInRange` widens automatic
  ranges to show it.
- `ChartPaint(listed: false)`, for a helper layer that counts for automatic
  ranges but is no series to a legend. `ChartSeries.listed` reports it.
- Minor ticks: `LinearTicks(minorCount:)`, `LogTicks(minor:)` and
  `BandTicks(minor:)`. An axis draws a short mark at each
  (`ChartAxis.minorTickLength`), and `ChartGrid(minor: true)` a fainter line.
  They are in `ChartScaleView.minorTicks`; ticks of your own provide them by
  overriding `ChartTicks.generateMinor`.
- `dash` on `ChartGrid` and `ChartCrosshair`. For painters of your own,
  `ChartPainter.dashPath` cuts a path into dashes and
  `ChartPainter.drawDashedLine` draws a dashed straight line in one call.
- `ChartTooltip(yScale:)`, for a focus measured on another vertical scale.
- `ChartHit.base`, `ChartHit.valueAxis`, `ChartHit.value` and
  `ChartHit.argument`. A bar's hit carries the value it starts from, so a
  tooltip can show the size of one layer of a stack.
- `ChartPaintContext.seriesColor`: the colour of the layer being painted, for
  painters of your own.
- `clip` on `BarSeries`, `ScatterSeries` and `CandlestickSeries`, as on
  `LineSeries`.

## 0.1.1

Fixes. Nothing is removed or renamed.

- Log scales: a log axis no longer gets stuck on the window 1 to 10 when the
  data, a bar's baseline of 0 or `includeZero` brings in a value of zero or
  less. Such values are missing data: automatic ranges leave them out, lines
  break there, and bars and filled areas grow from the edge of the plot. The
  fitted window reaches to the next power of the base below the smallest
  value, so the smallest bar still has a length.
- Infinite values are missing data as well. One of them used to send every
  automatic range to its fallback.
- `LineSeries`: zoomed far into sparse data, a stepped line and its fill drew
  the first run at the wrong height. A smooth line changed shape at the plot
  edges while panning, was drawn straight between two rows that bracket the
  window, and did not match `valueAt`.
- `LineSeries.dash` is compared by value, so a list written in `build` no
  longer repaints the series on every rebuild.
- `TimeTicks`: steps of one and two weeks fall on Mondays instead of
  Thursdays. In local time, steps of several days stay at midnight and steps
  of 3, 6 and 12 hours stay on the clock grid across a daylight saving change.
- Ticks set on a scale or an axis to change a spacing or a format keep what
  the scale knows: UTC on a UTC `TimeScale`, the base of a `LogScale`, the
  labels of a `BandScale`.
- `ChartLoader`: a failed load is reported to the new `onError` (or through
  `FlutterError.reportError`) and tried again when the window or the data
  changes; it used to leave that side loading for good. A load that says
  there is more but adds nothing is no longer repeated without end. A change
  of `xScale` is followed.
- `ChartPanZoom` removed while a finger is down releases its scales, which
  stayed marked as interacting, also on linked charts.
- `AnimatedChartData` respects reduced motion on first show too. Removing one
  that never animated no longer fails an assertion (seen on Flutter 3.41).
- An axis gutter that grew during a gesture shrinks when the gesture ends.
- `ChartData.setValue` updates the min/max index instead of rebuilding it,
  which makes a live last candle cheap on large stores.
- `FixedRange`, `FollowRange`, `LogScale` and `ChartLimits` assert
  configurations that cannot work, such as a range the wrong way round or a
  logarithm base of 1. In release builds such values no longer throw later.

New, for custom scales and series: `ChartScale.domain`,
`ChartScale.resolveTicks`, `ChartData.valueExtent(within:)` and
`ChartData.xExtentWithin`. A series' `bounds` should leave out values outside
the window it is given in each dimension, as the built-in ones now do.

## 0.1.0

First release.

- `Chart`: one widget for every kind of chart. It has named scales, four side
  slots that take any widget, and a list of children that share one
  data-space view.
- `ChartController` and `ChartScaleController`: the visible window per scale,
  readable, settable, animatable and listenable. Scale controllers and the
  crosshair focus can be shared between charts.
- Scales: linear, logarithmic, time and band, with fit, fit-visible, fixed and
  follow range policies. Custom scales subclass `ChartScale`.
- Widgets in data space: `ChartPositioned`, `ChartLayoutBuilder`,
  `ChartAxis` with widget labels and `ChartAxisMarker`.
- Painting: `ChartPaint` with `ChartPainter` and `ChartSeriesPainter`.
- Series: `LineSeries`, `BarSeries`, `ScatterSeries` and `CandlestickSeries`.
- Behaviors: `ChartPanZoom`, `ChartCrosshair`, `ChartTooltip`, `ChartLoader`
  and `AnimatedChartData`. Custom ones use `ChartGestureDetector`.
- `ChartData`: typed columns that grow at both ends, with an index for fast
  extent queries.
- An example gallery with one demo for each of 26 aspects.

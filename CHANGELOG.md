## 0.3.1

No code changes. The README opens with a grid of the chart types instead of
one clip of candlesticks: line, area, bar, bars and a line, scatter,
candlestick, pie and doughnut, gauge and radar. Each is a short clip that
opens its demo in the gallery. `doc/aspects.md` gives the right total of demo
lines, 2,231, and a gallery test now checks the counts the docs give.

## 0.3.0

Pie and doughnut charts, gauges and radar charts, on a `PolarChart` that
shares its legend, tooltip, data labels and animations with the other
charts. The names that 0.2.0 replaced are removed.

### Breaking

- The names deprecated in 0.2.0 are removed: `BarSeries.width` and `radius`,
  `CandlestickSeries.width`, `ScatterSeries.radius`, `Chart.scales`, and the
  top-level `formatNumber` and `niceStep`, also on the painters of the three
  series. Use `widthFactor`, `cornerRadius`, `pointRadius`, `Chart.yScales`,
  `ChartTicks.formatNumber` and `ChartTicks.niceStep`.
- `ChartSeries`, the view of a series that the controller hands out, has a
  new member, `entries`. A class of your own that implements it needs one.

### Changed

- The default tooltip shows `ChartHit.label` and `ChartHit.color` where a
  hit has them, and the label and colour of its series otherwise. A hit of
  the built-in Cartesian series has neither, so their tooltips are unchanged.
- `ChartCrosshair` marks a point in `ChartHit.color` where a hit has one.

### Gallery

- A21 is a doughnut, a gauge and a radar chart from the built-in series. It
  used to draw a doughnut with a painter of its own.

### New

- `PolarChart`: a chart on a circle. Its `angle` scale runs around the
  centre and its `radius` scale from the centre outwards; `startAngle`,
  `sweepAngle` and `innerRadius` say where. Its children are layers, as in a
  `Chart`, and it has the same side slots. A chart that turns less than a
  whole circle is laid out so that the drawn part fills the plot.
- `PieSeries`: one slice per row, as wide as its value, in the colours of
  the palette or of `colorOf`. `gap` separates the slices by the same
  distance at every radius, `cornerRadius` rounds them and `offsetOf` pulls
  one out. On an angle scale with a fixed range the slices cover their share
  of the circle.
- `RadialBarSeries`: bars around the centre, one ring per row, for gauges
  and progress rings. `track` draws the rest of each ring, `cap` rounds the
  ends, and `baseColumn` starts a bar at a value of its own.
- `RadarSeries`: a line around the centre with a corner per row, closed and
  filled. Pointing anywhere in the circle picks the nearest category for
  every series.
- `ChartPolarGrid`: rings at the ticks of the radius scale, round or as
  polygons, and spokes at the ticks of the angle scale.
- `ChartPolarAxis.angle()` writes the labels of the angle scale around the
  circle, with optional tick marks, outside it or inside the ring;
  `ChartPolarAxis.radius()` writes those of the radius scale along a line
  from the centre.
- `ChartNeedle(value:)`: the pointer of a gauge.
- `ChartPolarPositioned`: places a widget by an angle and a radius.
- `ChartCrosshair.point()`: tracks the single data point under the pointer
  and draws no lines. It is the crosshair for a polar chart, and suits a
  scatter plot that wants a tooltip only.
- `ChartLegend` shows one item for each named slice of a pie. `onEntryTap`
  reports taps on them and `entryBuilder` builds them.
- `ChartDataLabels` labels slices and bars around a circle, in their middle,
  at their rim or outside it, and puts the labels of a radar chart away from
  the centre.
- `ChartAppear` in a polar chart: `reveal` uncovers a series around the
  centre, from the start angle, and `growY` and `growX` grow it out of the
  centre.
- [doc/coming_from_charts_flutter.md](https://github.com/glynskyi/plot_twist/blob/main/doc/coming_from_charts_flutter.md):
  the concepts of charts_flutter and its forks mapped onto plot_twist, with
  three charts written in both.

For series and painters of your own:

- `ChartPolar` and `ChartPolarView`: the frame of a polar chart, and where
  its circle and every value are in one frame. `ChartPolarScope.of(context)`
  reads the frame, and `ChartSeriesPainter.polar` tells the chart that a
  series is drawn in one.
- `ChartSector`: a part of a ring, with `contains`, `distanceTo` and
  `toPath(gap:, cornerRadius:)`.
- `ChartHit.sector`, `ChartHit.label` and `ChartHit.color`, for a mark that
  is a sector and has a name or a colour of its own.
- `ChartSeriesPainter.entries` and `ChartSeriesEntry`: the parts of a series
  that a legend lists one by one.
- `kChartAngle` and `kChartRadius`, the ids of the two scales of a polar
  chart.

## 0.2.1

No code changes. The description, the topics and the feature list at the top
of the README name what the package does in the words people search for:
real-time data, time series, large datasets, stacked and horizontal bars. The
topic `charts` replaces `data-visualization`.

## 0.2.0

Horizontal bars, stacked areas, data labels, a legend, an appear animation,
reference lines, minor ticks and candle styles. A few parameters have new
names; the old ones keep working until 0.3.0.

### Breaking

- The library no longer exports its render objects and their parent data:
  `RenderChartLayout`, `RenderChartStack`, `RenderChartAxis`,
  `RenderChartPaint`, `RenderChartLayoutBuilder`, `ChartLayoutParentData`,
  `ChartStackParentData`, `ChartAxisParentData`, `ChartPlacement` and
  `ChartAxisChildKind`. They were implementation details; the widgets that
  create them are unchanged.
- `ChartController.scale(id)` fails an assertion for a scale the chart does
  not have, once a chart uses the controller. It used to create that scale
  silently, which hid a mistyped `xScale` or `yScale`. Before a chart uses
  the controller, scales are still created on demand.

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
- `ChartSeries`, the view of a series that the controller hands out, has two
  new members, `listed` and `visitMarks`.
- `ChartHitMode` has a third value, `nearestY`. A `switch` over the modes in a
  series of your own needs a case for it; a series whose rows run along x
  adds no hit there.
- The default tooltip shows `ChartHit.value`, which is `y` for everything
  except horizontal bars.

### Fixed

- A dashed `LineSeries` keeps its dashes in place while it is panned. They
  used to jump along the line whenever a row left the window.

### Gallery

- A2 picks the nearest star in both dimensions, A11 grows its series in, A14
  has minor ticks, A17 draws its threshold with `ChartReferenceLine`, A19
  lays its bars down and labels them, and A20 uses `ChartLegend`.

### New

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
- `ChartDataLabels`: a layer that writes the value next to every visible
  data point of bars in both directions, lines, scatter plots and
  candlesticks, with `format`, `position` (outside, inside or centred),
  overlap hiding and a limit (`maxLabels`, 250) above which it draws none.
  A series of your own gets labels by overriding
  `ChartSeriesPainter.visitMarks`.
- `ChartLegend`: the colour and label of every series, for a side slot of
  the chart or anywhere else with the chart's controller. It is complete on
  the first frame, wraps, dims hidden series and reports taps
  (`onSeriesTap`), so your state keeps deciding which series is visible.
- `ChartAppear`: wrap a series or a whole chart, and its series grow, are
  uncovered or fade in when first shown (`ChartAppearEffect.growY`, `growX`,
  `reveal`, `fade`). Only the painting is animated: ranges and hits are
  final from the first frame, so the axes stand still, and a series of your
  own gets it too. It is skipped under reduced motion.
- `ChartReferenceLine.y(value)` and `.x(value)`: a line across the plot at a
  threshold, a target or an average, with an optional dash pattern and a
  label widget that follows the line. `includeInRange` widens automatic
  ranges to show it.
- Minor ticks: `LinearTicks(minorCount:)`, `LogTicks(minor:)` and
  `BandTicks(minor:)`. An axis draws a short mark at each
  (`ChartAxis.minorTickLength`), and `ChartGrid(minor: true)` a fainter line.
  They are in `ChartScaleView.minorTicks`; ticks of your own provide them by
  overriding `ChartTicks.generateMinor`.
- `CandlestickSeries(style:)`: `CandleStyle.hollow` outlines the candles that
  close at or above their open, `CandleStyle.ohlc` draws OHLC bars. Both are
  still two draw calls per frame.
- `ChartCrosshair(mode:)`: `ChartHitMode.nearest` snaps to the closest point
  in both dimensions, so a tooltip on a scatter plot shows the dot under the
  pointer. `ChartHitMode.nearestY` snaps along y, for horizontal bars. The
  mode is stored in `ChartFocus.mode`, and `ChartController.hitsFor(focus)`
  returns the data points a focus stands for. `snapDistance` limits how far
  the focus snaps.
- `ChartTooltip(yScale:)`, for a focus measured on another vertical scale.
- `dash` on `ChartGrid` and `ChartCrosshair`. For painters of your own,
  `ChartPainter.dashPath` cuts a path into dashes and
  `ChartPainter.drawDashedLine` draws a dashed straight line in one call.
- `clip` on `BarSeries`, `ScatterSeries` and `CandlestickSeries`, as on
  `LineSeries`.

For series and painters of your own:

- `ChartPaintContext.seriesColor`: the colour of the layer being painted, for
  painters of your own.
- `ChartHit.base`, `ChartHit.valueAxis`, `ChartHit.value` and
  `ChartHit.argument`. A bar's hit carries the value it starts from, so a
  tooltip can show the size of one layer of a stack.
- `ChartPaint(listed: false)`, for a helper layer that counts for automatic
  ranges but is no series to a legend. `ChartSeries.listed` reports it.
- `ChartController.seriesRepaint`: notifies at once when a series changes
  what it shows, as the `repaint` of a painter that draws what the series
  show.

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

# The 26 aspects

This is the list of things a Flutter chart library is judged on, why each one
matters, and how plot_twist meets it. Each aspect has one demo in
`example/lib/demos/`.

## How the list was made

The aspects were collected from three kinds of source:

- the source code of widely used Flutter chart packages;
- the issue trackers of chart libraries for Flutter and other platforms;
- the APIs of libraries that solve a given problem well.

Each "Why it matters" section describes the problems app developers report,
and, where one exists, the approach that solves them.

The aspects are ranked. A1 to A14 are things a general-purpose chart package
must do, A15 to A21 are things it should do, and A22 to A25 are nice to have.

A26 was added after that list was ranked, when a comparison with other Flutter
chart packages showed a built-in candlestick series that plot_twist lacked. It
is a "should", and its "Why it matters" section gives reasons instead of
reported problems, because no issue tracker was read for it.

## What "easy" means here

A demo counts as proof only if it follows three rules, which a test in
`example/test/demos_test.dart` enforces:

1. It is one file.
2. It imports only `package:plot_twist/plot_twist.dart`, Flutter and the
   example's shared helpers (fake data, a pill widget, a shimmer). Nothing
   under `package:plot_twist/src/`.
3. It has at most 120 lines that are neither blank nor comments, after
   `dart format` at 100 columns.

The 26 demos have 2,211 such lines in total, 85 on average.

## Summary

| # | Aspect | Priority | Demo file | Lines | Main API used |
|---|---|---|---|---|---|
| A1 | Viewport controller | must | `a01_viewport_inspector.dart` | 76 | `ChartController`, `ChartScaleController` |
| A2 | 2D pan and zoom | must | `a02_star_map.dart` | 54 | `ChartPanZoom`, `ChartCrosshair(mode:)` |
| A3 | Mixed-anchor, derived overlays | must | `a03_edge_crossing.dart` | 90 | `ChartPositioned.resolve`, `ChartAxisMarker` |
| A4 | Widgets as tooltips | must | `a04_rich_tooltip.dart` | 93 | `ChartTooltip`, `ChartCrosshair` |
| A5 | Lazy history | must | `a05_infinite_history.dart` | 86 | `ChartLoader`, `ChartData.prependAll`, `ChartLimits` |
| A6 | Lazy widget markers | must | `a06_photo_pins.dart` | 82 | `ChartLayoutBuilder`, `ChartPositioned` |
| A7 | Widgets as axis labels | must | `a07_widget_axis.dart` | 82 | `ChartAxis.labelBuilder` |
| A8 | Custom series | must | `a08_custom_series.dart` | 99 | `ChartSeriesPainter`, `ChartPaint` |
| A9 | Custom interactions, coexisting gestures | must | `a09_coexistence.dart` | 113 | `ChartGestureDetector`, `ChartPanZoom` |
| A10 | Large data | must | `a10_million_points.dart` | 66 | `ChartData`, `LineSeries` |
| A11 | Mixed series, several Y axes | must | `a11_weather_combo.dart` | 87 | `Chart.yScales`, `yScale:`, `ChartAppear` |
| A12 | Crosshair as shared state | must | `a12_crosshair.dart` | 94 | `ChartController.focus`, `ChartCrosshairBadge` |
| A13 | Y auto-fit | must | `a13_auto_fit.dart` | 61 | `ChartRangePolicy.fitVisible` |
| A14 | Pluggable scales | must | `a14_scales.dart` | 86 | `ChartScale`, `ChartTicks` |
| A15 | Live data | should | `a15_live.dart` | 85 | `ChartRangePolicy.follow`, `ChartData.addAll` |
| A16 | Linked charts | should | `a16_linked_panes.dart` | 82 | shared `ChartScaleController`, `ChartGutterGroup` |
| A17 | Editable annotations | should | `a17_annotations.dart` | 106 | `ChartReferenceLine`, `ChartPainter`, `ChartGestureShield` |
| A18 | Accessibility | should | `a18_accessibility.dart` | 95 | `Chart.semanticLabel`, `ChartLayoutBuilder` |
| A19 | Animated transitions | should | `a19_transitions.dart` | 78 | `AnimatedChartData`, `BarSeries(direction:)`, `ChartDataLabels` |
| A20 | Legend outside the chart | should | `a20_legend.dart` | 68 | `ChartLegend`, `ChartController.series` |
| A21 | Non-Cartesian content | should | `a21_donut.dart` | 119 | `ChartPainter`, `ChartPositioned.resolve` |
| A22 | Data-driven styling | nice | `a22_styling.dart` | 86 | `LineSeries.shader`, `ChartTheme` |
| A23 | Navigator by composition | nice | `a23_navigator.dart` | 90 | `ChartPositioned.span`, `panBy` |
| A24 | Many small charts | nice | `a24_sparklines.dart` | 65 | `Chart(isolate: false)` |
| A25 | Export | nice | `a25_export.dart` | 85 | `RepaintBoundary.toImage` |
| A26 | Candlesticks | should | `a26_candlesticks.dart` | 109 | `CandlestickSeries`, `ChartCandle` |

---

## A1. Viewport controller

**What it is.** The visible window is a range per scale in data units. App
code can read it, set it, animate it and listen to it.

**Why it matters.**

- After a zoom or pan, the app cannot find out which X range is on screen, so
  it cannot load data for that range, show it in a label or move another
  widget with it.
- When the viewport is a pixel-space transform matrix, every conversion to
  data units is app code. If the chart also calls `setState` on every
  transform tick, panning rebuilds widgets every frame.
- When the range callback and the range controller are separate features,
  they can conflict: binding the visible range to a controller turns off zoom
  and pan.
- The approach that works is a visible-range change event in data units and a
  scroll position the app can bind both ways.

**In plot_twist.** A `ChartController` holds one `ChartScaleController` per
scale. Each is a `Listenable` with `min`, `max`, `range`, `isAuto`, `jumpTo`,
`panBy`, `zoomBy`, `animateTo` and `resetToAuto`. A change causes layout and
paint in the chart. It does not rebuild the chart's widgets.

**Demo.** A live readout of both ranges, a `RangeSlider` bound both ways to
the X window, an animated "Zoom to Q3" button and "Show all".

## A2. 2D pan and zoom

**What it is.** Dragging pans X and Y together. Pinch, wheel and trackpad
zoom. Dragging an axis stretches that scale only. Flings have inertia, limits
apply, and a double tap resets.

**Why it matters.**

- A chart longer than the screen that the user can scroll along X is one of
  the most requested chart features.
- When zoom is a scale factor that must be at least 1, the user cannot zoom
  out past the declared range or pan outside it.
- When every part of pan and zoom is off by default and is switched on mode by
  mode, a plain "drag to move, pinch to zoom" chart takes configuration.

**In plot_twist.** `ChartPanZoom` is one behavior with a flag per dimension
(`panX`, `panY`, `zoomX`, `zoomY`) and options for the wheel, inertia, axis
drag, double-tap reset and anisotropic pinch. Gestures become deltas in scale
space, so they also work on log and time scales. Limits come from the scale's
`ChartLimits`.

**Demo.** A 50,000-point scatter. The whole feature is
`const ChartPanZoom(panY: true, zoomY: true)`. Hovering picks the star nearest
to the pointer in both dimensions, with `ChartCrosshair(mode: .nearest)`; the
tooltip then shows that one point.

## A3. Mixed-anchor, derived overlays

**What it is.** An overlay whose X and Y anchors are chosen independently (a
data value, a fraction of the plot, or pixels from an edge), or derived from
live chart state. The canonical case is a dot where the line crosses the Y
axis, which stays on the axis while the chart scrolls, with a value pill in
the axis gutter.

**Why it matters.**

- When an annotation has one coordinate unit for both dimensions, this case
  means converting pixels to data by hand, interpolating the line in a
  range-changed callback and calling `setState`.
- Without an overlay API, the app inverts the chart's transform itself and
  stacks widgets over the chart.
- The approach that works is to choose the reference frame for X and Y
  separately, to recompute positions from the current view on every redraw,
  and to allow drawing over the axes.

**In plot_twist.**

- `ChartPositioned(x: …, y: …)` takes a `ChartAnchor` per dimension:
  `.value(v)`, `.fraction(f)`, `.pixels(px)`, `.fromEnd(px)`, or `.start`,
  `.center` and `.end`.
- `ChartPositioned.resolve(position: (view) => …)` computes the position from
  the current `ChartView` during layout.
- `controller.seriesById(id)?.valueAt(x)` reads the drawn curve.
- `overflow: .visible` lets the widget paint outside the plot, over the axis
  line.
- `ChartAxisMarker` pins a widget to a value inside an axis gutter.

**Demo.** The dot, a value pill in the left gutter, an arrow that replaces the
dot when the crossing is above or below the window, and a last-value pill on
the right axis. The research's version also had an arrow pointing to an
off-screen selected point; the demo leaves that out.

## A4. Widgets as tooltips

**What it is.** A tooltip is any widget. It is anchored to a data point, flips
at the edges, follows its point during a pan, can hold working controls, and
can leave the chart.

**Why it matters.**

- When a tooltip item accepts only text and styled text spans, it cannot show
  an icon, an image or a layout of its own. Requests for widget tooltips stay
  open for years.
- Users want working controls in a tooltip, such as a button that opens the
  details of the hovered point.
- The approach that works is a tooltip builder that returns a widget.

**In plot_twist.** `ChartTooltip(builder: (context, hits) => …)` returns a
widget. `interactive: true` lets it receive pointer events. `overlay: true`
shows it in the app's `Overlay`, where it is never clipped by the chart and
still tracks its anchor in the same frame. `ChartCrosshair(tap: true)` pins
the focus on tap.

**Demo.** A card with an avatar, a small chart and a button that opens a
snackbar, plus a switch for overlay mode.

## A5. Lazy history

**What it is.** When the window nears the loaded edge, the app is asked for
more. A placeholder covers what has not arrived. Prepending rows never moves
the view. The user can scroll into a range that exists but is not loaded.

**Why it matters.**

- Users want older data to load as they scroll back, as in a price chart.
  Without an API for it, and with zoom limited to the declared range, they
  cannot even pan past the first loaded point to trigger a load.
- When new data replaces the data source, the zoom position is not
  recalculated, so the view jumps.
- The approach that works keeps the viewport where it was when history is
  prepended, and shows a placeholder while more data loads.

**In plot_twist.**

- The window is stored in data space, so prepending cannot move it.
  `ChartData.prependAll` keeps row ordinals stable.
- `ChartLimits(min: …, max: …)` is the range the user may scroll in. It is
  separate from what is loaded.
- `ChartLoader(data: …, onLoadBefore: …, onLoadAfter: …)` calls back when the
  window comes within half its own width of the loaded edge (`prefetch`).
  Loading never blocks scrolling.
- The placeholder is `ChartPositioned.span(x1: …, x2: …, child: Shimmer())`.

**Demo.** Twenty years of daily values behind a fake API (300 ms per page of
200). A page counter shows the loading. Only loading older data is shown,
although `onLoadAfter` exists.

## A6. Lazy widget markers

**What it is.** Widgets per data point (pins, chips, photos) that exist only
while their data is visible.

**Why it matters.**

- Users want a widget at a data point, such as a photo or a chip. When point
  markers accept only a painter, the app has to draw these by hand or stack
  widgets over the chart and position them itself.
- The approach that works is a builder that returns a widget per point.

**In plot_twist.** `ChartLayoutBuilder<T>(selector: (view) => …, builder: …)`
runs its builder only when the selected value changes. Select the range of
visible indices and return a `ChartStack` of keyed `ChartPositioned` widgets.
While the chart is merely panned, the builder does not run.

**Demo.** Forty photo pins on a 2,000-point profile, with a counter of how
many pin widgets exist. Each pin has an ordinary Material `Tooltip`. Collision
avoidance between markers is not part of the package.

## A7. Widgets as axis labels

**What it is.** Tick labels are widgets. The axis sizes itself from them.
Labels slide during a pan instead of being rebuilt.

**Why it matters.**

- A label builder that returns a widget is only half the job. If the gutter's
  size must be set by hand, longer labels are cut off or overlap, and if
  panning rebuilds the label widgets every frame, panning is slow.
- A label formatter that returns only text and a style cannot show an icon or
  a two-line label.

**In plot_twist.** `ChartAxis` is a widget in a side slot of the chart. The
chart measures side slots before it fixes the plot rectangle, so
`ChartAxisExtent.auto()` (the default) makes the gutter as thick as the labels
need. It grows at once and shrinks only while the chart is idle, so it does
not jitter. `labelBuilder: (context, tick) => …` returns any widget, and
`format: (tick) => …` covers the text-only case. Labels are keyed by tick and
rebuilt only when a tick enters or leaves. Labels that would collide are
dropped; rotating or staggering them is not built in.

**Demo.** An icon over two lines of text on the X axis and chips on the Y
axis. A switch makes the chips longer and the gutter makes room.

## A8. Custom series

**What it is.** The app adds a new kind of mark without forking, and it works
with automatic ranges, tooltips, the crosshair and the legend.

**Why it matters.**

- Users ask how to build marks a library does not have, such as a sleep-cycle
  chart. Often a custom series means subclassing a series renderer and its
  segment class, which ties app code to the library's internals. Sometimes
  there is no extension point at all, and a custom line painter means forking.
- The approach that works is a public custom-series API that the built-in
  series use too.

**In plot_twist.** Extend `ChartSeriesPainter` and show it with `ChartPaint`.

| Method | What it gives the series |
|---|---|
| `paint(context)` | drawing, with `context.canvas` and `context.view` |
| `bounds({xWindow, yWindow})` | automatic ranges, including fit-to-visible |
| `collectHits(query, hits)` | tooltips, the crosshair and snapping |
| `valueAt(x)` | overlays that follow the drawn curve |

`ChartPaint(id: …, label: …, color: …)` lists it in `controller.series` for a
legend. The built-in line, bar, scatter and candlestick series use the same
contract.
Animation, semantics and data reduction for a custom series are the painter's
own job.

**Demo.** A sleep hypnogram written in the demo file, with a crosshair and a
tooltip that reads the stage from the hit's `datum`.

## A9. Custom interactions and coexisting gestures

**What it is.** Apps add their own behaviors next to the built-in ones, and a
chart inside a scrolling parent does not steal its gestures.

**Why it matters.**

- A chart inside a `PageView` breaks swiping between pages, because the chart
  takes every drag.
- Users ask to turn off scrolling in a chart inside a scroll view but keep its
  taps. When the interactions are a few fixed slots, the app cannot add its
  own or change the mix.
- The approach that works treats behaviors as an open list and lets the app
  register its own gestures next to the built-in ones.

**In plot_twist.**

- Behaviors are ordinary children, so the list is open.
- `ChartPanZoom` uses its own recognizer. It claims a drag only along the
  dimensions it pans, so a vertical drag falls through to a parent `ListView`.
  `yieldAtLimits: true` hands the drag to a parent `PageView` at the end of
  the data, and `wheelRequiresModifier: true` leaves the plain wheel to the
  page.
- `ChartGestureDetector(gestures: …)` registers any recognizer with the
  chart's pointer hub. It sees pointers over the plot and the gutters, even
  when a widget in the chart is on top.
- `ChartGestureShield` keeps a widget's own drags away from the chart.

**Demo.** A chart in a vertical list and three charts in a `PageView`, plus a
long-press measure tool written in the demo. The research's version also had a
Shift-drag brush; the demo leaves that out. Keyboard input is shown in A18.

## A10. Large data

**What it is.** A line with a million points pans smoothly and looks the same
as the full drawing.

**Why it matters.**

- Charts crash when given large data sets.
- Apps hang with 10,000 to 30,000 bars.

**In plot_twist.** `ChartData` keeps values in `Float64List` columns. Series
find the visible rows by binary search. When a straight-segment line has more
than ten rows per pixel, `LineSeries` reduces the rows in each half-pixel
column to that column's first, lowest, highest and last value. A test renders
200,000 points both ways and compares the two images. A two-level min/max
index answers "what is the Y extent of this X window" without a scan.

**Demo.** A million-point random walk with a switch for the reduction and a
readout of the slowest frame while moving.

**Measured.** On macOS in profile mode, 90% of frames built in 2.2 ms or less
and rastered in 1.5 ms or less while zooming and panning, with no missed
frames. The run is `example/test_driver/perf_test.dart`. No phone was
measured. The research's version also had 100,000 candles; those are measured
under A26.

## A11. Mixed series and several Y axes

**What it is.** Bars, lines, areas and points share a plot, on two or more Y
scales.

**Why it matters.**

- Users want bars and a line in one chart without stacking two chart widgets
  and lining them up by hand. A second Y axis is a related, long-standing
  request. The cause is that line charts and bar charts are separate widgets.

**In plot_twist.** There is one `Chart` widget and no chart types. A chart has
named scales (`x`, `y`, and more in `yScales:` and `xScales:`), and each series
and axis names the scale it uses with `yScale:` or `scale:`.

**Demo.** Rain as bars on a right-hand axis, mean temperature as a line on the
left, and a floating bar per day for the minimum and maximum, read from a
second value column. Each series is wrapped in a `ChartAppear`, so the bars
grow and the line is drawn in when the chart first shows. Bars lie down with
`BarSeries(direction: Axis.horizontal)`, which A19 shows.

## A12. Crosshair as shared state

**What it is.** What the user points at is a value app code can read, set and
share. It snaps to data and survives data updates.

**Why it matters.**

- Rebuilding the chart, for example after a `setState`, clears the selection
  and the crosshair.
- Tooltips synced across several charts get slower with every chart added.
- An imperative "show the trackball at x, y" call gives app code nothing to
  read or share.

**In plot_twist.** `ChartController.focus` is a
`ValueNotifier<ChartFocus?>` in data space. `ChartCrosshair` writes it.
`ChartTooltip` and `ChartCrosshairBadge` (a value badge on an axis) read it,
and so can any widget outside the chart. `controller.hitsAt(x)` returns the
nearest point of every series.

**Demo.** A snapped rule with dots, a badge on each axis, a tooltip, and a
table beside the chart that highlights and scrolls to the pointed-at row.
Setting the focus from code is shown in A18.

## A13. Y auto-fit

**What it is.** The Y range follows the data visible in the X window. When the
user moves Y by hand, fitting stops until it is asked for again.

**Why it matters.**

- When the user zooms into part of the data, the Y range stays fitted to the
  whole data set, so the visible part is a flat line. Without built-in
  fitting, the app scans the visible data and sets the range itself on every
  pan.
- The approach that works asks each series for its extent inside the visible
  X window.

**In plot_twist.** A scale's `range` is a policy: `.fit()`, `.fitVisible()`,
`.fixed(min, max)` or `.follow(span: …)`. With `.fitVisible()` the chart asks
every series for its bounds inside the X window, including custom series.
Moving the scale by hand switches it to manual. `isAuto` says which state it
is in and `resetToAuto(duration: …)` animates back.

**Demo.** Ten years of daily prices. The feature is
`y: const .linear(range: .fitVisible(padding: 0.1))`; a chip shows the state
and restores fitting.

## A14. Pluggable scales

**What it is.** Linear, logarithmic, time and category scales, custom scales,
custom ticks, and gaps in data.

**Why it matters.**

- Users ask for a `DateTime` X axis and a logarithmic axis. Without them,
  dates are converted to numbers and labelled by hand.
- When date-time, category and logarithmic axes are separate axis classes,
  the app cannot write a scale of its own, and switching scale means switching
  axis class.

**In plot_twist.** A `ChartScale` is a strictly increasing `transform`, its
`invert` and a default `ChartTicks`. The window is stored in transformed
units, so panning and zooming work the same on every scale. `LinearScale`,
`LogScale`, `TimeScale` and `BandScale` are built in, each can be `reversed`,
and `ticks:` replaces the tick strategy. A NaN value is a gap in a line.
Linear, logarithmic and band ticks can have minor ticks
(`LinearTicks(minorCount: 4)`, `LogTicks(minor: true)`): the axis marks them
and `ChartGrid(minor: true)` draws a fainter line at each.

**Demo.** Two years of hourly weekday prices. Time ticks change unit while
zooming, a chip switches Y between linear and logarithmic, both with minor
ticks, and another swaps X for `TradingDaysScale`, an 18-line scale written in
the demo that gives weekends no room.

## A15. Live data

**What it is.** Samples arrive many times a second. The window follows the
newest data until the user pans away.

**Why it matters.**

- A real-time line is not smooth, because each new sample rebuilds the chart.
- While live data arrives, the user cannot scroll back to older data; the
  chart snaps back to the newest.
- The approach that works follows the newest data until the user pans, and
  resumes following on request.

**In plot_twist.** `ChartData.add` and `addAll` append and notify once. The
series repaints; no widget is rebuilt. Following is a range policy,
`.follow(span: 10)`. Panning switches the scale to manual, which pauses
following, and `resetToAuto` resumes it. `removeFirst` drops old rows.

**Demo.** A 250-samples-per-second ECG with a ten-second window, one minute
kept, and a chip that shows "Live" or resumes following.

**Measured.** On macOS in profile mode, 90% of frames built in 0.8 ms or less
and rastered in 1.3 ms or less, with no missed frames.

## A16. Linked charts

**What it is.** Several charts share an X window and a crosshair. Moving one
moves all.

**Why it matters.**

- Users want to zoom one chart and have the charts below it follow. The
  problems in A1 (binding the range turns off zoom) and A12 (synced tooltips
  slow down with each chart) stand in the way.

**In plot_twist.** Pass the same `ChartScaleController` and the same focus
notifier to several controllers: `ChartController(x: time, focus: focus)`. A
`ChartGutterGroup` with `ChartAxisExtent.shared(group)` makes the axes of all
the charts equally thick, so the plots line up.

**Demo.** Price, volume and a strength line as three `Chart` widgets in a
`Column`. Resizable dividers between panes are left out.

## A17. Editable annotations

**What it is.** Reference lines, bands and handles in data space that the user
can drag.

**Why it matters.**

- Reference lines and range bands that only paint cannot be dragged by the
  user, and they tend to be clipped wrongly at the edges of the plot.

**In plot_twist.** `ChartReferenceLine.y(value)` and `.x(value)` draw a line
at a value, solid or dashed, with an optional label widget; `includeInRange`
makes automatic ranges show it. Everything else is made of the public pieces.
A `ChartPainter` draws other lines and fills. The handles are
`ChartPositioned` widgets with their own `GestureDetector`, wrapped in
`ChartGestureShield` so that dragging them does not pan the chart.
`view.toValue(pixel)` turns a drag into data units.

**Demo.** A dashed threshold line with a pill that shows its value and a
tinted area above it, and a trend line with a handle at each end. Drawing new
lines and saving annotations are left out.

## A18. Accessibility

**What it is.** A summary for screen readers, a node per data point, and
keyboard navigation.

**Why it matters.**

- Screen readers do not read tooltip content, and often only one chart type,
  such as the pie, has any semantics.
- The approach that works offers keyboard navigation between points, a label
  per point for screen readers, and a data table as an alternative.

**In plot_twist.** `Chart(semanticLabel: …)` gives the summary. A node per
point is a `Semantics` widget stretched over its bar with
`ChartPositioned.span`, built for visible bars only by `ChartLayoutBuilder`.
Keyboard navigation is a `Focus` widget that sets `controller.focus`, which
the crosshair and tooltip already follow.

**Demo.** A 12-bar chart with all three. A widget test checks that the nodes
exist, sit on their bars and focus their bar when activated, and that the
arrow keys move the focus. It was not tried with VoiceOver or TalkBack.
`AnimatedChartData` and `ChartAppear` skip their animations when
`MediaQuery.disableAnimations` is set; animated window changes (`animateTo`, `resetToAuto` with a duration)
and flings do not read it.

## A19. Animated transitions

**What it is.** When data changes, marks move to their new places, new ones
grow in and old ones shrink away.

**Why it matters.**

- Users want bars to grow in when the chart first appears, and marks to move
  when the data changes instead of jumping.

**In plot_twist.** There are two animations, for two cases.

- From one data set to another: `AnimatedChartData(data: target, builder:
  (context, animated) => …)` gives the series a `ChartData` that moves towards
  the target. Each frame repaints the series and re-fits the scales. A custom
  series reads the animated `ChartData` in the same way.
- The first show: `ChartAppear(child: …)` around a series or a whole chart
  grows the series in (`growY`, `growX`), uncovers them (`reveal`) or fades
  them in. Only the painting is animated, so the axes stand still, and every
  series gets it, also a custom one. A11 uses it.

Window moves animate with `animateTo` and `resetToAuto(duration: …)`.
`AnimatedChartData` and `ChartAppear` are skipped when the platform asks for
reduced motion; window moves and flings are not.

**Demo.** Week, month and year bars that morph into each other. A button lays
the bars down (`BarSeries(direction: Axis.horizontal)`), and a
`ChartDataLabels` layer writes each value at the end of its bar in both
directions.

## A20. Legend outside the chart

**What it is.** The legend is an ordinary widget, anywhere in the app, fed by
public series metadata.

**Why it matters.**

- Users want a legend they can place and style themselves. Without public
  series metadata, they keep their own copy of the series list and keep it in
  sync with the chart by hand.

**In plot_twist.** `controller.series` lists every series in paint order with
its `id`, `label`, `color` and `visible`, and `controller.seriesListenable`
notifies when the list changes. Every series has a `visible` flag. A hidden
series stays in the list but is not drawn or measured, so the scales re-fit.

`ChartLegend` is a legend built on that list: a dot and a label per series,
complete on the first frame. It goes in a side slot of the chart, or anywhere
else with the chart's controller. It reports taps and long presses and leaves
the `visible` of each series to the app's state. `itemBuilder` replaces its
items, and a legend of your own is still a `ListenableBuilder` over the same
list.

**Demo.** A `ChartLegend` above the chart. Tap hides a series and long-press
shows only that one. The four series have no colour of their own: each takes
the next colour of the theme's palette.

## A21. Non-Cartesian content

**What it is.** A pie, donut or gauge on the same core, with the same widgets
and interactions.

**Why it matters.**

- Circular charts are often a separate widget stack, with interactions of
  their own and none of the Cartesian chart's tools.
- Users ask for gauges, which no built-in chart type covers.

**In plot_twist.** Nothing in `Chart` requires axes. A `ChartPainter` gets the
plot size and draws anything. `ChartPositioned.resolve` places widgets from
the painter's own geometry, and `ChartGestureDetector(onPointerHover: …)`
gives hover and tap.

**Demo.** A donut with a widget in the centre, a widget label per slice and a
hover tooltip. The geometry (angles, hit testing) is 24 lines in the demo.
plot_twist has no polar coordinate system of its own, and the radar chart
planned for this demo was dropped to keep the file under the line limit.

## A22. Data-driven styling

**What it is.** Style depends on the data, and charts follow the app's theme.

**Why it matters.**

- Users want a line whose colour depends on its value, such as red above a
  threshold and blue below another.

**In plot_twist.** `LineSeries(shader: (view) => …)` builds a shader from the
current view, so gradient stops can be data values. `dash:` draws a dashed
line. `BarSeries(colorOf: …)` colours single bars. A series without a `color`
takes the colour the theme's palette has for its place in the chart: the
first series the first colour, the second the next. Without a `ChartTheme`,
charts take their colours from the ambient `DefaultTextStyle`, so they follow
light and dark themes; `ChartTheme` overrides them.

**Demo.** A temperature line that is red above 30° and blue below 0°, a dashed
forecast, and a dark-theme switch. The example's `MaterialChartTheme` helper
maps a Material colour scheme to a `ChartTheme`.

## A23. Navigator by composition

**What it is.** A small chart of the whole range with a draggable window bound
to the main chart.

**Why it matters.** Stock and analytics charts often have a navigator, and
users expect it. Here it is also a test of composition: if A1 and A3 are
right, no navigator class is needed.

**In plot_twist.** A second `Chart` shows the same data. The window is a
`ChartPositioned.span` between `main.x.min` and `main.x.max`, rebuilt by a
`ListenableBuilder` on `main.x`. Dragging it calls `main.x.panBy`, and
dragging its edges calls `main.x.jumpTo`.

**Demo.** Exactly that, in 90 lines.

## A24. Many small charts

**What it is.** Hundreds of sparklines in a scrolling list.

**Why it matters.**

- An app with six tabs of two to four charts each becomes slow.
- Sparklines often need a separate library, because a full chart is too heavy
  for a list row.

**In plot_twist.** A chart with no behaviors creates no gesture recognizers,
tickers or pointer listeners. `isolate: false` on the chart and the series
removes their repaint boundaries, so a row costs no compositing layers.

**Demo.** Five hundred rows, each with a sparkline and its change.

## A25. Export

**What it is.** Render a chart to an image, including the widgets in it.

**Why it matters.**

- Users want to save a chart as an image or share it.

**In plot_twist.** A chart is ordinary Flutter rendering, so
`RepaintBoundary.toImage(pixelRatio: 3)` captures it with every widget in it.

**Demo.** A button that exports a 3× PNG and shows it. Rendering a chart that
is not on screen and SVG output are not covered.

## A26. Candlesticks

**What it is.** A built-in series of open-high-low-close candles that behaves
like every other series. Y fits the lows and highs in view, the crosshair and
tooltip read all four prices, the last candle changes while it trades, closed
days need not take room, and a long history stays cheap to pan.

**Why it matters.**

- A candlestick is the basic mark of a price chart. An app that shows markets
  needs it before anything else a chart package offers, and other Flutter
  chart packages have it built in.
- Drawing the candle is the small part. The Y range has to come from two
  columns, the lows and the highs. One mark has four values for a tooltip.
  Rows are unevenly spaced, because markets close at night and at weekends.
  The last candle changes with every trade. Twenty years of daily candles are
  5,000 rows, and an intraday history is far longer.

**In plot_twist.** `CandlestickSeries(data: …)` reads four value columns of a
`ChartData`: open, high, low and close. It is written on the
`ChartSeriesPainter` contract of A8, as the other built-in series are.

- `bounds` reports the lowest low and the highest high inside the X window,
  so `.fitVisible()` works as in A13.
- A hit has the close as its value and a `ChartCandle` with the four prices
  as its `datum`. Its `rect` is the candle, so the crosshair draws its rule
  and no dot, as it does for a bar.
- A body is `widthFactor` × `step` wide. `step` defaults to the smallest
  distance between the first rows, so a weekend without rows does not widen
  the candles. The width is measured in pixels on both sides of a candle, so
  a custom scale that gives closed days no room does not squeeze the candle
  next to the gap.
- `ChartData.setValue` changes the candle that is still trading and `addRow`
  opens the next one. The series repaints and the scales re-fit; no widget is
  rebuilt.
- When a step is narrower than a pixel, each pixel column is drawn as one
  candle made of its rows: lowest low to highest high, coloured by the first
  open and the last close. A test renders 100,000 candles and checks every
  pixel column against the data.

**Demo.** 5,000 trading days with volume bars on a second Y scale, a
last-price pill on the axis, and a tooltip with the four prices and the
volume. A timer trades the last candle ten times a second, and the window
follows it until the user pans away. X is the number of the trading day and
the axis labels turn it into a date, so weekends take no room.
`style: CandleStyle.hollow` and `CandleStyle.ohlc` draw hollow candles and
open-high-low-close bars. Indicators are not built in.

**Measured.** On macOS in profile mode, wheel-zooming the demo out to all
5,000 days and back in, 90% of frames built in 2.7 ms or less and rastered in
1.7 ms or less. A chart of 100,000 candles in the driver, which is not a
gallery demo, built 90% of its frames in 1.9 ms or less and rastered them in
1.5 ms or less while zooming and panning. Neither missed a frame. In this run
the app window could not be brought to the foreground, and the A10 wheel zoom
measured 2.7 ms and 1.7 ms in it instead of the 2.2 ms and 1.3 ms of the run
quoted under A10.

---

## How the demos were checked

- **Automated.** `example/test/demos_test.dart` runs every demo with a real
  font: it builds it, hovers, drags, scrolls the wheel, disposes it, and fails
  on any exception. It also writes a screenshot of each demo to
  `example/build/screenshots/`. A18 and A26 have a test of their own for what
  their descriptions claim.
- **By hand.** Every demo was driven in Chrome on the web build: each
  behavior its description names was tried and seen to work.
- **Package tests.** The mechanisms behind the demos have their own tests in
  `test/`: no widget builds during a pan, axis layout, the gesture matrix
  (list, page view, wheel, trackpad, pinch, fling), tooltips, linked charts,
  data reduction, candlesticks and the README's code.
- **Not done.** No demo was run on a phone or tablet, and none with a screen
  reader.

## Considered and left out

- **More chart types** (sankey, treemap, funnel, 3D, maps). A8 and A21 cover
  how to write them.
- **Financial indicators, regression lines and aggregation.** These are data
  transforms and belong to the app.
- **A grammar or fluent syntax.** It can be added on top later.
- **GPU rendering of 100 million points.** The target is a million points on
  a `Canvas`.

## Lessons from the research

1. The viewport and the coordinate system must be first-class, in data space
   and observable. The strongest libraries give app code the conversion
   between data and pixels. Lazy loading, syncing, auto-fit and derived
   overlays then become app code.
2. Built-in series should use the same public contract as extensions.
3. Behaviors should be an open list with their state outside the chart.
4. Widgets should be real children of a custom multi-child render object:
   placed during layout from data coordinates, built lazily, and laid out
   again instead of rebuilt during a pan.
5. The core should stay small. plot_twist has about 12,300 lines and depends on
   nothing but Flutter.

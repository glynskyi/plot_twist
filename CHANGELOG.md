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

# plot_twist examples

## A price chart

A time axis, a Y axis that follows whatever the X window shows, pan and zoom, a
crosshair and a tooltip:

```dart
import 'package:flutter/widgets.dart';
import 'package:plot_twist/plot_twist.dart';

class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.prices});

  /// For example `ChartData.fromXY(times, values)`.
  final ChartData prices;

  @override
  Widget build(BuildContext context) {
    return Chart(
      x: const .time(),
      y: const .linear(range: .fitVisible()),
      left: const <Widget>[ChartAxis()],
      bottom: const <Widget>[ChartAxis()],
      children: <Widget>[
        const ChartGrid(),
        LineSeries(data: prices, label: 'Price'),
        const ChartPanZoom(),
        const ChartCrosshair(),
        const ChartTooltip(),
      ],
    );
  }
}
```

Drag to pan, pinch or scroll to zoom, drag an axis to stretch it, and
double-tap to reset.

## The gallery

This folder is a gallery app with one small demo for each of the 26 aspects a
chart library is judged on: widgets as tooltips and axis labels, lazily loaded
history, live data, linked charts, a million points, candlesticks and more.
Each demo is a single file under
[`lib/demos/`](https://github.com/glynskyi/plot_twist/tree/main/example/lib/demos)
written against the public API only.

- Try it in the browser: <https://glynskyi.github.io/plot_twist/>
- Run it locally:

  ```sh
  cd example
  flutter run -d macos   # or -d chrome
  ```

[`doc/aspects.md`](https://github.com/glynskyi/plot_twist/blob/main/doc/aspects.md)
explains why each aspect matters and how plot_twist meets it.

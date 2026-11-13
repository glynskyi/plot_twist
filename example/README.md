# plot_twist gallery

One small demo for each of the 26 aspects that plot_twist was designed
against. Each demo is one file in `lib/demos/`, written with the package's
public API only. A button on each demo shows its source and line count.

[../doc/aspects.md](../doc/aspects.md) explains what each demo proves.

## Run it

```sh
flutter run -d macos   # or -d chrome
```

## Test it

```sh
flutter test
```

The tests build every demo, hover, drag and scroll over it, and write a
screenshot of each to `build/screenshots/`. They also check that every demo
stays under 120 lines and imports nothing private.

## Measure it

```sh
flutter drive --profile -d macos \
  --target=test_driver/perf.dart --driver=test_driver/perf_test.dart
```

This zooms and pans the million-point demo, runs the live demo, zooms the
candlestick demo, and zooms and pans a chart of 100,000 candles. It then
prints frame build and raster times and writes them to
`build/perf_summary.json`.

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';
import '../shared/ui.dart';

/// A26 — Candlesticks: 5,000 trading days with volume. The last candle trades
/// live and the window follows it until you pan away. X counts trading days,
/// so weekends take no room. Zoomed out, every pixel column is drawn as one
/// candle.
class CandlesticksDemo extends StatefulWidget {
  const CandlesticksDemo({super.key});

  @override
  State<CandlesticksDemo> createState() => _CandlesticksDemoState();
}

class _CandlesticksDemoState extends State<CandlesticksDemo> {
  static const Color up = Color(0xFF26A69A);
  static const Color down = Color(0xFFEF5350);
  static const int tradesPerDay = 30;
  static final double firstDay = DateTime.utc(2007).millisecondsSinceEpoch.toDouble();

  // One row per trading day: open, high, low, close and volume.
  final ChartData days = ChartData(valueColumns: 5, capacity: 5200);
  final math.Random random = math.Random(21);
  late final Timer timer;
  int trades = 0;

  @override
  void initState() {
    super.initState();
    days.addRow(0, <double>[40, 40, 40, 40, 0]);
    while (days.length < 5000) {
      _trade();
    }
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _trade());
  }

  @override
  void dispose() {
    timer.cancel();
    days.dispose();
    super.dispose();
  }

  // One trade moves the close of the last candle; its high, low and volume
  // follow. After a day's worth of trades the next candle opens.
  void _trade() {
    final int last = days.length - 1;
    final double price = days.value(last, 3) * (1 + (random.nextDouble() - 0.5) * 0.008);
    days
      ..setValue(last, math.max(days.value(last, 1), price), column: 1)
      ..setValue(last, math.min(days.value(last, 2), price), column: 2)
      ..setValue(last, price, column: 3)
      ..setValue(last, days.value(last, 4) + random.nextDouble(), column: 4);
    if (++trades % tradesPerDay == 0) {
      days.addRow(days.length.toDouble(), <double>[price, price, price, price, 0]);
    }
  }

  // Trading day 0 is a Monday; five trading days make a week.
  static String _date(double day) =>
      shortDate(firstDay + (day.round() ~/ 5 * 7 + day.round() % 5) * dayMs);

  bool _falls(int row) => days.value(row, 3) < days.value(row, 0);

  @override
  Widget build(BuildContext context) {
    return Chart(
      // Follow the newest candle, with room for two more.
      x: const .linear(
        range: .follow(span: 90, lead: 2),
        limits: .data(padding: 0.01),
        ticks: BandTicks(spacing: 110, format: _date),
      ),
      y: const .linear(range: .fitVisible(padding: 0.12)),
      // Volume keeps to the bottom quarter of the plot.
      yScales: const <Object, ChartScale>{
        'volume': LinearScale(range: FitVisibleRange(includeZero: true, padding: 3)),
      },
      right: <Widget>[
        ChartAxis(
          extent: const .fixed(60),
          markers: <Widget>[
            // The last price: rebuilt when a trade arrives, placed by the axis.
            ListenableBuilder(
              listenable: days,
              builder: (BuildContext context, Widget? child) {
                final double price = days.value(days.length - 1, 3);
                return ChartAxisMarker(
                  value: price,
                  clamp: true,
                  child: Pill(price.toStringAsFixed(2), color: _falls(days.length - 1) ? down : up),
                );
              },
            ),
          ],
        ),
      ],
      bottom: const <Widget>[ChartAxis()],
      children: <Widget>[
        const ChartGrid(),
        BarSeries(
          data: days,
          column: 4,
          yScale: 'volume',
          colorOf: (int row, double x, double y) =>
              (_falls(row) ? down : up).withValues(alpha: 0.3),
        ),
        CandlestickSeries(data: days, label: 'ACME', upColor: up, downColor: down),
        const ChartPanZoom(),
        const ChartCrosshair(),
        ChartTooltip(
          builder: (BuildContext context, List<ChartHit> hits) {
            // Each hit of the candle series carries the four prices.
            final ChartHit hit = hits.firstWhere((ChartHit h) => h.datum is ChartCandle);
            final ChartCandle c = hit.datum! as ChartCandle;
            String f(double price) => price.toStringAsFixed(2);
            return Pill(
              '${_date(hit.x)}   O ${f(c.open)}  H ${f(c.high)}  L ${f(c.low)}  C ${f(c.close)}'
              '   Vol ${days.value(hit.index!, 4).toStringAsFixed(1)}M',
              color: c.isUp ? up : down,
            );
          },
        ),
      ],
    );
  }
}

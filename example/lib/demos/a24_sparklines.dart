import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A24 — Five hundred charts in a list. A chart with no behaviors has no
/// gesture recognizers, tickers or listeners, and with `isolate: false` no
/// layers of its own — so it is cheap enough to use as a sparkline.
class SparklinesDemo extends StatefulWidget {
  const SparklinesDemo({super.key});

  @override
  State<SparklinesDemo> createState() => _SparklinesDemoState();
}

class _SparklinesDemoState extends State<SparklinesDemo> {
  // Data is created when a row first scrolls into view, and kept.
  final Map<int, ChartData> series = <int, ChartData>{};

  ChartData _data(int index) =>
      series[index] ??= randomWalk(60, seed: index + 1, start: 50, volatility: 2);

  @override
  void dispose() {
    for (final ChartData data in series.values) {
      data.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: 500,
      itemExtent: 44,
      itemBuilder: (BuildContext context, int index) {
        final ChartData data = _data(index);
        final double change = data.y(59) - data.y(0);
        // Decided on the rounded value, so a tiny loss reads +0.0, not -0.0.
        final bool up = change > -0.05;
        final Color color = up ? const Color(0xFF59A14F) : scheme.error;
        return Row(
          children: <Widget>[
            SizedBox(width: 90, child: Text('Ticker ${index + 1}')),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Chart(
                  isolate: false,
                  y: const .linear(range: .fit(padding: 0.1)),
                  children: <Widget>[
                    LineSeries(
                      data: data,
                      color: color,
                      width: 1.5,
                      fillColor: color.withValues(alpha: 0.12),
                      isolate: false,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                '${up ? '+' : '-'}${change.abs().toStringAsFixed(1)}',
                textAlign: TextAlign.end,
                style: TextStyle(color: color),
              ),
            ),
          ],
        );
      },
    );
  }
}

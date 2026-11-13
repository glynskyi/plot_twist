import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';
import '../shared/ui.dart';

/// A5 — History loads as you scroll towards it. Loading never blocks the
/// scroll, a placeholder widget covers what has not arrived, and rows that
/// are prepended do not move what is on screen.
class InfiniteHistoryDemo extends StatefulWidget {
  const InfiniteHistoryDemo({super.key});

  @override
  State<InfiniteHistoryDemo> createState() => _InfiniteHistoryDemoState();
}

class _InfiniteHistoryDemoState extends State<InfiniteHistoryDemo> {
  static const int pageSize = 200;
  final double end = year2026 + 300 * dayMs;
  late final double domainStart = end - 20 * 365 * dayMs; // 20 years of history exist
  final ChartData data = ChartData();
  int pages = 0;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    data.addAll(
      List<double>.generate(pageSize, (int i) => end - (pageSize - 1 - i) * dayMs),
      walk(pageSize, volatility: 2),
    );
  }

  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  // The "API": 300 ms per page of 200 days.
  Future<bool> _loadOlder() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final double first = data.x(0);
    final int n = math.min(pageSize, ((first - domainStart) / dayMs).round());
    if (n <= 0) return false;
    data.prependAll(
      List<double>.generate(n, (int i) => first - (n - i) * dayMs),
      walk(n, seed: pages + 7, start: data.y(0), volatility: 2).reversed.toList(),
    );
    if (mounted) setState(() => pages++);
    return first - n * dayMs > domainStart;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Pages loaded: $pages   ·   ${data.length} days in memory   ·   '
          '${loading ? 'loading…' : 'idle'}',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Chart(
            x: ChartScale.time(
              utc: true,
              range: FixedRange(end - 120 * dayMs, end),
              // The user may scroll anywhere in the 20 years, loaded or not.
              limits: ChartLimits(min: domainStart, max: end),
            ),
            y: const .linear(range: .fitVisible()),
            left: const <Widget>[ChartAxis(extent: .fixed(48))],
            bottom: const <Widget>[ChartAxis()],
            children: <Widget>[
              const ChartGrid(),
              LineSeries(data: data),
              // A widget stretched over everything older than what is loaded.
              ListenableBuilder(
                listenable: data,
                builder: (BuildContext context, Widget? child) => ChartPositioned.span(
                  x1: .value(domainStart),
                  x2: .value(data.x(0)),
                  child: const Shimmer(),
                ),
              ),
              const ChartPanZoom(),
              ChartLoader(
                data: data,
                onLoadBefore: _loadOlder,
                onLoadingChanged: (bool value) => setState(() => loading = value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

/// A15 — Live data at 250 samples a second. The window follows the newest
/// sample until you pan away; the chip resumes following. Samples are appended
/// to the data store — no widget is rebuilt per sample.
class LiveDemo extends StatefulWidget {
  const LiveDemo({super.key});

  @override
  State<LiveDemo> createState() => _LiveDemoState();
}

class _LiveDemoState extends State<LiveDemo> with SingleTickerProviderStateMixin {
  static const double rate = 250;
  final ChartController chart = ChartController();
  final ChartData ecg = ChartData();
  final math.Random random = math.Random(2);
  late final Ticker ticker;
  double time = 0;

  @override
  void initState() {
    super.initState();
    ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    ticker.dispose();
    chart.dispose();
    ecg.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final double now = elapsed.inMicroseconds / 1e6;
    final List<double> xs = <double>[];
    final List<double> ys = <double>[];
    for (; time < now; time += 1 / rate) {
      xs.add(time);
      ys.add(_heart(time % 1) + (random.nextDouble() - 0.5) * 0.03);
    }
    ecg.addAll(xs, ys);
    // Keep one minute.
    if (ecg.length > rate * 60) ecg.removeFirst(ecg.length - (rate * 60).round());
  }

  // One heartbeat: P wave, QRS complex, T wave.
  static double _heart(double p) {
    double bump(double centre, double width, double height) =>
        height * math.exp(-math.pow((p - centre) / width, 2));
    return bump(0.2, 0.03, 0.12) +
        bump(0.37, 0.012, -0.15) +
        bump(0.4, 0.012, 1) +
        bump(0.43, 0.012, -0.25) +
        bump(0.65, 0.05, 0.3);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListenableBuilder(
          listenable: chart.x,
          builder: (BuildContext context, Widget? child) => chart.x.isAuto
              ? const Chip(
                  avatar: Icon(Icons.circle, color: Colors.red, size: 12),
                  label: Text('Live'),
                )
              : ActionChip(
                  avatar: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Paused — tap to follow again'),
                  onPressed: chart.x.resetToAuto,
                ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Chart(
            controller: chart,
            // Following is a range policy: show the latest ten seconds.
            x: const .linear(range: .follow(span: 10)),
            y: const .linear(range: .fixed(-0.5, 1.3)),
            left: const <Widget>[ChartAxis(extent: .fixed(40))],
            bottom: <Widget>[ChartAxis(format: (ChartTick tick) => '${tick.label} s')],
            children: <Widget>[
              const ChartGrid(),
              LineSeries(data: ecg, width: 1.5),
              const ChartPanZoom(),
            ],
          ),
        ),
      ],
    );
  }
}

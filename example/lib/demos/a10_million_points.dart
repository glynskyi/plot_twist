import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A10 — A million points. Only the visible rows are touched, and where many
/// rows share a pixel they are reduced to their extremes — so the line looks
/// the same and stays smooth to pan. Switch the reduction off to compare.
class MillionPointsDemo extends StatefulWidget {
  const MillionPointsDemo({super.key});

  @override
  State<MillionPointsDemo> createState() => _MillionPointsDemoState();
}

class _MillionPointsDemoState extends State<MillionPointsDemo> {
  final ChartController chart = ChartController();
  final ChartData data = randomWalk(1000000);
  bool decimate = true;
  double worstFrameMs = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    chart.dispose();
    data.dispose();
    super.dispose();
  }

  // Report the slowest frame while the chart is being moved.
  void _onTimings(List<FrameTiming> timings) {
    if (!mounted || !chart.isInteracting) return;
    final int micros = timings.map((FrameTiming t) => t.totalSpan.inMicroseconds).reduce(math.max);
    setState(() => worstFrameMs = micros / 1000);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Switch(value: decimate, onChanged: (bool v) => setState(() => decimate = v)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '1,000,000 points · reduction ${decimate ? 'on' : 'off'} · '
                'slowest frame while moving: ${worstFrameMs.toStringAsFixed(1)} ms',
              ),
            ),
          ],
        ),
        Expanded(
          child: Chart(
            controller: chart,
            // Pan and zoom stay within the data.
            x: const .linear(limits: .data()),
            y: const .linear(range: .fitVisible()),
            left: const <Widget>[ChartAxis(extent: .fixed(52))],
            bottom: const <Widget>[ChartAxis()],
            children: <Widget>[
              const ChartGrid(),
              LineSeries(data: data, width: 1, decimate: decimate),
              const ChartPanZoom(),
            ],
          ),
        ),
      ],
    );
  }
}

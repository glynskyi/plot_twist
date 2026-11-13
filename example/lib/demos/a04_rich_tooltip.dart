import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A4 — The tooltip is a real widget: it holds an avatar, another chart and a
/// working button. Tap a point to pin it. It flips at the edges, follows its
/// point while panning, and can live in the app overlay to leave the chart.
class RichTooltipDemo extends StatefulWidget {
  const RichTooltipDemo({super.key});

  @override
  State<RichTooltipDemo> createState() => _RichTooltipDemoState();
}

class _RichTooltipDemoState extends State<RichTooltipDemo> {
  final ChartData visitors = randomWalk(40, start: 500, volatility: 60, seed: 5);
  bool overlay = false;

  @override
  void dispose() {
    visitors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SwitchListTile(
          dense: true,
          title: const Text('Show in the app overlay (the tooltip may leave the chart)'),
          value: overlay,
          onChanged: (bool v) => setState(() => overlay = v),
        ),
        Expanded(
          child: Chart(
            y: const .linear(range: .fit(padding: 0.25)),
            left: const <Widget>[ChartAxis()],
            bottom: const <Widget>[ChartAxis()],
            children: <Widget>[
              const ChartGrid(),
              LineSeries(data: visitors, label: 'Visitors', pointRadius: 3),
              const ChartPanZoom(doubleTapToReset: false),
              const ChartCrosshair(tap: true),
              ChartTooltip(
                interactive: true,
                overlay: overlay,
                builder: (BuildContext context, List<ChartHit> hits) =>
                    _VisitCard(hit: hits.first, history: visitors),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.hit, required this.history});

  final ChartHit hit;
  final ChartData history;

  @override
  Widget build(BuildContext context) {
    final int day = hit.x.round();
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 190,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(radius: 16, child: Text('$day')),
                  const SizedBox(width: 8),
                  Text('${hit.y.round()} visitors', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              // A chart inside a tooltip inside a chart.
              SizedBox(
                height: 36,
                child: Chart(children: <Widget>[LineSeries(data: history, width: 1)]),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text('Opened day $day'))),
                  child: const Text('Open'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

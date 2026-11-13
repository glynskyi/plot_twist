import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';
import '../shared/ui.dart';

/// A9 — Charts that share gestures politely, and a custom interaction.
///
/// The page scrolls vertically straight through the charts, by drag or by
/// wheel; horizontal drags pan them and Ctrl/⌘ + wheel zooms. The charts in the
/// PageView pan until they reach their limit, then the page turns. Long-press
/// and drag on the first chart to measure — a behavior written right here with
/// the public API.
class CoexistenceDemo extends StatelessWidget {
  const CoexistenceDemo({super.key});

  static final Map<int, ChartData> _walks = <int, ChartData>{};

  static Widget _chart(int seed, List<Widget> behaviors) => Chart(
    x: const .linear(range: .fixed(0, 120), limits: ChartLimits(min: 0, max: 400)),
    y: const .linear(range: .fitVisible()),
    left: const <Widget>[ChartAxis(extent: .fixed(40))],
    bottom: const <Widget>[ChartAxis()],
    children: <Widget>[
      const ChartGrid(),
      LineSeries(data: _walks[seed] ??= randomWalk(401, seed: seed, volatility: 2)),
      ...behaviors,
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        const ListTile(
          title: Text(
            'Long-press and drag to measure. Drag sideways to pan, Ctrl/⌘ + wheel to zoom.',
          ),
        ),
        SizedBox(
          height: 200,
          child: _chart(1, const <Widget>[
            ChartPanZoom(wheelRequiresModifier: true),
            MeasureTool(),
          ]),
        ),
        const ListTile(title: Text('A PageView of charts: pan to the end, then the page turns.')),
        SizedBox(
          height: 200,
          child: PageView(
            children: <Widget>[
              for (final int seed in const <int>[2, 3, 4])
                _chart(seed, const <Widget>[
                  ChartPanZoom(yieldAtLimits: true, wheelRequiresModifier: true),
                ]),
            ],
          ),
        ),
        for (int i = 1; i <= 12; i++) ListTile(title: Text('More page content $i')),
      ],
    );
  }
}

typedef _Point = ({double x, double y});

/// A project-specific behavior: nothing here is private to the package.
class MeasureTool extends StatefulWidget {
  const MeasureTool({super.key});

  @override
  State<MeasureTool> createState() => _MeasureToolState();
}

class _MeasureToolState extends State<MeasureTool> {
  _Point? from;
  _Point? to;

  _Point _value(Offset chartPosition) {
    final ChartView view = ChartScope.of(context).controller.view!;
    return view.toValue(view.chartToPlot(chartPosition));
  }

  @override
  Widget build(BuildContext context) {
    final _Point? a = from;
    final _Point? b = to;
    return ChartGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              LongPressGestureRecognizer.new,
              (LongPressGestureRecognizer r) => r
                ..onLongPressStart = (LongPressStartDetails d) {
                  setState(() => from = to = _value(d.localPosition));
                }
                ..onLongPressMoveUpdate = (LongPressMoveUpdateDetails d) {
                  setState(() => to = _value(d.localPosition));
                }
                ..onLongPressEnd = (LongPressEndDetails d) {
                  setState(() => from = to = null);
                },
            ),
      },
      child: a == null || b == null
          ? null
          : ChartStack(
              children: <Widget>[
                ChartPositioned.span(
                  x1: .value(math.min(a.x, b.x)),
                  x2: .value(math.max(a.x, b.x)),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                ChartPositioned(
                  x: .value(b.x),
                  y: .value(b.y),
                  alignment: .bottomCenter,
                  offset: const Offset(0, -28),
                  fit: .clamp,
                  child: Pill(
                    'Δx ${(b.x - a.x).toStringAsFixed(0)}    Δy ${(b.y - a.y).toStringAsFixed(1)}',
                  ),
                ),
              ],
            ),
    );
  }
}

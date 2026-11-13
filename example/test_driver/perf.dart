import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';
import 'package:plot_twist_example/demos/a10_million_points.dart';
import 'package:plot_twist_example/demos/a15_live.dart';
import 'package:plot_twist_example/demos/a26_candlesticks.dart';

/// App side of the performance run in `perf_test.dart`. The driver sends a
/// command; the app shows a demo or drives it with synthetic wheel and touch
/// input in real time, and answers when it is done.
final ValueNotifier<Widget> demo = ValueNotifier<Widget>(const SizedBox.expand());
final GlobalKey area = GlobalKey();
final Stopwatch clock = Stopwatch()..start();
int nextPointer = 1;
bool mouseAdded = false;

void main() {
  enableFlutterDriverExtension(handler: _handle);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ValueListenableBuilder<Widget>(
            valueListenable: demo,
            builder: (BuildContext context, Widget child, Widget? _) =>
                KeyedSubtree(key: area, child: child),
          ),
        ),
      ),
    ),
  );
}

Future<String> _handle(String? command) async {
  switch (command) {
    case 'a10':
      demo.value = const MillionPointsDemo();
      await _wait(2000);
      _addMouse();
    case 'a15':
      demo.value = const LiveDemo();
      await _wait(2000);
    case 'a26':
      demo.value = const CandlesticksDemo();
      await _wait(2000);
      _addMouse();
    case 'candles':
      demo.value = const ManyCandles();
      await _wait(2000);
      _addMouse();
    case 'zoom':
      // Small wheel steps in, then out: every step reduces the rows again.
      for (int i = 0; i < 60; i++) {
        await _wheel(-40);
      }
      for (int i = 0; i < 60; i++) {
        await _wheel(40);
      }
    case 'zoom-out':
      // Out until every candle of A26 is in view, then back in.
      for (int i = 0; i < 40; i++) {
        await _wheel(40);
      }
      for (int i = 0; i < 40; i++) {
        await _wheel(-40);
      }
    case 'zoom-in':
      for (int i = 0; i < 5; i++) {
        await _wheel(-110);
      }
    case 'pan':
      for (int i = 0; i < 4; i++) {
        await _drag(const Offset(-500, 0));
        await _drag(const Offset(500, 0));
      }
    case 'wait':
      await _wait(6000);
  }
  await _wait(500);
  return 'ok';
}

// The mouse that turns the wheel; a device may be added only once.
void _addMouse() {
  if (!mouseAdded) _send(PointerAddedEvent(device: 1, position: _centre()));
  mouseAdded = true;
}

/// 100,000 candles in one chart: more than the A26 demo holds, to measure the
/// candlestick series at the size of a long intraday history.
class ManyCandles extends StatefulWidget {
  const ManyCandles({super.key});

  @override
  State<ManyCandles> createState() => _ManyCandlesState();
}

class _ManyCandlesState extends State<ManyCandles> {
  late final ChartData candles = _walk(100000);

  static ChartData _walk(int count) {
    final math.Random random = math.Random(5);
    final List<List<double>> columns = List<List<double>>.generate(
      4,
      (_) => List<double>.filled(count, 0),
    );
    double price = 100;
    for (int i = 0; i < count; i++) {
      final double open = price;
      price += (random.nextDouble() - 0.5) * 2;
      columns[0][i] = open;
      columns[1][i] = math.max(open, price) + random.nextDouble();
      columns[2][i] = math.min(open, price) - random.nextDouble();
      columns[3][i] = price;
    }
    return ChartData(valueColumns: 4, capacity: count)
      ..addRows(List<double>.generate(count, (int i) => i.toDouble()), columns);
  }

  @override
  void dispose() {
    candles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Chart(
    x: const .linear(limits: .data()),
    y: const .linear(range: .fitVisible()),
    left: const <Widget>[ChartAxis()],
    bottom: const <Widget>[ChartAxis()],
    children: <Widget>[
      const ChartGrid(),
      CandlestickSeries(data: candles),
      const ChartPanZoom(),
    ],
  );
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

Duration _now() => clock.elapsed;

void _send(PointerEvent event) => GestureBinding.instance.handlePointerEvent(event);

Offset _centre() {
  final RenderBox box = area.currentContext!.findRenderObject()! as RenderBox;
  return box.localToGlobal(box.size.center(Offset.zero));
}

Future<void> _wheel(double dy) async {
  _send(
    PointerScrollEvent(
      device: 1,
      timeStamp: _now(),
      position: _centre(),
      scrollDelta: Offset(0, dy),
    ),
  );
  await _wait(16);
}

// A finger moving by [delta] over 0.8 s, then lifted (which may fling).
Future<void> _drag(Offset delta) async {
  final int pointer = nextPointer++;
  const PointerDeviceKind touch = PointerDeviceKind.touch;
  final Offset start = _centre();
  Offset at = start;
  _send(
    PointerDownEvent(pointer: pointer, kind: touch, device: 2, position: at, timeStamp: _now()),
  );
  const int steps = 50;
  for (int i = 1; i <= steps; i++) {
    await _wait(16);
    final Offset next = start + delta * (i / steps);
    _send(
      PointerMoveEvent(
        pointer: pointer,
        kind: touch,
        device: 2,
        position: next,
        delta: next - at,
        timeStamp: _now(),
      ),
    );
    at = next;
  }
  _send(PointerUpEvent(pointer: pointer, kind: touch, device: 2, position: at, timeStamp: _now()));
  await _wait(600);
}

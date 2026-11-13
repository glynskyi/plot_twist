import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';
import '../shared/ui.dart';

/// A25 — Export. A chart is ordinary Flutter rendering, so a `RepaintBoundary`
/// captures it at any resolution — including the widgets placed inside it.
class ExportDemo extends StatefulWidget {
  const ExportDemo({super.key});

  @override
  State<ExportDemo> createState() => _ExportDemoState();
}

class _ExportDemoState extends State<ExportDemo> {
  final GlobalKey boundary = GlobalKey();
  final ChartData data = wave(120, amplitude: 14, period: 45, base: 30);
  late final int peak = List<int>.generate(
    120,
    (int i) => i,
  ).reduce((int a, int b) => data.y(a) >= data.y(b) ? a : b);

  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final RenderRepaintBoundary render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await render.toImage(pixelRatio: 3);
    final ByteData bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('PNG, ${image.width} × ${image.height} px, ${bytes.lengthInBytes ~/ 1024} kB'),
        content: Image.memory(bytes.buffer.asUint8List(), width: 520),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton.icon(
          onPressed: _export,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Export at 3×'),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: scheme.surface,
              child: Chart(
                y: const .linear(range: .fit(padding: 0.25)),
                left: const <Widget>[ChartAxis()],
                bottom: const <Widget>[ChartAxis()],
                children: <Widget>[
                  const ChartGrid(),
                  LineSeries(data: data, fillColor: scheme.primary.withValues(alpha: 0.1)),
                  // Widgets in the chart are part of the picture.
                  ChartPositioned(
                    x: .value(data.x(peak)),
                    y: .value(data.y(peak)),
                    alignment: .bottomCenter,
                    offset: const Offset(0, -6),
                    child: Pill('Peak ${data.y(peak).toStringAsFixed(1)}'),
                  ),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(padding: EdgeInsets.all(8), child: FlutterLogo(size: 28)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a chart in a fixed 400x300 box at the top-left of the test surface.
Widget host(Widget chart, {Size size = const Size(400, 300)}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: size.width, height: size.height, child: chart),
  ),
);

const Key _shot = Key('shot');

/// Renders [chart] on white in the 400x300 host and returns a function that
/// reads the ARGB value of a pixel.
Future<int Function(int x, int y)> renderPixels(WidgetTester tester, Widget chart) async {
  await tester.pumpWidget(
    host(
      RepaintBoundary(
        key: _shot,
        child: ColoredBox(color: const Color(0xFFFFFFFF), child: chart),
      ),
    ),
  );
  return capturePixels(tester);
}

/// Reads the pixels of what [renderPixels] pumped, as it is drawn now.
Future<int Function(int x, int y)> capturePixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester.renderObject(find.byKey(_shot));
  late Uint8List bytes;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    bytes = (await image.toByteData())!.buffer.asUint8List();
    image.dispose();
  });
  return (int x, int y) {
    final int i = (y * 400 + x) * 4;
    return bytes[i + 3] << 24 | bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2];
  };
}

/// Centre of the widget keyed `Key('marker')`.
Offset markerCenter(WidgetTester tester) => tester.getCenter(find.byKey(const Key('marker')));

/// A mutable counter.
class Counter {
  int value = 0;
}

/// A 6x6 box that counts how often it is built and laid out.
class CountingBox extends StatelessWidget {
  const CountingBox({super.key, required this.builds, required this.layouts});

  final Counter builds;
  final Counter layouts;

  @override
  Widget build(BuildContext context) {
    builds.value++;
    return _CountingLayout(layouts: layouts);
  }
}

class _CountingLayout extends LeafRenderObjectWidget {
  const _CountingLayout({required this.layouts});

  final Counter layouts;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCounting(layouts);
}

class _RenderCounting extends RenderBox {
  _RenderCounting(this.layouts);

  final Counter layouts;

  @override
  void performLayout() {
    layouts.value++;
    size = constraints.constrain(const Size(6, 6));
  }
}

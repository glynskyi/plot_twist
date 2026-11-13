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

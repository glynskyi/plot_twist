import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import 'open_url.dart';

/// Maps the Material theme onto the charts below. plot_twist itself has no
/// Material dependency; this is all the glue an app needs.
class MaterialChartTheme extends StatelessWidget {
  const MaterialChartTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ChartTheme(
      data:
          ChartThemeData.fallback(
            foreground: theme.colorScheme.onSurface,
            textStyle: theme.textTheme.bodySmall,
            brightness: theme.brightness,
          ).copyWith(
            tooltipColor: theme.colorScheme.inverseSurface,
            tooltipTextStyle: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onInverseSurface,
            ),
          ),
      child: child,
    );
  }
}

/// A small rounded label.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.foreground});

  final String text;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          text,
          style: TextStyle(fontSize: 11, height: 1.2, color: foreground ?? scheme.onPrimary),
        ),
      ),
    );
  }
}

/// One entry of the gallery.
class Demo {
  const Demo(this.id, this.title, this.summary, this.file, this.builder);

  /// The aspect number, such as "A3".
  final String id;
  final String title;

  /// What the demo proves.
  final String summary;

  /// File name under `lib/demos/`.
  final String file;
  final WidgetBuilder builder;

  /// The gallery's address for this demo; on the web, `#/a10` opens A10.
  String get route => '/${id.toLowerCase()}';

  /// Where the demo's source can be read on GitHub.
  String get sourceUrl =>
      'https://github.com/glynskyi/plot_twist/blob/main/example/lib/demos/$file';
}

/// The frame every demo is shown in: what it proves, the demo, and its source.
class DemoPage extends StatelessWidget {
  const DemoPage({super.key, required this.demo, this.showAppBar = true});

  final Demo demo;
  final bool showAppBar;

  Future<void> _showSource(BuildContext context) async {
    final String source = await rootBundle.loadString('lib/demos/${demo.file}');
    final int lines = source
        .split('\n')
        .where((String l) => l.trim().isNotEmpty && !l.trim().startsWith('//'))
        .length;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('${demo.file} — $lines lines of code'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: SelectableText(
              source,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.35),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _openOnGitHub(BuildContext context) async {
    final bool opened = await openUrl(demo.sourceUrl);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Copied the link to ${demo.file} on GitHub')));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(demo.summary, style: theme.textTheme.bodyMedium)),
              TextButton.icon(
                onPressed: () => _showSource(context),
                icon: const Icon(Icons.code, size: 18),
                label: const Text('Source'),
              ),
              TextButton.icon(
                onPressed: () => _openOnGitHub(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('GitHub'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: MaterialChartTheme(
              child: KeyedSubtree(key: ValueKey<String>(demo.id), child: demo.builder(context)),
            ),
          ),
        ],
      ),
    );
    if (!showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: Text('${demo.id} · ${demo.title}')),
      body: body,
    );
  }
}

/// A soft, moving placeholder for content that is still loading.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-3 + 4 * _animation.value, 0),
            end: Alignment(-1 + 4 * _animation.value, 0),
            colors: <Color>[
              base.withValues(alpha: 0.05),
              base.withValues(alpha: 0.14),
              base.withValues(alpha: 0.05),
            ],
          ),
        ),
      ),
    );
  }
}

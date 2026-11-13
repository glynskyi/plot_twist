import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Colours and text styles used by the built-in chart widgets.
@immutable
class ChartThemeData {
  /// Creates a chart theme.
  const ChartThemeData({
    required this.foreground,
    required this.gridColor,
    required this.axisColor,
    required this.labelStyle,
    required this.palette,
    required this.crosshairColor,
    required this.tooltipColor,
    required this.tooltipTextStyle,
  });

  /// A theme derived from a text colour, for either brightness.
  factory ChartThemeData.fallback({
    Color? foreground,
    TextStyle? textStyle,
    Brightness brightness = Brightness.light,
  }) {
    final Color fg =
        foreground ??
        (brightness == Brightness.dark ? const Color(0xFFE6E6E6) : const Color(0xFF1F1F1F));
    final bool dark = brightness == Brightness.dark;
    return ChartThemeData(
      foreground: fg,
      gridColor: fg.withValues(alpha: 0.10),
      axisColor: fg.withValues(alpha: 0.35),
      labelStyle: (textStyle ?? const TextStyle()).copyWith(
        fontSize: 11,
        height: 1.2,
        color: fg.withValues(alpha: 0.72),
      ),
      palette: defaultPalette,
      crosshairColor: fg.withValues(alpha: 0.45),
      tooltipColor: dark ? const Color(0xFFF2F2F2) : const Color(0xFF2B2B2B),
      tooltipTextStyle: (textStyle ?? const TextStyle()).copyWith(
        fontSize: 12,
        height: 1.3,
        color: dark ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF),
      ),
    );
  }

  /// A colour-blind-friendly categorical palette.
  static const List<Color> defaultPalette = <Color>[
    Color(0xFF4E79A7),
    Color(0xFFF28E2B),
    Color(0xFFE15759),
    Color(0xFF76B7B2),
    Color(0xFF59A14F),
    Color(0xFFEDC948),
    Color(0xFFB07AA1),
    Color(0xFFFF9DA7),
  ];

  /// The base content colour.
  final Color foreground;

  /// Colour of grid lines.
  final Color gridColor;

  /// Colour of axis lines and tick marks.
  final Color axisColor;

  /// Text style of axis labels.
  final TextStyle labelStyle;

  /// Colours for series that do not specify one.
  final List<Color> palette;

  /// Colour of crosshair lines.
  final Color crosshairColor;

  /// Background of the default tooltip.
  final Color tooltipColor;

  /// Text style of the default tooltip.
  final TextStyle tooltipTextStyle;

  /// The palette colour for the series at [index], wrapping around.
  Color seriesColor(int index) => palette[index % palette.length];

  /// A copy with some fields replaced.
  ChartThemeData copyWith({
    Color? foreground,
    Color? gridColor,
    Color? axisColor,
    TextStyle? labelStyle,
    List<Color>? palette,
    Color? crosshairColor,
    Color? tooltipColor,
    TextStyle? tooltipTextStyle,
  }) => ChartThemeData(
    foreground: foreground ?? this.foreground,
    gridColor: gridColor ?? this.gridColor,
    axisColor: axisColor ?? this.axisColor,
    labelStyle: labelStyle ?? this.labelStyle,
    palette: palette ?? this.palette,
    crosshairColor: crosshairColor ?? this.crosshairColor,
    tooltipColor: tooltipColor ?? this.tooltipColor,
    tooltipTextStyle: tooltipTextStyle ?? this.tooltipTextStyle,
  );

  @override
  bool operator ==(Object other) =>
      other is ChartThemeData &&
      other.foreground == foreground &&
      other.gridColor == gridColor &&
      other.axisColor == axisColor &&
      other.labelStyle == labelStyle &&
      listEquals(other.palette, palette) &&
      other.crosshairColor == crosshairColor &&
      other.tooltipColor == tooltipColor &&
      other.tooltipTextStyle == tooltipTextStyle;

  @override
  int get hashCode => Object.hash(
    foreground,
    gridColor,
    axisColor,
    labelStyle,
    Object.hashAll(palette),
    crosshairColor,
    tooltipColor,
    tooltipTextStyle,
  );
}

/// Applies a [ChartThemeData] to the charts below it.
///
/// Without a `ChartTheme`, charts derive their colours from the ambient
/// `DefaultTextStyle`, so they follow light and dark app themes by default.
class ChartTheme extends InheritedWidget {
  /// Creates a chart theme.
  const ChartTheme({super.key, required this.data, required super.child});

  /// The theme for the subtree.
  final ChartThemeData data;

  /// The theme for [context].
  static ChartThemeData of(BuildContext context) {
    final ChartTheme? theme = context.dependOnInheritedWidgetOfExactType<ChartTheme>();
    if (theme != null) return theme.data;
    final TextStyle style = DefaultTextStyle.of(context).style;
    final Brightness brightness = MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    return ChartThemeData.fallback(
      foreground: style.color,
      textStyle: style,
      brightness: style.color == null
          ? brightness
          : (style.color!.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light),
    );
  }

  @override
  bool updateShouldNotify(ChartTheme oldWidget) => oldWidget.data != data;
}

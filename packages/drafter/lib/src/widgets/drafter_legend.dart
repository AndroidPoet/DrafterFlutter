/*
 * Designed and developed by 2024 androidpoet (Ranbir Singh)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:drafter/src/theme/drafter_theme.dart';
import 'package:flutter/widgets.dart';

/// A single entry in a [DrafterLegend]: a color swatch paired with a [label].
@immutable
class LegendItem {
  /// Creates a legend entry showing [label] in [color].
  const LegendItem({required this.label, required this.color});

  /// The series / category name shown next to the swatch.
  final String label;

  /// The swatch color — match the color the series is drawn with.
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is LegendItem && other.label == label && other.color == color;

  @override
  int get hashCode => Object.hash(label, color);
}

/// The flow direction of a [DrafterLegend]'s entries.
enum DrafterLegendDirection {
  /// Entries flow left-to-right and wrap onto new lines when they run out of
  /// width.
  horizontal,

  /// Entries stack top-to-bottom in a single column.
  vertical,
}

/// The shape of a [DrafterLegend] color swatch.
enum LegendMarker {
  /// A small rounded square — the default, neutral marker.
  square,

  /// A filled circle — pairs well with scatter / bubble / pie charts.
  circle,

  /// A short rounded bar — pairs well with line / area charts.
  line,
}

/// A presentational legend that maps series colors to labels, themed to match
/// the charts via [DrafterTheme].
///
/// It holds no selection state of its own; wire [onItemTap] to toggle series
/// visibility in your own state if you need it. Place it anywhere relative to a
/// chart (above, below, or beside) — it lays out with [Wrap] (horizontal) or a
/// [Column] (vertical) and sizes itself to its content.
///
/// ```dart
/// DrafterLegend.fromLabels(const ['Revenue', 'Cost', 'Profit'])
/// ```
class DrafterLegend extends StatelessWidget {
  /// Creates a legend from explicit [items], each carrying its own color.
  const DrafterLegend({
    required this.items,
    super.key,
    this.direction = DrafterLegendDirection.horizontal,
    this.marker = LegendMarker.square,
    this.markerSize = 12,
    this.spacing = 16,
    this.runSpacing = 8,
    this.gap = 6,
    this.textStyle,
    this.onItemTap,
  }) : _labels = null,
       _colors = null;

  /// Creates a legend from a list of [labels], coloring each by index.
  ///
  /// When [colors] is omitted the active [DrafterTheme]'s palette is used
  /// (cycling for more labels than colors), so the legend matches how charts
  /// color their series by default.
  const DrafterLegend.fromLabels(
    List<String> labels, {
    super.key,
    List<Color>? colors,
    this.direction = DrafterLegendDirection.horizontal,
    this.marker = LegendMarker.square,
    this.markerSize = 12,
    this.spacing = 16,
    this.runSpacing = 8,
    this.gap = 6,
    this.textStyle,
    this.onItemTap,
  }) : _labels = labels,
       _colors = colors,
       items = const [];

  /// The explicit legend entries (empty when built via [DrafterLegend.fromLabels]).
  final List<LegendItem> items;

  /// Whether entries flow horizontally (wrapping) or stack vertically.
  final DrafterLegendDirection direction;

  /// The swatch shape drawn before each label.
  final LegendMarker marker;

  /// The swatch's nominal size in logical pixels.
  final double markerSize;

  /// Horizontal space between entries (and between wrapped runs' columns).
  final double spacing;

  /// Vertical space between wrapped runs (horizontal) or between entries
  /// (vertical).
  final double runSpacing;

  /// The gap between a swatch and its label.
  final double gap;

  /// The label text style. Defaults to the theme's label color at 12px.
  final TextStyle? textStyle;

  /// Called with the entry index when an entry is tapped. When null, entries are
  /// not interactive.
  final ValueChanged<int>? onItemTap;

  final List<String>? _labels;
  final List<Color>? _colors;

  List<LegendItem> _resolve(DrafterThemeColors theme) {
    final labels = _labels;
    if (labels == null) return items;
    final colors = _colors;
    return <LegendItem>[
      for (var i = 0; i < labels.length; i++)
        LegendItem(
          label: labels[i],
          color: colors == null || colors.isEmpty
              ? theme.colorAt(i)
              : colors[i % colors.length],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = DrafterTheme.of(context);
    final entries = _resolve(theme);
    final style = textStyle ?? TextStyle(color: theme.label, fontSize: 12);

    final children = <Widget>[
      for (var i = 0; i < entries.length; i++)
        _LegendEntry(
          item: entries[i],
          index: i,
          marker: marker,
          markerSize: markerSize,
          gap: gap,
          style: style,
          onTap: onItemTap,
        ),
    ];

    if (direction == DrafterLegendDirection.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: runSpacing),
            children[i],
          ],
        ],
      );
    }

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.item,
    required this.index,
    required this.marker,
    required this.markerSize,
    required this.gap,
    required this.style,
    required this.onTap,
  });

  final LegendItem item;
  final int index;
  final LegendMarker marker;
  final double markerSize;
  final double gap;
  final TextStyle style;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _LegendSwatch(color: item.color, size: markerSize, marker: marker),
        SizedBox(width: gap),
        Text(item.label, style: style),
      ],
    );
    final tap = onTap;
    if (tap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => tap(index),
      child: row,
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({
    required this.color,
    required this.size,
    required this.marker,
  });

  final Color color;
  final double size;
  final LegendMarker marker;

  @override
  Widget build(BuildContext context) {
    switch (marker) {
      case LegendMarker.circle:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      case LegendMarker.line:
        return Container(
          width: size * 1.6,
          height: (size * 0.32).clamp(2.0, size),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.all(Radius.circular(size)),
          ),
        );
      case LegendMarker.square:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.all(Radius.circular(size * 0.25)),
          ),
        );
    }
  }
}

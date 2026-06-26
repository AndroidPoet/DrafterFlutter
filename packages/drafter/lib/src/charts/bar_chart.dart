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
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drafter/src/core/chart_data.dart';
import 'package:drafter/src/core/chart_formatting.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Shared layout
// ---------------------------------------------------------------------------

/// The plot geometry shared by every bar variant, mirroring the Compose
/// `calculateChartDimensions`: 15% horizontal padding, 70% tall plot box.
class _BarLayout {
  _BarLayout(Size size)
    : chartHeight = size.height * 0.7,
      chartTop = size.height * 0.15,
      chartBottom = size.height * 0.15 + size.height * 0.7,
      chartLeft = size.width * 0.15,
      chartWidth = size.width - size.width * 0.15 * 2;

  final double chartLeft;
  final double chartTop;
  final double chartBottom;
  final double chartWidth;
  final double chartHeight;
}

/// The per-variant bar layout + drawing strategy. Mirrors the Kotlin
/// `BarChartDataRenderer` interface so each variant supplies labels, scaling,
/// and a `drawGroup` for its own grouped/stacked/waterfall logic.
abstract class _BarVariant {
  List<String> get labels;
  int get barsPerGroup;
  double maxValue();

  /// Returns (barWidth, groupSpacing) clamped to be non-negative.
  (double, double) barAndSpacing({
    required double chartWidth,
    required int dataSize,
    required int barsPerGroup,
  });

  /// The on-screen width of a single group (bars + their internal spacing).
  double groupWidth({required double barWidth, required int barsPerGroup});

  void drawGroup(
    Canvas canvas, {
    required int index,
    required double left,
    required double barWidth,
    required double groupSpacing,
    required double chartBottom,
    required double chartHeight,
    required double maxValue,
    required double progress,
  });
}

/// Draws a rounded-top bar with a soft top-to-bottom gradient (the premium
/// look from the Compose simple-bar renderer), used by every variant for
/// visual consistency.
void _drawBar(
  Canvas canvas, {
  required Rect rect,
  required Color color,
  required double cornerRadius,
}) {
  if (rect.height <= 0 || rect.width <= 0) return;
  final r = math.min(cornerRadius, rect.width / 2);
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
  final paint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      [color, color.withValues(alpha: 0.72)],
    );
  canvas.drawRRect(rrect, paint);
}

/// The shared scaffold that draws the Y grid (5 ticks) + Y labels, walks the
/// groups, and centers X labels under each group. The variant supplies all
/// data-specific geometry.
void _drawBarChart(
  _BarVariant variant,
  Canvas canvas,
  Size size,
  DrafterThemeColors theme,
  double progress,
) {
  if (size.width < 1 || size.height < 1) return;
  final labels = variant.labels;
  if (labels.isEmpty) return;

  final layout = _BarLayout(size);
  final barsPerGroup = variant.barsPerGroup;
  final maxValue = math.max(variant.maxValue(), 1e-6);

  // Baseline axis.
  canvas.drawLine(
    Offset(layout.chartLeft, layout.chartBottom),
    Offset(layout.chartLeft + layout.chartWidth, layout.chartBottom),
    Paint()
      ..color = theme.grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );

  // Y grid + labels (5 steps).
  const steps = 5;
  final gridPaint = Paint()
    ..color = theme.grid
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  for (var i = 0; i <= steps; i++) {
    final value = maxValue / steps * i;
    final y = layout.chartBottom - (value / maxValue) * layout.chartHeight;
    canvas.drawLine(
      Offset(layout.chartLeft, y),
      Offset(size.width, y),
      gridPaint,
    );

    final rounded = (value * 10).toInt() / 10;
    drawChartText(
      canvas,
      _floatDescription(rounded),
      Offset(layout.chartLeft - 6, y),
      color: theme.label,
      h: HAlign.end,
      v: VAlign.center,
    );
  }

  // Bar/spacing geometry.
  final (barWidth, groupSpacing) = variant.barAndSpacing(
    chartWidth: layout.chartWidth,
    dataSize: labels.length,
    barsPerGroup: barsPerGroup,
  );
  final groupWidth = variant.groupWidth(
    barWidth: barWidth,
    barsPerGroup: barsPerGroup,
  );

  // Bars, group by group, growing from the baseline with the reveal.
  var currentLeft = layout.chartLeft;
  for (var index = 0; index < labels.length; index++) {
    variant.drawGroup(
      canvas,
      index: index,
      left: currentLeft,
      barWidth: barWidth,
      groupSpacing: groupSpacing,
      chartBottom: layout.chartBottom,
      chartHeight: layout.chartHeight,
      maxValue: maxValue,
      progress: progress,
    );
    currentLeft += groupWidth + groupSpacing;
  }

  // X labels, centered under each group. At small sizes, thin out dense labels
  // and truncate long ones so they don't overlap or clip past the canvas.
  currentLeft = layout.chartLeft;
  // Budget ~36pt per label; show every Nth label if they'd collide.
  final slot = groupWidth + groupSpacing;
  final stride = slot > 0 ? math.max(1, (36 / slot).ceil()) : 1;
  for (var i = 0; i < labels.length; i++) {
    final label = labels[i];
    final centerX = currentLeft + groupWidth / 2;
    currentLeft += slot;
    if (i % stride != 0) continue;
    final shown = label.length > 8 ? '${label.substring(0, 7)}…' : label;
    drawChartText(
      canvas,
      shown,
      Offset(centerX, layout.chartBottom + 6),
      color: theme.label,
      h: HAlign.center,
    );
  }
}

/// Renders a number the way Swift's `Float.description` does for the Y-axis
/// labels: integer-valued floats keep a trailing `.0` (e.g. `3` -> `"3.0"`).
String _floatDescription(double value) {
  if (value == value.roundToDouble()) return '${value.toInt()}.0';
  return ChartFormatting.format(value);
}

// ---------------------------------------------------------------------------
// Simple
// ---------------------------------------------------------------------------

/// Draws `[BarItem]` as single rounded, gradient-filled bars. Each bar binds its
/// own label, value, and optional color (palette fallback by position).
class SimpleBarChartRenderer extends ChartRenderer {
  const SimpleBarChartRenderer({required this.bars});

  final List<BarItem> bars;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    _drawBarChart(
      _SimpleVariant(bars: bars, theme: theme),
      canvas,
      size,
      theme,
      progress,
    );
  }

  @override
  String get accessibilityLabel => 'Bar chart';

  @override
  String get accessibilityValue => bars.isEmpty
      ? 'No data'
      : '${bars.length} bars, '
            '${AccessibilityFormat.points([for (final b in bars) (b.label, b.value)])}';
}

class _SimpleVariant extends _BarVariant {
  _SimpleVariant({required this.bars, required this.theme});

  final List<BarItem> bars;
  final DrafterThemeColors theme;

  @override
  List<String> get labels => [for (final b in bars) b.label];

  @override
  int get barsPerGroup => 1;

  @override
  double maxValue() =>
      bars.isEmpty ? 0 : bars.map((b) => b.value).reduce(math.max);

  @override
  (double, double) barAndSpacing({
    required double chartWidth,
    required int dataSize,
    required int barsPerGroup,
  }) {
    if (dataSize <= 0) return (0, 0);
    final totalSpacing = chartWidth * 0.1;
    final groupSpacing = totalSpacing / (dataSize + 1);
    final availableWidth = chartWidth - totalSpacing;
    final barWidth = availableWidth / dataSize;
    return (math.max(barWidth, 0), math.max(groupSpacing, 0));
  }

  @override
  double groupWidth({required double barWidth, required int barsPerGroup}) =>
      barWidth;

  @override
  void drawGroup(
    Canvas canvas, {
    required int index,
    required double left,
    required double barWidth,
    required double groupSpacing,
    required double chartBottom,
    required double chartHeight,
    required double maxValue,
    required double progress,
  }) {
    if (index >= bars.length) return;
    final bar = bars[index];
    final barHeight = (bar.value / maxValue) * chartHeight * progress;
    if (barHeight <= 0) return;
    final color = bar.color ?? theme.colorAt(index);
    // Slim the bar for breathing room and round the top corners.
    final inset = barWidth * 0.16;
    final drawWidth = barWidth - inset * 2;
    final rect = Rect.fromLTWH(
      left + inset,
      chartBottom - barHeight,
      drawWidth,
      barHeight,
    );
    _drawBar(canvas, rect: rect, color: color, cornerRadius: drawWidth * 0.4);
  }
}

/// A simple bar chart: one rounded, gradient-filled bar per `BarItem`.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.bars,
    this.animate = true,
    this.replay = 0,
  });

  /// Convenience for unlabeled data: one value per bar, palette-colored.
  SimpleBarChart.values({
    super.key,
    required List<double> values,
    this.animate = true,
    this.replay = 0,
  }) : bars = [for (final v in values) BarItem.value(v)];

  final List<BarItem> bars;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: SimpleBarChartRenderer(bars: bars),
    animate: animate,
    replay: replay,
  );
}

// ---------------------------------------------------------------------------
// Grouped
// ---------------------------------------------------------------------------

/// Draws side-by-side bars per category from `[ChartSeries]`. Each series is one
/// colored item; `series[s].values[i]` is that item's bar in category `i`.
/// `categories` supplies the x-axis labels.
class GroupedBarChartRenderer extends ChartRenderer {
  const GroupedBarChartRenderer({
    required this.series,
    this.categories = const [],
  });

  final List<ChartSeries> series;
  final List<String> categories;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    _drawBarChart(
      _GroupedVariant(series: series, categories: categories, theme: theme),
      canvas,
      size,
      theme,
      progress,
    );
  }

  @override
  String get accessibilityLabel => 'Grouped bar chart';

  @override
  String get accessibilityValue => series.isEmpty
      ? 'No data'
      : '${series.length} series: ${series.map((s) => '${s.name.isEmpty ? 'series' : s.name} ${AccessibilityFormat.range(s.values)}').join('; ')}';
}

class _GroupedVariant extends _BarVariant {
  _GroupedVariant({
    required this.series,
    required this.categories,
    required this.theme,
  });

  final List<ChartSeries> series;
  final List<String> categories;
  final DrafterThemeColors theme;

  static const double _innerSpacing = 4;

  int get _groupCount =>
      series.isEmpty ? 0 : series.map((s) => s.values.length).reduce(math.max);

  @override
  List<String> get labels => normalizedLabels(categories, _groupCount);

  @override
  int get barsPerGroup => math.max(series.length, 1);

  @override
  double maxValue() {
    final all = [for (final s in series) ...s.values];
    return all.isEmpty ? 0 : all.reduce(math.max);
  }

  @override
  (double, double) barAndSpacing({
    required double chartWidth,
    required int dataSize,
    required int barsPerGroup,
  }) {
    if (dataSize <= 0 || barsPerGroup <= 0) return (0, 0);
    final totalGroupSpacing = chartWidth * 0.1;
    final groupSpacing = totalGroupSpacing / (dataSize + 1);
    final availableWidth = chartWidth - totalGroupSpacing;
    final totalBarSpacingPerGroup = (barsPerGroup - 1) * _innerSpacing;
    final barWidth =
        (availableWidth / dataSize - totalBarSpacingPerGroup) / barsPerGroup;
    return (math.max(barWidth, 0), math.max(groupSpacing, 0));
  }

  @override
  double groupWidth({required double barWidth, required int barsPerGroup}) =>
      barWidth * barsPerGroup + (barsPerGroup - 1) * _innerSpacing;

  @override
  void drawGroup(
    Canvas canvas, {
    required int index,
    required double left,
    required double barWidth,
    required double groupSpacing,
    required double chartBottom,
    required double chartHeight,
    required double maxValue,
    required double progress,
  }) {
    var currentLeft = left;
    for (final item in series) {
      final value = index < item.values.length ? item.values[index] : 0.0;
      final barHeight = (value / maxValue) * chartHeight * progress;
      final rect = Rect.fromLTWH(
        currentLeft,
        chartBottom - barHeight,
        barWidth,
        barHeight,
      );
      _drawBar(
        canvas,
        rect: rect,
        color: item.color,
        cornerRadius: barWidth * 0.3,
      );
      currentLeft += barWidth + _innerSpacing;
    }
  }
}

/// A grouped bar chart: side-by-side bars for each category.
class GroupedBarChart extends StatelessWidget {
  const GroupedBarChart({
    super.key,
    required this.series,
    this.categories = const [],
    this.animate = true,
    this.replay = 0,
  });

  final List<ChartSeries> series;
  final List<String> categories;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: GroupedBarChartRenderer(series: series, categories: categories),
    animate: animate,
    replay: replay,
  );
}

// ---------------------------------------------------------------------------
// Stacked
// ---------------------------------------------------------------------------

/// Draws a vertical stack of segments per category from `[ChartSeries]`. Each
/// series is one colored segment-level; `series[s].values[i]` is that level's
/// height in category `i`. `categories` supplies the x-axis labels.
class StackedBarChartRenderer extends ChartRenderer {
  const StackedBarChartRenderer({
    required this.series,
    this.categories = const [],
  });

  final List<ChartSeries> series;
  final List<String> categories;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    _drawBarChart(
      _StackedVariant(series: series, categories: categories, theme: theme),
      canvas,
      size,
      theme,
      progress,
    );
  }

  @override
  String get accessibilityLabel => 'Stacked bar chart';

  @override
  String get accessibilityValue => series.isEmpty
      ? 'No data'
      : '${series.length} series: ${series.map((s) => '${s.name.isEmpty ? 'series' : s.name} ${AccessibilityFormat.range(s.values)}').join('; ')}';
}

class _StackedVariant extends _BarVariant {
  _StackedVariant({
    required this.series,
    required this.categories,
    required this.theme,
  });

  final List<ChartSeries> series;
  final List<String> categories;
  final DrafterThemeColors theme;

  int get _groupCount =>
      series.isEmpty ? 0 : series.map((s) => s.values.length).reduce(math.max);

  @override
  List<String> get labels => normalizedLabels(categories, _groupCount);

  @override
  int get barsPerGroup => 1;

  @override
  double maxValue() {
    final totals = [
      for (var i = 0; i < _groupCount; i++)
        series.fold<double>(
          0,
          (sum, s) => sum + (i < s.values.length ? s.values[i] : 0.0),
        ),
    ];
    return totals.isEmpty ? 0 : totals.reduce(math.max);
  }

  @override
  (double, double) barAndSpacing({
    required double chartWidth,
    required int dataSize,
    required int barsPerGroup,
  }) {
    if (dataSize <= 0) return (0, 0);
    // Stacked uses a wider 20% gap budget for extra breathing room.
    final totalGapSpace = chartWidth * 0.2;
    final groupSpacing = totalGapSpace / (dataSize + 1);
    final availableWidth = chartWidth - totalGapSpace;
    final barWidth = availableWidth / dataSize;
    return (math.max(barWidth, 0), math.max(groupSpacing, 0));
  }

  @override
  double groupWidth({required double barWidth, required int barsPerGroup}) =>
      barWidth;

  @override
  void drawGroup(
    Canvas canvas, {
    required int index,
    required double left,
    required double barWidth,
    required double groupSpacing,
    required double chartBottom,
    required double chartHeight,
    required double maxValue,
    required double progress,
  }) {
    var currentBottom = chartBottom;
    for (final level in series) {
      final value = index < level.values.length ? level.values[index] : 0.0;
      final barHeight =
          (value / math.max(maxValue, 1e-6)) * chartHeight * progress;
      final rect = Rect.fromLTWH(
        left,
        currentBottom - barHeight,
        barWidth,
        barHeight,
      );
      // Square segments so stacks read as a continuous bar.
      if (barHeight > 0 && barWidth > 0) {
        canvas.drawRect(rect, Paint()..color = level.color);
      }
      currentBottom -= barHeight;
    }
  }
}

/// A stacked bar chart: each category's bar stacks its series segments vertically.
class StackedBarChart extends StatelessWidget {
  const StackedBarChart({
    super.key,
    required this.series,
    this.categories = const [],
    this.animate = true,
    this.replay = 0,
  });

  final List<ChartSeries> series;
  final List<String> categories;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: StackedBarChartRenderer(series: series, categories: categories),
    animate: animate,
    replay: replay,
  );
}

// ---------------------------------------------------------------------------
// Histogram
// ---------------------------------------------------------------------------

/// Draws a frequency distribution: bins raw `values` into `binCount` bars. A
/// single array of points — there are no parallel arrays to mismatch.
class HistogramRenderer extends ChartRenderer {
  HistogramRenderer({
    required this.values,
    required this.binCount,
    Color? color,
  }) : color = color ?? DrafterColors.blue,
       _binned = _bin(values, binCount);

  final List<double> values;
  final int binCount;
  final Color color;
  final (List<String>, List<double>) _binned;

  /// Bins raw points into `binCount` buckets, returning range labels and counts.
  static (List<String>, List<double>) _bin(List<double> points, int binCount) {
    if (binCount <= 0) return (const [], const []);
    final minVal = points.isEmpty ? 0.0 : points.reduce(math.min);
    final maxVal = points.isEmpty ? minVal : points.reduce(math.max);
    final binSize = maxVal > minVal ? (maxVal - minVal) / binCount : 1.0;
    final freqs = List<double>.filled(binCount, 0);
    for (final point in points) {
      final raw = ((point - minVal) / binSize).toInt();
      final idx = math.min(math.max(raw, 0), binCount - 1);
      freqs[idx] += 1;
    }
    final labels = [
      for (var i = 0; i < binCount; i++)
        () {
          final start = minVal + i * binSize;
          final end = start + binSize;
          return '${ChartFormatting.format(start)}-${ChartFormatting.format(end)}';
        }(),
    ];
    return (labels, freqs);
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    _drawBarChart(
      _HistogramVariant(
        labels: _binned.$1,
        frequencies: _binned.$2,
        color: color,
      ),
      canvas,
      size,
      theme,
      progress,
    );
  }

  @override
  String get accessibilityLabel => 'Histogram';

  @override
  String get accessibilityValue => values.isEmpty
      ? 'No data'
      : '${values.length} values, ${AccessibilityFormat.range(values)}';
}

class _HistogramVariant extends _BarVariant {
  _HistogramVariant({
    required this.labels,
    required this.frequencies,
    required this.color,
  });

  @override
  final List<String> labels;
  final List<double> frequencies;
  final Color color;

  @override
  int get barsPerGroup => 1;

  @override
  double maxValue() {
    final m = frequencies.isEmpty ? 0.0 : frequencies.reduce(math.max);
    return m > 0 ? m : 1;
  }

  @override
  (double, double) barAndSpacing({
    required double chartWidth,
    required int dataSize,
    required int barsPerGroup,
  }) {
    if (dataSize <= 0 || chartWidth <= 0) return (0, 0);
    final totalSpacing = chartWidth * 0.1;
    final groupSpacing = totalSpacing / (dataSize + 1);
    final availableWidth = chartWidth - totalSpacing;
    final barWidth = availableWidth / dataSize;
    return (math.max(barWidth, 0), math.max(groupSpacing, 0));
  }

  @override
  double groupWidth({required double barWidth, required int barsPerGroup}) =>
      barWidth;

  @override
  void drawGroup(
    Canvas canvas, {
    required int index,
    required double left,
    required double barWidth,
    required double groupSpacing,
    required double chartBottom,
    required double chartHeight,
    required double maxValue,
    required double progress,
  }) {
    if (index >= frequencies.length) return;
    final freq = frequencies[index];
    final barHeight = (freq / math.max(maxValue, 1)) * chartHeight * progress;
    final rect = Rect.fromLTWH(
      left,
      chartBottom - barHeight,
      barWidth,
      barHeight,
    );
    _drawBar(canvas, rect: rect, color: color, cornerRadius: barWidth * 0.2);
  }
}

/// A histogram: bins raw `values` into a frequency-distribution bar chart.
class Histogram extends StatelessWidget {
  Histogram({
    super.key,
    required this.values,
    required this.binCount,
    Color? color,
    this.animate = true,
    this.replay = 0,
  }) : color = color ?? DrafterColors.blue;

  final List<double> values;
  final int binCount;
  final Color color;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: HistogramRenderer(
      values: values,
      binCount: binCount,
      color: color,
    ),
    animate: animate,
    replay: replay,
  );
}

// ---------------------------------------------------------------------------
// Waterfall
// ---------------------------------------------------------------------------

/// One rendered column: a bar spanning `[start, end]` with a label and color.
class _WaterfallColumn {
  const _WaterfallColumn({
    required this.start,
    required this.end,
    required this.label,
    required this.color,
  });

  final double start;
  final double end;
  final String label;
  final Color? color;
}

/// Draws a waterfall from `[WaterfallStep]`: each step is a labeled incremental
/// change applied to `initialValue`. Set `startLabel` to draw a leading bar at
/// the initial value, and `totalLabel` to draw a trailing bar at the final
/// running total — the classic Start … Total waterfall. Connectors are drawn
/// horizontally at each running total.
class WaterfallChartRenderer extends ChartRenderer {
  const WaterfallChartRenderer({
    required this.steps,
    this.initialValue = 0,
    this.startLabel,
    this.totalLabel,
  });

  final List<WaterfallStep> steps;
  final double initialValue;
  final String? startLabel;
  final String? totalLabel;

  /// Builds the ordered columns: optional Start bar, one bar per step, optional
  /// Total bar. This count — not any label array — drives the chart.
  List<_WaterfallColumn> _buildColumns() {
    final result = <_WaterfallColumn>[];
    if (startLabel != null) {
      result.add(
        _WaterfallColumn(
          start: 0,
          end: initialValue,
          label: startLabel!,
          color: null,
        ),
      );
    }
    var running = initialValue;
    for (final step in steps) {
      final start = running;
      running += step.value;
      result.add(
        _WaterfallColumn(
          start: start,
          end: running,
          label: step.label,
          color: step.color,
        ),
      );
    }
    if (totalLabel != null) {
      result.add(
        _WaterfallColumn(
          start: 0,
          end: running,
          label: totalLabel!,
          color: null,
        ),
      );
    }
    return result;
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    final columns = _buildColumns();
    if (columns.isEmpty) return;
    _drawBarChart(
      _WaterfallVariant(columns: columns, theme: theme),
      canvas,
      size,
      theme,
      progress,
    );
  }

  @override
  String get accessibilityLabel => 'Waterfall chart';

  @override
  String get accessibilityValue {
    if (steps.isEmpty) return 'No data';
    final total =
        initialValue + steps.fold<double>(0, (sum, s) => sum + s.value);
    return 'starting ${AccessibilityFormat.number(initialValue)}, '
        '${AccessibilityFormat.points([for (final s in steps) (s.label, s.value)])}'
        ', total ${AccessibilityFormat.number(total)}';
  }
}

class _WaterfallVariant extends _BarVariant {
  _WaterfallVariant({required this.columns, required this.theme});

  final List<_WaterfallColumn> columns;
  final DrafterThemeColors theme;

  @override
  List<String> get labels => [for (final c in columns) c.label];

  @override
  int get barsPerGroup => 1;

  @override
  double maxValue() {
    final all = [
      for (final c in columns) ...[c.start.abs(), c.end.abs()],
    ];
    return all.isEmpty ? 0 : all.reduce(math.max);
  }

  @override
  (double, double) barAndSpacing({
    required double chartWidth,
    required int dataSize,
    required int barsPerGroup,
  }) {
    if (dataSize <= 0) return (0, 0);
    final totalSpacing = chartWidth * 0.1;
    final groupSpacing = totalSpacing / (dataSize + 1);
    final availableWidth = chartWidth - totalSpacing;
    final barWidth = availableWidth / dataSize;
    return (math.max(barWidth, 0), math.max(groupSpacing, 0));
  }

  @override
  double groupWidth({required double barWidth, required int barsPerGroup}) =>
      barWidth;

  @override
  void drawGroup(
    Canvas canvas, {
    required int index,
    required double left,
    required double barWidth,
    required double groupSpacing,
    required double chartBottom,
    required double chartHeight,
    required double maxValue,
    required double progress,
  }) {
    if (index >= columns.length || maxValue <= 0) return;
    final column = columns[index];
    final yStart = chartBottom - (column.start / maxValue) * chartHeight;
    final yEnd = chartBottom - (column.end / maxValue) * chartHeight;
    final top = math.min(yStart, yEnd);
    final height = (yEnd - yStart).abs() * progress;
    final color = column.color ?? theme.colorAt(index);
    final rect = Rect.fromLTWH(left, top, barWidth, height);
    _drawBar(canvas, rect: rect, color: color, cornerRadius: barWidth * 0.2);

    // Horizontal connector at the previous column's running total.
    if (index > 0) {
      final prevY =
          chartBottom - (columns[index - 1].end / maxValue) * chartHeight;
      canvas.drawLine(
        Offset(left - groupSpacing, prevY),
        Offset(left, prevY),
        Paint()
          ..color = theme.label.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }
}

/// A waterfall chart: bars span the running total's change from an initial value.
class WaterfallChart extends StatelessWidget {
  const WaterfallChart({
    super.key,
    required this.steps,
    this.initialValue = 0,
    this.startLabel,
    this.totalLabel,
    this.animate = true,
    this.replay = 0,
  });

  final List<WaterfallStep> steps;
  final double initialValue;
  final String? startLabel;
  final String? totalLabel;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: WaterfallChartRenderer(
      steps: steps,
      initialValue: initialValue,
      startLabel: startLabel,
      totalLabel: totalLabel,
    ),
    animate: animate,
    replay: replay,
  );
}

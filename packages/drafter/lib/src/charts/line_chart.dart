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
import 'dart:ui' as ui;

import 'package:drafter/src/core/chart_data.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/interaction/label_layout.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Shared geometry / chrome
// ---------------------------------------------------------------------------

/// Plot rect using the Compose 10% inset on every edge.
ChartBounds _lineBounds(Size size) {
  final left = size.width * 0.1;
  final top = size.height * 0.1;
  return ChartBounds.insets(
    size,
    left: left,
    top: top,
    right: size.width - (left + size.width * 0.8),
    bottom: size.height - (top + size.height * 0.8),
  );
}

/// Draws the faint Y grid + value labels and the X-axis labels. Shared by all
/// line variants; mirrors the Compose `drawGridAndLabels` / `drawXAxisLabel`.
void _drawLineChrome(
  Canvas canvas, {
  required ChartBounds bounds,
  required List<String> categories,
  required int pointCount,
  required double maxValue,
  required DrafterThemeColors theme,
}) {
  final labels = normalizedLabels(categories, pointCount);
  // Guard a non-finite axis max so `(maxValue / step).toInt()` below cannot
  // throw on Infinity.
  maxValue = drafterFinite(maxValue);
  if (maxValue > 0) {
    final step = ChartAxis.gridStep(maxValue);
    final numSteps = (maxValue / step).toInt();
    final gridPaint = Paint()
      ..color = theme.grid
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 0; i <= (numSteps < 0 ? 0 : numSteps); i++) {
      final value = i * step;
      final ratio = value / maxValue;
      final y = bounds.bottom - ratio * bounds.height;
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.left + bounds.width, y),
        gridPaint,
      );
      drawChartText(
        canvas,
        '${value.toInt()}',
        Offset(bounds.left - 6, y),
        color: theme.label,
        h: HAlign.end,
        v: VAlign.center,
      );
    }
  }

  if (labels.length <= 1) return;
  // X labels, de-overlapped by measured width so dense axes stay legible
  // (replaces fixed stride-thinning, which ignored how wide labels actually are).
  final centers = <double>[];
  final widths = <double>[];
  final kept = <int>[];
  for (var index = 0; index < labels.length; index++) {
    if (labels[index].isEmpty) continue;
    centers.add(bounds.left + index * (bounds.width / (labels.length - 1)));
    widths.add(measureChartText(labels[index]));
    kept.add(index);
  }
  final keep = LabelLayout.thin(centers, widths, 6).toSet();
  for (var k = 0; k < kept.length; k++) {
    if (!keep.contains(k)) continue;
    drawChartText(
      canvas,
      labels[kept[k]],
      Offset(centers[k], bounds.bottom + 14),
      color: theme.label,
      h: HAlign.center,
      v: VAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
// Simple
// ---------------------------------------------------------------------------

/// Draws a single smooth series from `[ChartPoint]`: curve, gradient fill, reveal, dots.
class LineChartRenderer extends ChartRenderer implements InteractiveRenderer {
  /// Creates a renderer for a single smooth line series of [points].
  LineChartRenderer({required this.points, Color? color})
    : color = color ?? DrafterColors.blue;

  /// The ordered data points of the series.
  final List<ChartPoint> points;

  /// The stroke and fill color of the line.
  final Color color;

  /// The shared data→pixel scale for [size]; the single source of geometry for
  /// both [draw] and [buildScene].
  CartesianScale _scaleFor(Size size) {
    // Coerce non-finite values so the axis max can never become NaN/Infinity.
    final values = [for (final p in points) drafterFinite(p.value)];
    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    return CartesianScale(
      bounds: _lineBounds(size),
      count: values.length,
      minValue: 0,
      maxValue: maxValue,
    );
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    final values = [for (final p in points) drafterFinite(p.value)];
    final scale = _scaleFor(size);
    final bounds = scale.bounds;

    _drawLineChrome(
      canvas,
      bounds: bounds,
      categories: [for (final p in points) p.label],
      pointCount: values.length,
      maxValue: scale.maxValue,
      theme: theme,
    );

    if (values.length < 2 || scale.maxValue <= 0) return;

    final pixelPoints = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(scale.xForIndex(i), scale.yForValue(values[i])),
    ];

    drawSmoothLine(
      canvas,
      points: pixelPoints,
      color: color,
      baseline: bounds.bottom,
      progress: progress,
    );
  }

  @override
  ChartScene buildScene(Size size) {
    final values = [for (final p in points) p.value];
    if (values.length < 2) return ChartScene.empty;
    final scale = _scaleFor(size);
    if (scale.maxValue <= 0) return ChartScene.empty;
    return ChartScene(
      bounds: scale.bounds,
      scale: scale,
      categories: [for (final p in points) p.label],
      marks: [
        for (var i = 0; i < values.length; i++)
          PlotMark(
            index: i,
            seriesIndex: 0,
            seriesName: '',
            label: points[i].label,
            value: values[i],
            center: Offset(
              scale.xForIndex(i),
              scale.yForValue(drafterFinite(values[i])),
            ),
            color: color,
          ),
      ],
    );
  }

  @override
  String get accessibilityLabel => 'Line chart';

  @override
  String get accessibilityValue => points.isEmpty
      ? 'No data'
      : '${points.length} points, '
            '${AccessibilityFormat.points([for (final p in points) (p.label, p.value)])}';
}

// ---------------------------------------------------------------------------
// Grouped (overlaid multi-series)
// ---------------------------------------------------------------------------

/// Draws overlaid smooth series with no fill; vertex dots reveal with the trace.
class GroupedLineChartRenderer extends ChartRenderer
    implements InteractiveRenderer {
  /// Creates a renderer for overlaid line [series] sharing [categories].
  const GroupedLineChartRenderer({
    required this.series,
    this.categories = const [],
  });

  /// The overlaid data series, each drawn as its own line.
  final List<ChartSeries> series;

  /// The shared x-axis category labels.
  final List<String> categories;

  @override
  ChartScene buildScene(Size size) {
    if (series.isEmpty) return ChartScene.empty;
    final all = [
      for (final s in series)
        for (final v in s.values) drafterFinite(v),
    ];
    final maxValue = all.isEmpty ? 0.0 : all.reduce((a, b) => a > b ? a : b);
    final numPoints = series
        .map((s) => s.values.length)
        .reduce((a, b) => a > b ? a : b);
    if (numPoints < 2 || maxValue <= 0) return ChartScene.empty;
    final scale = CartesianScale(
      bounds: _lineBounds(size),
      count: numPoints,
      minValue: 0,
      maxValue: maxValue,
    );
    final labels = normalizedLabels(categories, numPoints);
    return ChartScene(
      bounds: scale.bounds,
      scale: scale,
      categories: labels,
      marks: [
        for (var s = 0; s < series.length; s++)
          for (var i = 0; i < numPoints; i++)
            if (i < series[s].values.length)
              PlotMark(
                index: i,
                seriesIndex: s,
                seriesName: series[s].name,
                label: labels[i],
                value: series[s].values[i],
                center: Offset(
                  scale.xForIndex(i),
                  scale.yForValue(drafterFinite(series[s].values[i])),
                ),
                color: series[s].color,
              ),
      ],
    );
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    final all = [
      for (final s in series)
        for (final v in s.values) drafterFinite(v),
    ];
    final maxValue = all.isEmpty ? 0.0 : all.reduce((a, b) => a > b ? a : b);
    final bounds = _lineBounds(size);

    final numPoints = series.isEmpty
        ? 0
        : series.map((s) => s.values.length).reduce((a, b) => a > b ? a : b);
    _drawLineChrome(
      canvas,
      bounds: bounds,
      categories: categories,
      pointCount: numPoints,
      maxValue: maxValue,
      theme: theme,
    );

    if (numPoints < 2 || maxValue <= 0 || series.isEmpty) return;

    final xs = <double>[
      for (var i = 0; i < numPoints; i++)
        bounds.left + i * (bounds.width / (numPoints - 1)),
    ];
    final clamped = progress.clamp(0.0, 1.0);
    final span = xs.last - xs.first;
    final revealRight = xs.first + span * clamped;

    for (final line in series) {
      final pixelPoints = <Offset>[
        for (var i = 0; i < numPoints; i++)
          Offset(
            xs[i],
            bounds.bottom -
                (drafterFinite(i < line.values.length ? line.values[i] : 0.0) /
                        maxValue) *
                    bounds.height,
          ),
      ];
      drawSmoothLine(
        canvas,
        points: pixelPoints,
        color: line.color,
        baseline: bounds.bottom,
        progress: progress,
        strokeWidth: 5,
        fill: false,
        endDot: false,
      );
      for (final p in pixelPoints) {
        if (p.dx <= revealRight + 0.5) {
          drawVertexDot(canvas, p, line.color, 5);
        }
      }
    }
  }

  @override
  String get accessibilityLabel => 'Grouped line chart';

  @override
  String get accessibilityValue => series.isEmpty
      ? 'No data'
      : '${series.length} series: ${series.map((s) => '${s.name.isEmpty ? 'series' : s.name} ${AccessibilityFormat.range(s.values)}').join('; ')}';
}

// ---------------------------------------------------------------------------
// Stacked (stacked filled areas)
// ---------------------------------------------------------------------------

/// Draws cumulative smooth filled bands that grow vertically with the reveal.
class StackedLineChartRenderer extends ChartRenderer
    implements InteractiveRenderer {
  /// Creates a renderer for cumulatively stacked line [series] sharing
  /// [categories].
  const StackedLineChartRenderer({
    required this.series,
    this.categories = const [],
  });

  /// The data series, stacked cumulatively from the first to the last.
  final List<ChartSeries> series;

  /// The shared x-axis category labels.
  final List<String> categories;

  @override
  ChartScene buildScene(Size size) {
    if (series.isEmpty) return ChartScene.empty;
    final numPoints = series
        .map((s) => s.values.length)
        .reduce((a, b) => a > b ? a : b);
    final totals = <double>[
      for (var i = 0; i < numPoints; i++)
        series.fold<double>(
          0,
          (sum, s) =>
              sum + drafterFinite(i < s.values.length ? s.values[i] : 0.0),
        ),
    ];
    final maxValue = totals.isEmpty
        ? 0.0
        : totals.reduce((a, b) => a > b ? a : b);
    if (numPoints < 2 || maxValue <= 0) return ChartScene.empty;
    final scale = CartesianScale(
      bounds: _lineBounds(size),
      count: numPoints,
      minValue: 0,
      maxValue: maxValue,
    );
    final labels = normalizedLabels(categories, numPoints);
    final marks = <PlotMark>[];
    for (var s = 0; s < series.length; s++) {
      for (var i = 0; i < numPoints; i++) {
        // Cumulative top of this band (the painted y); the row shows the
        // series' own contribution, not the running total.
        var cumulative = 0.0;
        for (var k = 0; k <= s; k++) {
          final v = series[k].values;
          if (i < v.length) cumulative += drafterFinite(v[i]);
        }
        final own = i < series[s].values.length ? series[s].values[i] : 0.0;
        marks.add(
          PlotMark(
            index: i,
            seriesIndex: s,
            seriesName: series[s].name,
            label: labels[i],
            value: own,
            center: Offset(scale.xForIndex(i), scale.yForValue(cumulative)),
            color: series[s].color,
          ),
        );
      }
    }
    return ChartScene(
      bounds: scale.bounds,
      scale: scale,
      categories: labels,
      marks: marks,
    );
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    final numPoints = series.isEmpty
        ? 0
        : series.map((s) => s.values.length).reduce((a, b) => a > b ? a : b);
    final totals = <double>[
      for (var i = 0; i < numPoints; i++)
        series.fold(
          0,
          (sum, s) =>
              sum + drafterFinite(i < s.values.length ? s.values[i] : 0.0),
        ),
    ];
    final maxValue = totals.isEmpty
        ? 0.0
        : totals.reduce((a, b) => a > b ? a : b);
    final bounds = _lineBounds(size);

    _drawLineChrome(
      canvas,
      bounds: bounds,
      categories: categories,
      pointCount: numPoints,
      maxValue: maxValue,
      theme: theme,
    );

    if (numPoints < 2 || maxValue <= 0 || series.isEmpty) return;
    final baseline = bounds.bottom;
    final stackCount = series.length;

    final xs = <double>[
      for (var i = 0; i < numPoints; i++)
        bounds.left + i * (bounds.width / (numPoints - 1)),
    ];

    // cumulative[k][i] = sum of levels 0..k at x-index i.
    final cumulative = <List<double>>[
      for (var k = 0; k < stackCount; k++)
        [
          for (var i = 0; i < numPoints; i++)
            () {
              var sum = 0.0;
              for (var s = 0; s <= k; s++) {
                final v = series[s].values;
                if (i < v.length) sum += drafterFinite(v[i]);
              }
              return sum;
            }(),
        ],
    ];

    // Back-to-front: top level first so each band shows above the one below.
    for (var stackIndex = stackCount - 1; stackIndex >= 0; stackIndex--) {
      final color = series[stackIndex].color;
      final topPoints = <Offset>[
        for (var i = 0; i < numPoints; i++)
          Offset(
            xs[i],
            baseline -
                ((cumulative[stackIndex][i] * progress) / maxValue) *
                    bounds.height,
          ),
      ];

      final curve = smoothPath(topPoints);
      final fillPath = Path.from(curve)
        ..lineTo(topPoints.last.dx, baseline)
        ..lineTo(topPoints.first.dx, baseline)
        ..close();

      var topY = double.infinity;
      for (final p in topPoints) {
        if (p.dy < topY) topY = p.dy;
      }
      canvas
        ..drawPath(
          fillPath,
          Paint()
            ..style = PaintingStyle.fill
            ..shader = ui.Gradient.linear(
              Offset(0, topY),
              Offset(0, baseline),
              [
                color.withValues(alpha: 0.85),
                color.withValues(alpha: 0.85 * 0.45),
                color.withValues(alpha: 0),
              ],
              const [0.0, 0.5, 1.0],
            ),
        )
        ..drawPath(
          curve,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
    }
  }

  @override
  String get accessibilityLabel => 'Stacked line chart';

  @override
  String get accessibilityValue => series.isEmpty
      ? 'No data'
      : '${series.length} series: ${series.map((s) => '${s.name.isEmpty ? 'series' : s.name} ${AccessibilityFormat.range(s.values)}').join('; ')}';
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// A smooth single-series line chart with a soft gradient fill and reveal.
class LineChart extends StatelessWidget {
  /// Creates a single-series line chart for [points].
  LineChart({
    super.key,
    required this.points,
    Color? color,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 1100),
  }) : color = color ?? DrafterColors.blue;

  /// Convenience for unlabeled data: one value per point, blank x-axis labels.
  LineChart.values({
    super.key,
    required List<double> values,
    Color? color,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 1100),
  }) : points = [for (final v in values) ChartPoint.value(v)],
       color = color ?? DrafterColors.blue;

  /// The ordered data points to plot.
  final List<ChartPoint> points;

  /// The stroke and fill color of the line.
  final Color color;

  /// Whether to play the reveal animation when first shown.
  final bool animate;

  /// Bump this value to replay the reveal animation.
  final int replay;

  /// The duration of the reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: LineChartRenderer(points: points, color: color),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}

/// Overlaid multi-series smooth lines with revealed vertex dots.
class GroupedLineChart extends StatelessWidget {
  /// Creates an overlaid multi-series line chart for [series].
  const GroupedLineChart({
    super.key,
    required this.series,
    this.categories = const [],
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 1100),
  });

  /// The overlaid data series, each drawn as its own line.
  final List<ChartSeries> series;

  /// The shared x-axis category labels.
  final List<String> categories;

  /// Whether to play the reveal animation when first shown.
  final bool animate;

  /// Bump this value to replay the reveal animation.
  final int replay;

  /// The duration of the reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: GroupedLineChartRenderer(series: series, categories: categories),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}

/// Stacked filled areas that grow vertically with the reveal.
class StackedLineChart extends StatelessWidget {
  /// Creates a cumulatively stacked multi-series line chart for [series].
  const StackedLineChart({
    super.key,
    required this.series,
    this.categories = const [],
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 1100),
  });

  /// The data series, stacked cumulatively from the first to the last.
  final List<ChartSeries> series;

  /// The shared x-axis category labels.
  final List<String> categories;

  /// Whether to play the reveal animation when first shown.
  final bool animate;

  /// Bump this value to replay the reveal animation.
  final int replay;

  /// The duration of the reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: StackedLineChartRenderer(series: series, categories: categories),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}

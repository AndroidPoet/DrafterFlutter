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
  const maxLabels = 6;
  final stride = ((labels.length + maxLabels - 1) ~/ maxLabels).clamp(
    1,
    1 << 30,
  );
  for (var index = 0; index < labels.length; index++) {
    final label = labels[index];
    if (index % stride != 0 || label.isEmpty) continue;
    final x = bounds.left + index * (bounds.width / (labels.length - 1));
    drawChartText(
      canvas,
      label,
      Offset(x, bounds.bottom + 14),
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
class LineChartRenderer extends ChartRenderer {
  LineChartRenderer({required this.points, Color? color})
    : color = color ?? DrafterColors.blue;

  final List<ChartPoint> points;
  final Color color;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    final values = [for (final p in points) p.value];
    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    final bounds = _lineBounds(size);

    _drawLineChrome(
      canvas,
      bounds: bounds,
      categories: [for (final p in points) p.label],
      pointCount: values.length,
      maxValue: maxValue,
      theme: theme,
    );

    if (values.length < 2 || maxValue <= 0) return;

    final pixelPoints = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          bounds.left + bounds.width * i / (values.length - 1),
          bounds.bottom - (values[i] / maxValue) * bounds.height,
        ),
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
class GroupedLineChartRenderer extends ChartRenderer {
  const GroupedLineChartRenderer({
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
    final all = [for (final s in series) ...s.values];
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
                ((i < line.values.length ? line.values[i] : 0.0) / maxValue) *
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
class StackedLineChartRenderer extends ChartRenderer {
  const StackedLineChartRenderer({
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
    final numPoints = series.isEmpty
        ? 0
        : series.map((s) => s.values.length).reduce((a, b) => a > b ? a : b);
    final totals = <double>[
      for (var i = 0; i < numPoints; i++)
        series.fold(
          0,
          (sum, s) => sum + (i < s.values.length ? s.values[i] : 0.0),
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
                if (i < v.length) sum += v[i];
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
  LineChart({
    super.key,
    required this.points,
    Color? color,
    this.animate = true,
    this.replay = 0,
  }) : color = color ?? DrafterColors.blue;

  /// Convenience for unlabeled data: one value per point, blank x-axis labels.
  LineChart.values({
    super.key,
    required List<double> values,
    Color? color,
    this.animate = true,
    this.replay = 0,
  }) : points = [for (final v in values) ChartPoint.value(v)],
       color = color ?? DrafterColors.blue;

  final List<ChartPoint> points;
  final Color color;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: LineChartRenderer(points: points, color: color),
    animate: animate,
    duration: const Duration(milliseconds: 1100),
    replay: replay,
  );
}

/// Overlaid multi-series smooth lines with revealed vertex dots.
class GroupedLineChart extends StatelessWidget {
  const GroupedLineChart({
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
    renderer: GroupedLineChartRenderer(series: series, categories: categories),
    animate: animate,
    duration: const Duration(milliseconds: 1100),
    replay: replay,
  );
}

/// Stacked filled areas that grow vertically with the reveal.
class StackedLineChart extends StatelessWidget {
  const StackedLineChart({
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
    renderer: StackedLineChartRenderer(series: series, categories: categories),
    animate: animate,
    duration: const Duration(milliseconds: 1100),
    replay: replay,
  );
}

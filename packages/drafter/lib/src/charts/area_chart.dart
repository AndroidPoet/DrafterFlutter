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

import 'package:drafter/src/core/chart_data.dart';
import 'package:drafter/src/core/chart_formatting.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// Draws a smooth area chart from `[ChartPoint]`: Catmull-Rom spline, soft
/// gradient fill that fades to the baseline, a left-to-right reveal, and
/// white-haloed vertex dots.
class AreaChartRenderer extends ChartRenderer {
  AreaChartRenderer({required this.points, Color? color})
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
    if (points.length < 2) return;
    final values = [for (final p in points) p.value];

    final bounds = ChartBounds.insets(
      size,
      left: 40,
      top: 12,
      right: 16,
      bottom: 26,
    );
    // Zero-anchored axis, like the Compose renderer (max clamped to >= 1).
    final rawMax = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    final maxValue = rawMax <= 0 ? 1.0 : rawMax;

    // Y grid + labels (4 ticks).
    const tickCount = 4;
    final gridPaint = Paint()
      ..color = theme.grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i <= tickCount; i++) {
      final frac = i / tickCount;
      final y = bounds.bottom - frac * bounds.height;
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.right, y),
        gridPaint,
      );

      final tickValue = maxValue * frac;
      drawChartText(
        canvas,
        ChartFormatting.format(tickValue),
        Offset(bounds.left - 6, y),
        color: theme.label,
        h: HAlign.end,
        v: VAlign.center,
      );
    }

    // Map points into pixel space.
    final denom = math.max(1, values.length - 1).toDouble();
    final pixelPoints = <Offset>[
      for (var index = 0; index < values.length; index++)
        () {
          final t = index / denom;
          final x = bounds.left + bounds.width * t;
          final norm = values[index] / maxValue;
          final y = bounds.bottom - norm * bounds.height;
          return Offset(x, y);
        }(),
    ];

    // Smooth area + line + reveal + end dot (shared helper).
    drawSmoothLine(
      canvas,
      points: pixelPoints,
      color: color,
      baseline: bounds.bottom,
      progress: progress,
      strokeWidth: 5,
    );

    // Vertex dots, revealed alongside the trace.
    final revealRight = bounds.left + bounds.width * progress.clamp(0.0, 1.0);
    for (final point in pixelPoints) {
      if (point.dx <= revealRight + 0.5) {
        drawVertexDot(canvas, point, color, 4);
      }
    }

    // X labels, thinned so they stay legible at small sizes (at most ~6). Each
    // label travels with its point, so labels can never shift or run short.
    const maxLabels = 6;
    final labelStride = math.max(
      1,
      (pixelPoints.length + maxLabels - 1) ~/ maxLabels,
    );
    for (var index = 0; index < pixelPoints.length; index++) {
      if (index % labelStride != 0) continue;
      final label = points[index].label;
      if (label.isEmpty) continue;
      drawChartText(
        canvas,
        label,
        Offset(pixelPoints[index].dx, bounds.bottom + 13),
        color: theme.label,
        h: HAlign.center,
        v: VAlign.center,
      );
    }
  }

  @override
  String get accessibilityLabel => 'Area chart';

  @override
  String get accessibilityValue => points.isEmpty
      ? 'No data'
      : '${points.length} points, '
            '${AccessibilityFormat.points([for (final p in points) (p.label, p.value)])}';
}

/// A smooth area chart with a soft gradient fill and an animated reveal.
class AreaChart extends StatelessWidget {
  AreaChart({
    super.key,
    required this.points,
    Color? color,
    this.animate = true,
    this.replay = 0,
  }) : color = color ?? DrafterColors.blue;

  /// Convenience for unlabeled data: one value per point, blank x-axis labels.
  AreaChart.values({
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
    renderer: AreaChartRenderer(points: points, color: color),
    animate: animate,
    duration: const Duration(milliseconds: 900),
    replay: replay,
  );
}

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
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// Builds a stepped polyline: for each segment go horizontally at the prior
/// y to the next x, then vertically to the next y.
Path _steppedPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    path
      ..lineTo(points[i].dx, points[i - 1].dy)
      ..lineTo(points[i].dx, points[i].dy);
  }
  return path;
}

/// Draws a stepped line chart from `[ChartPoint]` as horizontal/vertical steps,
/// with a soft gradient fill, a left-to-right reveal that clips the trace, and
/// vertex dots at each data point. Mirrors the Compose `StepLineChartRenderer`.
class StepLineChartRenderer extends ChartRenderer
    implements InteractiveRenderer {
  /// Creates a renderer for a single stepped line series of [points].
  StepLineChartRenderer({required this.points, Color? color})
    : color = color ?? DrafterColors.teal;

  /// The ordered data points of the series.
  final List<ChartPoint> points;

  /// The stroke and gradient-fill color of the stepped line.
  final Color color;

  /// The shared data→pixel scale; same insets/zero-anchor [draw] uses.
  CartesianScale _scaleFor(Size size) {
    // Coerce non-finite values so the axis max can never become NaN/Infinity.
    final values = [for (final p in points) drafterFinite(p.value)];
    final rawMax = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    return CartesianScale(
      bounds: ChartBounds.insets(
        size,
        left: 40,
        top: 12,
        right: 16,
        bottom: 26,
      ),
      count: values.length,
      minValue: 0,
      maxValue: rawMax <= 0 ? 1.0 : rawMax,
    );
  }

  @override
  ChartScene buildScene(Size size) {
    if (points.isEmpty) return ChartScene.empty;
    final scale = _scaleFor(size);
    return ChartScene(
      bounds: scale.bounds,
      scale: scale,
      categories: [for (final p in points) p.label],
      marks: [
        for (var i = 0; i < points.length; i++)
          PlotMark(
            index: i,
            seriesIndex: 0,
            seriesName: '',
            label: points[i].label,
            value: points[i].value,
            center: Offset(
              scale.xForIndex(i),
              scale.yForValue(drafterFinite(points[i].value)),
            ),
            color: color,
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
    final values = [for (final p in points) drafterFinite(p.value)];
    if (values.isEmpty) return;

    final bounds = ChartBounds.insets(
      size,
      left: 40,
      top: 12,
      right: 16,
      bottom: 26,
    );
    // Anchored at zero, like the Compose renderer.
    final rawMax = values.reduce((a, b) => a > b ? a : b);
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

    // Map data points to pixel space.
    final count = values.length;
    final pixelPoints = <Offset>[
      for (var index = 0; index < count; index++)
        () {
          final double x;
          if (count == 1) {
            x = bounds.left + bounds.width / 2;
          } else {
            x = bounds.left + index / (count - 1) * bounds.width;
          }
          final y = bounds.bottom - (values[index] / maxValue) * bounds.height;
          return Offset(x, y);
        }(),
    ];

    // Stepped path: horizontal to next x at the previous y, then vertical to next y.
    final stepPath = _steppedPath(pixelPoints);

    final clamped = progress.clamp(0.0, 1.0);
    final revealRight = bounds.left + bounds.width * clamped;

    // Reveal clip: everything left of the moving edge.
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, revealRight, size.height));

    final first = pixelPoints.first;
    final last = pixelPoints.last;
    var topY = double.infinity;
    for (final p in pixelPoints) {
      if (p.dy < topY) topY = p.dy;
    }
    if (!topY.isFinite) topY = bounds.top;

    final fillPath = Path.from(stepPath)
      ..lineTo(last.dx, bounds.bottom)
      ..lineTo(first.dx, bounds.bottom)
      ..close();
    canvas
      ..drawPath(
        fillPath,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = ui.Gradient.linear(
            Offset(0, topY),
            Offset(0, bounds.bottom),
            [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0),
            ],
          ),
      )
      // Stepped line with rounded caps/joins.
      ..drawPath(
        stepPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();

    // Vertex dots at each revealed data point.
    for (final point in pixelPoints) {
      if (point.dx <= revealRight + 0.5) {
        drawVertexDot(canvas, point, color, 4);
      }
    }

    // X-axis labels, thinned so they stay legible at small sizes (at most ~6).
    // Each label travels with its point, so labels can never shift or run short;
    // blank labels (unlabeled points) are simply skipped.
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
  String get accessibilityLabel => 'Step line chart';

  @override
  String get accessibilityValue => points.isEmpty
      ? 'No data'
      : '${points.length} points, '
            '${AccessibilityFormat.points([for (final p in points) (p.label, p.value)])}';
}

/// A stepped line chart with a soft gradient fill and a left-to-right reveal.
class StepLineChart extends StatelessWidget {
  /// Creates a single-series stepped line chart for [points].
  StepLineChart({
    super.key,
    required this.points,
    Color? color,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 900),
  }) : color = color ?? DrafterColors.teal;

  /// Convenience for unlabeled data: one value per point, blank x-axis labels.
  StepLineChart.values({
    super.key,
    required List<double> values,
    Color? color,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 900),
  }) : points = [for (final v in values) ChartPoint.value(v)],
       color = color ?? DrafterColors.teal;

  /// The ordered data points to plot.
  final List<ChartPoint> points;

  /// The stroke and gradient-fill color of the stepped line.
  final Color color;

  /// Whether to play the reveal animation when first shown.
  final bool animate;

  /// Bump this value to replay the reveal animation.
  final int replay;

  /// The duration of the reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: StepLineChartRenderer(points: points, color: color),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}

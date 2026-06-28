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

import 'package:drafter/src/core/chart_formatting.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// A single bubble: position (`x`, `y`), relative `size`, and a fill color.
@immutable
class BubbleData {
  /// Creates a bubble at (`x`, `y`) with the given [size] and optional [color]
  /// (defaults to the Drafter blue palette color).
  const BubbleData({
    required this.x,
    required this.y,
    required this.size,
    Color? color,
  }) : color = color ?? const Color(0xFF4C8DF6); // mirrors DrafterColors.blue

  /// The bubble's x position in data space.
  final double x;

  /// The bubble's y position in data space.
  final double y;

  /// The bubble's relative magnitude, mapped to its drawn radius.
  final double size;

  /// The bubble's fill color.
  final Color color;
}

/// Axis value ranges (always anchored at 0, max rounded up to a nice number).
class _BubbleValueRanges {
  const _BubbleValueRanges({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });

  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
}

/// Draws a bubble chart into a canvas with Cartesian axes and a grid.
class BubbleChartRenderer extends ChartRenderer implements InteractiveRenderer {
  /// Creates a bubble-chart renderer for the given [series].
  const BubbleChartRenderer({required this.series});

  /// The bubble groups to draw; each inner list is one series.
  final List<List<BubbleData>> series;

  @override
  ChartScene buildScene(Size size) {
    final all = [for (final group in series) ...group];
    if (all.isEmpty) return ChartScene.empty;

    // Same plot origin / extent the draw() pass uses.
    const originX = 40.0;
    final originY = size.height - 20;
    final chartWidth = size.width - 60;
    final chartHeight = size.height - 60;
    if (!(chartWidth > 0) || !(chartHeight > 0)) return ChartScene.empty;

    final ranges = _valueRanges();
    final xRange = math.max(ranges.xMax - ranges.xMin, 0.0001);
    final yRange = math.max(ranges.yMax - ranges.yMin, 0.0001);

    final maxBubbleSize = all
        .map((b) => drafterFinite(b.size))
        .fold(0.0, math.max);
    if (!(maxBubbleSize > 0)) return ChartScene.empty;
    final scaleFactor = math.min(chartWidth, chartHeight) / 6;

    // Free x/y/size layout (not index-uniform) → no CartesianScale. Each bubble
    // owns a circular tap halo (drawn radius, floored to a comfortable minimum).
    final bounds = ChartBounds(size, padding: 0);
    final marks = <PlotMark>[];
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final group = series[seriesIndex];
      for (var bubbleIndex = 0; bubbleIndex < group.length; bubbleIndex++) {
        final bubble = group[bubbleIndex];
        final x = originX + (drafterFinite(bubble.x) / xRange) * chartWidth;
        final y = originY - (drafterFinite(bubble.y) / yRange) * chartHeight;
        // Full-progress radius (the buildScene mirrors the final frame).
        final radius =
            (drafterFinite(bubble.size) / maxBubbleSize) * scaleFactor;
        final center = Offset(x, y);
        marks.add(
          PlotMark(
            index: bubbleIndex,
            seriesIndex: seriesIndex,
            seriesName: '',
            label:
                '${ChartFormatting.format(bubble.x)}, '
                '${ChartFormatting.format(bubble.y)}',
            value: bubble.y,
            center: center,
            color: bubble.color,
            region: Rect.fromCircle(
              center: center,
              radius: math.max(radius, 10),
            ),
          ),
        );
      }
    }
    return ChartScene(bounds: bounds, marks: marks);
  }

  // Always start at 0; round the max up to a tidy bound (matches Compose).
  double _roundToNiceNumber(double value) {
    // Guard before toInt(): a non-finite value would throw UnsupportedError
    // (even in release builds).
    if (!value.isFinite) return 10;
    if (value <= 50) return ((value + 9).toInt() ~/ 10 * 10).toDouble();
    if (value <= 100) return ((value + 24).toInt() ~/ 25 * 25).toDouble();
    return ((value + 49).toInt() ~/ 50 * 50).toDouble();
  }

  _BubbleValueRanges _valueRanges() {
    final all = [for (final group in series) ...group];
    // Fold over finite values only so a non-finite x/y can't poison the max.
    final xMax = _roundToNiceNumber(
      all.map((b) => drafterFinite(b.x)).fold(0.0, math.max),
    );
    final yMax = _roundToNiceNumber(
      all.map((b) => drafterFinite(b.y)).fold(0.0, math.max),
    );
    return _BubbleValueRanges(xMin: 0, xMax: xMax, yMin: 0, yMax: yMax);
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    final all = [for (final group in series) ...group];
    if (all.isEmpty) return;

    // Plot origin / extent (mirrors the Compose 40 / 20 / 60 insets).
    const originX = 40.0;
    final originY = size.height - 20;
    final chartWidth = size.width - 60;
    final chartHeight = size.height - 60;
    if (!(chartWidth > 0) || !(chartHeight > 0)) return;

    final ranges = _valueRanges();
    final xRange = math.max(ranges.xMax - ranges.xMin, 0.0001);
    final yRange = math.max(ranges.yMax - ranges.yMin, 0.0001);

    // Magnitude-based grid steps.
    final xStep = ChartAxis.gridStep(xRange);
    final yStep = ChartAxis.gridStep(yRange);
    final xLines = math.max((xRange / xStep).toInt(), 0);
    final yLines = math.max((yRange / yStep).toInt(), 0);

    final gridPaint = Paint()
      ..color = theme.grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Grid lines.
    for (var i = 0; i <= math.max(xLines, 0); i++) {
      final value = ranges.xMin + i * xStep;
      final ratio = (value - ranges.xMin) / xRange;
      final x = originX + ratio * chartWidth;
      canvas.drawLine(
        Offset(x, originY),
        Offset(x, originY - chartHeight),
        gridPaint,
      );
    }
    for (var i = 0; i <= math.max(yLines, 0); i++) {
      final value = ranges.yMin + i * yStep;
      final ratio = (value - ranges.yMin) / yRange;
      final y = originY - ratio * chartHeight;
      canvas.drawLine(
        Offset(originX, y),
        Offset(originX + chartWidth, y),
        gridPaint,
      );
    }

    // Axes (x along the bottom, y up the left).
    final axes = Path()
      ..moveTo(originX, originY)
      ..lineTo(originX + chartWidth, originY)
      ..moveTo(originX, originY)
      ..lineTo(originX, originY - chartHeight);
    canvas.drawPath(
      axes,
      Paint()
        ..color = theme.label
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Axis tick labels (integers, matching Compose `value.toInt()`).
    for (var i = 0; i <= math.max(xLines, 0); i++) {
      final value = ranges.xMin + i * xStep;
      final ratio = (value - ranges.xMin) / xRange;
      final x = originX + ratio * chartWidth;
      drawChartText(
        canvas,
        '${value.toInt()}',
        Offset(x, originY + 11),
        color: theme.label,
        fontSize: 10,
        h: HAlign.center,
        v: VAlign.center,
      );
    }
    for (var i = 0; i <= math.max(yLines, 0); i++) {
      final value = ranges.yMin + i * yStep;
      final ratio = (value - ranges.yMin) / yRange;
      final y = originY - ratio * chartHeight;
      drawChartText(
        canvas,
        '${value.toInt()}',
        Offset(originX - 5, y),
        color: theme.label,
        fontSize: 10,
        h: HAlign.end,
        v: VAlign.center,
      );
    }

    // Bubbles, with a per-bubble staggered reveal and size-proportional radius.
    final maxBubbleSize = all
        .map((b) => drafterFinite(b.size))
        .fold(0.0, math.max);
    if (!(maxBubbleSize > 0)) return;
    final scaleFactor = math.min(chartWidth, chartHeight) / 6;

    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final group = series[seriesIndex];
      for (var bubbleIndex = 0; bubbleIndex < group.length; bubbleIndex++) {
        final bubble = group[bubbleIndex];
        final delay = (seriesIndex * group.length + bubbleIndex) * 0.1;
        final bubbleProgress = (progress - delay).clamp(0.0, 1.0);

        // Use the floored xRange/yRange (not raw xMax/yMax) so an all-zero
        // axis can't produce 0 / 0 = NaN flowing into Offset/drawCircle.
        final x = originX + (drafterFinite(bubble.x) / xRange) * chartWidth;
        final y = originY - (drafterFinite(bubble.y) / yRange) * chartHeight;
        final scaledSize =
            (drafterFinite(bubble.size) / maxBubbleSize) * scaleFactor;
        final radius = scaledSize * bubbleProgress;
        if (!(radius > 0)) continue;

        final center = Offset(x, y);
        canvas
          ..drawCircle(
            center,
            radius,
            Paint()..color = bubble.color.withValues(alpha: 0.30),
          )
          ..drawCircle(
            center,
            radius,
            Paint()
              ..color = bubble.color.withValues(alpha: 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          );
      }
    }
  }

  @override
  String get accessibilityLabel => 'Bubble chart';

  @override
  String get accessibilityValue =>
      '${series.length} series, ${series.fold(0, (sum, g) => sum + g.length)} bubbles';
}

/// A bubble (scatter) chart with magnitude-based axes and a staggered reveal.
class BubbleChart extends StatelessWidget {
  /// Creates a bubble chart from [series] (each inner list is one series).
  const BubbleChart({
    super.key,
    required this.series,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 2000),
  });

  /// The bubble groups to draw; each inner list is one series.
  final List<List<BubbleData>> series;

  /// Whether the bubbles animate in on first reveal.
  final bool animate;

  /// Bump this to replay the reveal animation.
  final int replay;

  /// How long the reveal animation runs.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: BubbleChartRenderer(series: series),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}

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
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// A single box-and-whisker group: five-number summary plus a draw color.
class BoxGroup {
  BoxGroup({
    required this.label,
    required this.min,
    required this.q1,
    required this.median,
    required this.q3,
    required this.max,
    Color? color,
  }) : color = color ?? DrafterColors.violet;

  final String label;
  final double min;
  final double q1;
  final double median;
  final double q3;
  final double max;
  final Color color;
}

/// Draws box-and-whisker groups into a canvas.
class BoxPlotChartRenderer extends ChartRenderer {
  const BoxPlotChartRenderer({required this.groups});

  final List<BoxGroup> groups;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    if (groups.isEmpty) return;

    // Match the Compose layout: ~10% inset on every side, but floor the left
    // inset so Y axis labels never clip off the left edge at small sizes.
    final leftInset = math.max(size.width * 0.1, 34.0);
    final edgeY = size.height * 0.1;
    final bounds = ChartBounds.insets(
      size,
      left: leftInset,
      top: edgeY,
      right: size.width * 0.1,
      bottom: edgeY,
    );
    final chartBottom = bounds.bottom;

    // Global value range across all groups.
    final globalMin = groups.map((g) => g.min).reduce((a, b) => a < b ? a : b);
    final globalMax = groups.map((g) => g.max).reduce((a, b) => a > b ? a : b);
    final range = math.max(globalMax - globalMin, 0.0001);

    double valueToY(double value) =>
        chartBottom - ((value - globalMin) / range) * bounds.height;

    // Gridlines + y labels.
    const gridLines = 5;
    for (var i = 0; i <= gridLines; i++) {
      final fraction = i / gridLines;
      final value = globalMin + fraction * range;
      final y = chartBottom - fraction * bounds.height;
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.right, y),
        Paint()
          ..color = theme.grid
          ..strokeWidth = 1,
      );

      drawChartText(
        canvas,
        ChartFormatting.format(value),
        Offset(bounds.left - 6, y),
        color: theme.label,
        fontSize: 10,
        h: HAlign.end,
        v: VAlign.center,
      );
    }

    // Distribute group columns evenly across the width.
    final columnWidth = bounds.width / groups.length;
    final boxWidth = math.min(columnWidth * 0.45, 70.0);

    final p = progress.clamp(0.0, 1.0);

    for (var index = 0; index < groups.length; index++) {
      final group = groups[index];
      final centerX = bounds.left + columnWidth * (index + 0.5);

      final yMin = valueToY(group.min);
      final yMedian = valueToY(group.median);
      final yQ1 = valueToY(group.q1);
      final yQ3 = valueToY(group.q3);
      final yMax = valueToY(group.max);

      // Whiskers extend out from the median line.
      final whiskerTopY = yMedian + (yMax - yMedian) * p;
      final whiskerBottomY = yMedian + (yMin - yMedian) * p;
      canvas.drawLine(
        Offset(centerX, whiskerTopY),
        Offset(centerX, whiskerBottomY),
        Paint()
          ..color = group.color
          ..strokeWidth = 2,
      );

      // Caps at min and max.
      final capHalf = boxWidth * 0.3;
      final capsPaint = Paint()
        ..color = group.color
        ..strokeWidth = 2;
      canvas
        ..drawLine(
          Offset(centerX - capHalf, whiskerTopY),
          Offset(centerX + capHalf, whiskerTopY),
          capsPaint,
        )
        ..drawLine(
          Offset(centerX - capHalf, whiskerBottomY),
          Offset(centerX + capHalf, whiskerBottomY),
          capsPaint,
        );

      // Box grows vertically out from the median line.
      final boxTopY = yMedian + (yQ3 - yMedian) * p;
      final boxBottomY = yMedian + (yQ1 - yMedian) * p;
      final boxLeft = centerX - boxWidth / 2;
      final boxTop = math.min(boxTopY, boxBottomY);
      final boxHeight = (boxBottomY - boxTopY).abs();
      final boxRect = Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight);
      final boxRRect = RRect.fromRectAndRadius(
        boxRect,
        const Radius.circular(8),
      );

      canvas
        ..drawRRect(
          boxRRect,
          Paint()..color = group.color.withValues(alpha: 0.35),
        )
        ..drawRRect(
          boxRRect,
          Paint()
            ..color = group.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        )
        // Bold median line across the box (always at the median position).
        ..drawLine(
          Offset(boxLeft, yMedian),
          Offset(boxLeft + boxWidth, yMedian),
          Paint()
            ..color = group.color
            ..strokeWidth = 3.5,
        );

      // X label under each box.
      drawChartText(
        canvas,
        group.label,
        Offset(centerX, chartBottom + 12),
        color: theme.label,
        fontSize: 10,
        h: HAlign.center,
      );
    }
  }

  @override
  String get accessibilityLabel => 'Box plot';

  @override
  String get accessibilityValue {
    if (groups.isEmpty) return 'No data';
    final summaries = groups
        .map((g) => '${g.label} median ${AccessibilityFormat.number(g.median)}')
        .join('; ');
    return '${groups.length} groups: $summaries';
  }
}

/// A box-and-whisker chart with whiskers, translucent boxes, and median lines
/// that grow out from the median on an animated reveal.
class BoxPlotChart extends StatelessWidget {
  const BoxPlotChart({
    super.key,
    required this.groups,
    this.animate = true,
    this.replay = 0,
  });

  final List<BoxGroup> groups;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: BoxPlotChartRenderer(groups: groups),
    animate: animate,
    duration: const Duration(milliseconds: 900),
    replay: replay,
  );
}

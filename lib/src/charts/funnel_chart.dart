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

import 'package:drafter/src/core/chart_formatting.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// One stage (band) of a [FunnelChart]: a [label], a [value], and a fill [color].
class FunnelStage {
  const FunnelStage({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// Draws an ordered list of [FunnelStage]s as stacked, center-converging
/// trapezoids into a canvas.
class FunnelChartRenderer extends ChartRenderer {
  const FunnelChartRenderer({required this.stages});

  final List<FunnelStage> stages;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    if (stages.isEmpty) return;

    // Matches Compose FunnelChart host insets (0.1 / 0.08 / 0.8 / 0.84).
    final chartLeft = size.width * 0.1;
    final chartTop = size.height * 0.08;
    final chartWidth = size.width * 0.8;
    final chartHeight = size.height * 0.84;

    final maxValue = stages
        .map((s) => s.value)
        .fold<double>(stages.first.value, (a, b) => a > b ? a : b);
    final safeMax = maxValue > 0 ? maxValue : 1.0;
    final centerX = chartLeft + chartWidth / 2;
    final gap = chartHeight * 0.02;
    final count = stages.length;
    final bandHeight = (chartHeight - gap * (count - 1)) / count;
    // The narrowest band keeps a sensible minimum width so it never pinches to nothing.
    const minWidthFraction = 0.12;

    double widthFor(double value) {
      final fraction =
          minWidthFraction + (1 - minWidthFraction) * (value / safeMax);
      return chartWidth * fraction;
    }

    final prog = progress.clamp(0.0, 1.0);
    final labelColor = theme.label;

    for (var index = 0; index < count; index++) {
      final stage = stages[index];
      final topFull = widthFor(stage.value);
      final bottomValue = index < count - 1
          ? stages[index + 1].value
          : stage.value;
      final bottomFull = widthFor(bottomValue);

      // Widths expand outward from the center with the reveal.
      final topHalf = (topFull / 2) * prog;
      final bottomHalf = (bottomFull / 2) * prog;

      final bandTop = chartTop + index * (bandHeight + gap);
      final bandBottom = bandTop + bandHeight;

      final path = Path()
        ..moveTo(centerX - topHalf, bandTop)
        ..lineTo(centerX + topHalf, bandTop)
        ..lineTo(centerX + bottomHalf, bandBottom)
        ..lineTo(centerX - bottomHalf, bandBottom)
        ..close();

      canvas
        ..drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(centerX, bandTop),
              Offset(centerX, bandBottom),
              [
                stage.color.withValues(alpha: 0.95 * progress),
                stage.color.withValues(alpha: 0.7 * progress),
              ],
            ),
        )
        // Soft top highlight for a rounded, premium feel.
        ..drawLine(
          Offset(centerX - topHalf, bandTop),
          Offset(centerX + topHalf, bandTop),
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.22 * progress)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

      if (progress > 0.55) {
        final centerY = bandTop + bandHeight / 2;
        const labelFont = 13.0;
        const valueFont = 11.0;
        final labelHeight = _textHeight(stage.label, labelFont);
        final valueHeight = _textHeight(
          ChartFormatting.format(stage.value, decimals: 2),
          valueFont,
        );
        final totalH = labelHeight + valueHeight + 2;
        final topY = centerY - totalH / 2;

        drawChartText(
          canvas,
          stage.label,
          Offset(centerX, topY + labelHeight / 2),
          color: labelColor,
          fontSize: labelFont,
          h: HAlign.center,
          v: VAlign.center,
        );
        drawChartText(
          canvas,
          ChartFormatting.format(stage.value, decimals: 2),
          Offset(centerX, topY + labelHeight + 2 + valueHeight / 2),
          color: labelColor.withValues(alpha: 0.74),
          fontSize: valueFont,
          h: HAlign.center,
          v: VAlign.center,
        );
      }
    }
  }

  static double _textHeight(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.height;
  }

  /// VoiceOver: names this as a funnel chart.
  @override
  String get accessibilityLabel => 'Funnel chart';

  /// VoiceOver: the stage count and each stage's label/value.
  @override
  String get accessibilityValue => stages.isEmpty
      ? 'No data'
      : '${stages.length} stages, '
            '${AccessibilityFormat.points([for (final s in stages) (s.label, s.value)])}';
}

/// A stacked, center-converging funnel chart with an animated outward reveal.
class FunnelChart extends StatelessWidget {
  const FunnelChart({
    super.key,
    required this.stages,
    this.animate = true,
    this.replay = 0,
  });

  final List<FunnelStage> stages;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: FunnelChartRenderer(stages: stages),
    animate: animate,
    duration: const Duration(milliseconds: 900),
    replay: replay,
  );
}

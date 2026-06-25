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

/// Draws `[ScatterPoint]` into a canvas using a bottom-left origin.
class ScatterPlotRenderer extends ChartRenderer {
  const ScatterPlotRenderer({required this.points});

  final List<ScatterPoint> points;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    if (points.isEmpty) return;

    // 10% inset on every side, matching the Compose layout (0.8 plot area).
    // Floor the left inset so Y axis labels never clip off the left edge at
    // small canvas sizes (10% of 300pt is only 30pt — too tight for "100.0").
    final chartHeight = size.height * 0.8;
    final chartTop = size.height * 0.1;
    final chartBottom = chartTop + chartHeight;
    final chartLeft = math.max(size.width * 0.1, 34.0);
    final chartWidth = size.width * 0.9 - chartLeft;

    final maxX = points.map((p) => p.x).fold(0.0, math.max);
    final maxY = points.map((p) => p.y).fold(0.0, math.max);
    if (!(maxX > 0) || !(maxY > 0)) return;

    // Axes: left (Y) and bottom (X), origin at bottom-left.
    final axes = Path()
      ..moveTo(chartLeft, chartTop)
      ..lineTo(chartLeft, chartBottom)
      ..moveTo(chartLeft, chartBottom)
      ..lineTo(chartLeft + chartWidth, chartBottom);
    canvas.drawPath(
      axes,
      Paint()
        ..color = theme.grid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Y labels: a few evenly spaced ticks (drawing one per distinct value
    // overlaps badly at small canvas sizes).
    for (final value in _tickValues(maxY, 4)) {
      final y = chartBottom - (value / maxY) * (chartBottom - chartTop);
      drawChartText(
        canvas,
        ChartFormatting.format(value),
        Offset(chartLeft - 5, y),
        color: theme.label,
        h: HAlign.end,
        v: VAlign.center,
      );
    }

    // X labels: a few evenly spaced ticks.
    for (final value in _tickValues(maxX, 4)) {
      final x = chartLeft + (value / maxX) * chartWidth;
      drawChartText(
        canvas,
        ChartFormatting.format(value),
        Offset(x, chartBottom + 5),
        color: theme.label,
        h: HAlign.center,
      );
    }

    // Points: radius scales with progress; halo + fill + white ring.
    final p = progress.clamp(0.0, 1.0);
    final pointSize = 6.0 * p;
    if (!(pointSize > 0)) return;

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = chartLeft + (point.x / maxX) * chartWidth;
      final y = chartTop + chartHeight - (point.y / maxY) * chartHeight;
      final center = Offset(x, y);

      // Each point's color travels with it; fall back to the theme palette by
      // position when none is given, so a color can never bind to the wrong dot.
      final color = point.color ?? theme.colorAt(index);

      // Soft translucent halo.
      canvas
        ..drawCircle(
          center,
          pointSize * 2,
          Paint()..color = color.withValues(alpha: 0.16 * p),
        )
        // Crisp filled dot.
        ..drawCircle(
          center,
          pointSize,
          Paint()..color = color.withValues(alpha: p),
        )
        // White ring.
        ..drawCircle(
          center,
          pointSize,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: p)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }
  }

  @override
  String get accessibilityLabel => 'Scatter plot';

  @override
  String get accessibilityValue =>
      points.isEmpty ? 'No data' : '${points.length} points';

  /// Evenly spaced tick values from 0...max (inclusive) for axis labels.
  List<double> _tickValues(double max, int count) {
    if (!(max > 0) || count <= 0) return const [];
    return [for (var i = 0; i <= count; i++) max * i / count];
  }
}

/// A cartesian scatter plot with axis labels and dots that scale in on reveal.
class ScatterPlot extends StatelessWidget {
  const ScatterPlot({
    super.key,
    required this.points,
    this.animate = true,
    this.replay = 0,
  });

  final List<ScatterPoint> points;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: ScatterPlotRenderer(points: points),
    animate: animate,
    duration: const Duration(milliseconds: 2000),
    replay: replay,
  );
}

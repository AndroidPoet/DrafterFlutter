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

import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// One wedge of a [PieChart] / [DonutChart]: its weight, fill color, and label.
class PieSlice {
  const PieSlice({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;
}

/// The total of all slice values, floored at 1 so an empty dataset can't divide
/// by zero (matches the Compose `max(sum, 1f)`).
double _pieTotal(List<PieSlice> slices) {
  final sum = slices.fold(0.0, (a, s) => a + s.value);
  return sum < 1 ? 1 : sum;
}

double _radians(double degrees) => degrees * math.pi / 180;

// ---------------------------------------------------------------------------
// Pie
// ---------------------------------------------------------------------------

/// Draws a list of [PieSlice]s as solid wedges that meet at the center.
class PieChartRenderer extends ChartRenderer {
  const PieChartRenderer({required this.slices, this.labelThreshold = 5});

  final List<PieSlice> slices;
  final double labelThreshold;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    if (slices.isEmpty) return;

    final total = _pieTotal(slices);
    final layout = RadialLayout(size, scale: 0.7);
    final center = layout.center;
    final radius = layout.radius;
    final separator = theme.surface;
    final labelColor = theme.isDark
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    var startAngle = -90.0; // 12 o'clock, sweeping clockwise.

    for (final slice in slices) {
      final fraction = slice.value / total;
      final sweep = fraction * 360 * progress;
      if (sweep <= 0) {
        startAngle += sweep;
        continue;
      }

      final wedge = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(arcRect, _radians(startAngle), _radians(sweep), false)
        ..close();
      canvas
        ..drawPath(wedge, Paint()..color = slice.color)
        ..drawPath(
          wedge,
          Paint()
            ..color = separator
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );

      final percent = fraction * 100;
      if (percent >= labelThreshold) {
        final mid = _radians(startAngle + sweep / 2);
        final p = layout.pointAt(angle: mid, distance: radius * 0.7);
        drawChartText(
          canvas,
          '${percent.toInt()}%',
          p,
          color: labelColor,
          fontSize: 12,
          weight: FontWeight.bold,
          h: HAlign.center,
          v: VAlign.center,
        );
      }

      startAngle += sweep;
    }
  }

  @override
  String get accessibilityLabel => 'Pie chart';

  @override
  String get accessibilityValue => slices.isEmpty
      ? 'No data'
      : '${slices.length} slices, '
            '${AccessibilityFormat.points([for (final s in slices) (s.label, s.value)])}';
}

/// A solid pie chart whose wedges sweep in proportionally on reveal.
class PieChart extends StatelessWidget {
  const PieChart({
    super.key,
    required this.slices,
    this.animate = true,
    this.replay = 0,
  });

  final List<PieSlice> slices;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: PieChartRenderer(slices: slices),
    animate: animate,
    replay: replay,
  );
}

// ---------------------------------------------------------------------------
// Donut
// ---------------------------------------------------------------------------

/// Draws a list of [PieSlice]s as stroked arcs around a hollow center.
class DonutChartRenderer extends ChartRenderer {
  const DonutChartRenderer({
    required this.slices,
    this.labelThreshold = 5,
    this.holeRadiusFraction = 0.5,
  });

  final List<PieSlice> slices;
  final double labelThreshold;
  final double holeRadiusFraction;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    if (slices.isEmpty) return;

    final total = _pieTotal(slices);
    final layout = RadialLayout(size, scale: 0.6);
    final center = layout.center;
    final outerRadius = layout.radius;
    final innerRadius = outerRadius * holeRadiusFraction;
    final bandRadius = (outerRadius + innerRadius) / 2;
    final bandWidth = outerRadius - innerRadius;
    final labelColor = theme.isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    final bandRect = Rect.fromCircle(center: center, radius: bandRadius);

    const gap = 2.0;
    var startAngle = -90.0;

    for (final slice in slices) {
      final fraction = slice.value / total;
      final sweep = fraction * 360 * progress;
      final drawSweep = math.max(sweep - gap, 0.0);
      if (drawSweep > 0) {
        canvas.drawArc(
          bandRect,
          _radians(startAngle + gap / 2),
          _radians(drawSweep),
          false,
          Paint()
            ..color = slice.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = bandWidth
            ..strokeCap = StrokeCap.round,
        );
      }

      final percent = fraction * 100;
      if (percent >= labelThreshold && sweep > 0) {
        final mid = _radians(startAngle + sweep / 2);
        final p = layout.pointAt(angle: mid, distance: outerRadius * 1.22);
        drawChartText(
          canvas,
          '${percent.toInt()}%',
          p,
          color: labelColor,
          fontSize: 12,
          weight: FontWeight.bold,
          h: HAlign.center,
          v: VAlign.center,
        );
      }

      startAngle += sweep;
    }
  }

  @override
  String get accessibilityLabel => 'Donut chart';

  @override
  String get accessibilityValue => slices.isEmpty
      ? 'No data'
      : '${slices.length} slices, '
            '${AccessibilityFormat.points([for (final s in slices) (s.label, s.value)])}';
}

/// A donut chart: stroked arcs around a hollow center, sweeping in on reveal.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.animate = true,
    this.replay = 0,
  });

  final List<PieSlice> slices;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: DonutChartRenderer(slices: slices),
    animate: animate,
    replay: replay,
  );
}

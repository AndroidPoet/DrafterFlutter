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
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// One wedge of a [PieChart] / [DonutChart]: its weight, fill color, and label.
@immutable
class PieSlice {
  /// Creates a wedge with the given [value] weight, [color] fill, and [label].
  const PieSlice({
    required this.value,
    required this.color,
    required this.label,
  });

  /// The slice's weight; its share of the chart is `value / sum(values)`.
  final double value;

  /// The fill color of the wedge.
  final Color color;

  /// The human-readable label for the slice.
  final String label;
}

/// The total of all finite slice values, floored at 1 so an empty dataset can't
/// divide by zero (matches the Compose `max(sum, 1f)`). Non-finite values are
/// skipped so a `NaN`/`Infinity` weight can never poison the total.
double _pieTotal(List<PieSlice> slices) {
  final sum = slices.fold(0.0, (a, s) => s.value.isFinite ? a + s.value : a);
  return sum < 1 ? 1 : sum;
}

double _radians(double degrees) => degrees * math.pi / 180;

/// A solid pie wedge (center → arc → close) for hit-testing, at full sweep.
Path _wedgePath(
  Offset center,
  double radius,
  double startDeg,
  double sweepDeg,
) {
  return Path()
    ..moveTo(center.dx, center.dy)
    ..arcTo(
      Rect.fromCircle(center: center, radius: radius),
      _radians(startDeg),
      _radians(sweepDeg),
      false,
    )
    ..close();
}

/// An annular sector (donut band) between [inner] and [outer] radius.
Path _annularWedge(
  Offset center,
  double inner,
  double outer,
  double startDeg,
  double sweepDeg,
) {
  return Path()
    ..arcTo(
      Rect.fromCircle(center: center, radius: outer),
      _radians(startDeg),
      _radians(sweepDeg),
      true,
    )
    ..arcTo(
      Rect.fromCircle(center: center, radius: inner),
      _radians(startDeg + sweepDeg),
      _radians(-sweepDeg),
      false,
    )
    ..close();
}

// ---------------------------------------------------------------------------
// Pie
// ---------------------------------------------------------------------------

/// Draws a list of [PieSlice]s as solid wedges that meet at the center.
class PieChartRenderer extends ChartRenderer implements InteractiveRenderer {
  /// Creates a renderer for [slices], labeling wedges at or above
  /// [labelThreshold] percent.
  const PieChartRenderer({required this.slices, this.labelThreshold = 5});

  /// The wedges to draw, in order, sweeping clockwise from 12 o'clock.
  final List<PieSlice> slices;

  /// Minimum percentage a slice must reach for its `%` label to be drawn.
  final double labelThreshold;

  @override
  ChartScene buildScene(Size size) {
    if (slices.isEmpty) return ChartScene.empty;
    final total = _pieTotal(slices);
    final layout = RadialLayout(size, scale: 0.7);
    final marks = <PlotMark>[];
    var startAngle = -90.0;
    for (var i = 0; i < slices.length; i++) {
      final fraction = drafterFinite(slices[i].value) / total;
      final sweep = fraction * 360;
      final mid = _radians(startAngle + sweep / 2);
      marks.add(
        PlotMark(
          index: i,
          seriesIndex: 0,
          seriesName: '',
          label: slices[i].label,
          value: slices[i].value,
          center: layout.pointAt(angle: mid, distance: layout.radius * 0.6),
          color: slices[i].color,
          hitPath: _wedgePath(layout.center, layout.radius, startAngle, sweep),
        ),
      );
      startAngle += sweep;
    }
    return ChartScene(
      bounds: ChartBounds(size, padding: 0),
      categories: [for (final s in slices) s.label],
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
      final fraction = drafterFinite(slice.value) / total;
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
  /// Creates a pie chart for [slices].
  const PieChart({
    super.key,
    required this.slices,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 1000),
  });

  /// The wedges to draw, in order.
  final List<PieSlice> slices;

  /// Whether to play the entrance reveal animation.
  final bool animate;

  /// Bump this value to replay the entrance animation.
  final int replay;

  /// Duration of the entrance reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: PieChartRenderer(slices: slices),
    animate: animate,
    replay: replay,
    duration: duration,
  );
}

// ---------------------------------------------------------------------------
// Donut
// ---------------------------------------------------------------------------

/// Draws a list of [PieSlice]s as stroked arcs around a hollow center.
class DonutChartRenderer extends ChartRenderer implements InteractiveRenderer {
  /// Creates a renderer for [slices], labeling bands at or above
  /// [labelThreshold] percent, with a hollow center of [holeRadiusFraction] of
  /// the outer radius.
  const DonutChartRenderer({
    required this.slices,
    this.labelThreshold = 5,
    this.holeRadiusFraction = 0.5,
  });

  /// The wedges to draw, in order, sweeping clockwise from 12 o'clock.
  final List<PieSlice> slices;

  /// Minimum percentage a slice must reach for its `%` label to be drawn.
  final double labelThreshold;

  /// The hole radius as a fraction of the outer radius (0 = full pie, 1 = ring).
  final double holeRadiusFraction;

  @override
  ChartScene buildScene(Size size) {
    if (slices.isEmpty) return ChartScene.empty;
    final total = _pieTotal(slices);
    final layout = RadialLayout(size, scale: 0.6);
    final outerRadius = layout.radius;
    final innerRadius = outerRadius * holeRadiusFraction;
    final bandRadius = (outerRadius + innerRadius) / 2;
    final marks = <PlotMark>[];
    var startAngle = -90.0;
    for (var i = 0; i < slices.length; i++) {
      final fraction = drafterFinite(slices[i].value) / total;
      final sweep = fraction * 360;
      final mid = _radians(startAngle + sweep / 2);
      marks.add(
        PlotMark(
          index: i,
          seriesIndex: 0,
          seriesName: '',
          label: slices[i].label,
          value: slices[i].value,
          center: layout.pointAt(angle: mid, distance: bandRadius),
          color: slices[i].color,
          hitPath: _annularWedge(
            layout.center,
            innerRadius,
            outerRadius,
            startAngle,
            sweep,
          ),
        ),
      );
      startAngle += sweep;
    }
    return ChartScene(
      bounds: ChartBounds(size, padding: 0),
      categories: [for (final s in slices) s.label],
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
      final fraction = drafterFinite(slice.value) / total;
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
  /// Creates a donut chart for [slices].
  const DonutChart({
    super.key,
    required this.slices,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 1000),
  });

  /// The wedges to draw, in order.
  final List<PieSlice> slices;

  /// Whether to play the entrance reveal animation.
  final bool animate;

  /// Bump this value to replay the entrance animation.
  final int replay;

  /// Duration of the entrance reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: DonutChartRenderer(slices: slices),
    animate: animate,
    replay: replay,
    duration: duration,
  );
}

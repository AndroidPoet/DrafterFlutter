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

double _radians(double degrees) => degrees * math.pi / 180;

/// A single wedge in a [PolarAreaChart]: its `label`, magnitude `value`, and `color`.
@immutable
class PolarSlice {
  /// Creates a wedge with the given [label], magnitude [value], and [color].
  const PolarSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  /// The human-readable label for the slice.
  final String label;

  /// The slice's magnitude; the wedge radius is proportional to it.
  final double value;

  /// The fill color of the wedge.
  final Color color;
}

/// Draws polar-area wedges into a canvas as equal-angle, value-radius wedges.
class PolarAreaChartRenderer extends ChartRenderer
    implements InteractiveRenderer {
  /// Creates a renderer for [slices].
  const PolarAreaChartRenderer({required this.slices});

  /// The wedges to draw, in order, sweeping clockwise from 12 o'clock.
  final List<PolarSlice> slices;

  /// The largest finite slice value, used to normalize radii. Non-finite values
  /// are ignored so a `NaN`/`Infinity` magnitude can't poison the scale.
  double maxValue() {
    final finite = slices.map((s) => s.value).where((v) => v.isFinite);
    return finite.isEmpty ? 0 : finite.reduce(math.max);
  }

  @override
  ChartScene buildScene(Size size) {
    // Mirror draw()'s early-returns so degenerate inputs hit-test to nothing.
    if (slices.isEmpty) return ChartScene.empty;
    final layout = RadialLayout(size, scale: 0.72);
    final center = layout.center;
    final maxRadius = layout.radius;
    if (maxRadius <= 0) return ChartScene.empty;

    final maxVal = math.max(maxValue(), 0.0001);
    final sweepPer = 360.0 / slices.length;
    final marks = <PlotMark>[];

    // One mark per wedge at full (un-animated) radius: equal angular sweep,
    // radius proportional to the slice's value. The hit shape is the wedge
    // itself; the focal point sits at the wedge mid-angle, partway out.
    for (var index = 0; index < slices.length; index++) {
      final slice = slices[index];
      final startAngle = -90.0 + index * sweepPer;
      final radius = slice.value / maxVal * maxRadius;
      if (!radius.isFinite) continue;
      final midDeg = startAngle + sweepPer / 2.0;
      final mid = _radians(midDeg);
      marks.add(
        PlotMark(
          index: index,
          seriesIndex: 0,
          seriesName: '',
          label: slice.label,
          value: slice.value,
          center: layout.pointAt(angle: mid, distance: radius * 0.6),
          color: slice.color,
          hitPath: _wedgePath(center, radius, startAngle, sweepPer),
        ),
      );
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

    // Leave room for the outside labels: the demo card is short (~200pt tall),
    // so the constraining half-dimension is small. A 0.72 scale keeps the
    // label ring (maxRadius + 14) inside the canvas top/bottom edges.
    final layout = RadialLayout(size, scale: 0.72);
    final center = layout.center;
    final maxRadius = layout.radius;
    if (maxRadius <= 0) return;

    final maxVal = math.max(maxValue(), 0.0001);
    final sweepPer = 360.0 / slices.length;

    _drawGrid(canvas, center, maxRadius, slices.length, sweepPer, theme.grid);

    // Wedges: equal angle, radius proportional to value, radius animates with progress.
    for (var index = 0; index < slices.length; index++) {
      final slice = slices[index];
      final startAngle = -90.0 + index * sweepPer;
      final targetRadius = slice.value / maxVal * maxRadius;
      final radius = targetRadius * math.min(math.max(progress, 0.0), 1.0);
      if (radius <= 0 || !radius.isFinite) continue;

      final wedge = _wedgePath(center, radius, startAngle, sweepPer);
      canvas
        ..drawPath(
          wedge,
          Paint()..color = slice.color.withValues(alpha: 0.7),
        )
        ..drawPath(
          wedge,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }

    _drawLabels(canvas, center, maxRadius, slices, sweepPer, theme.label);
  }

  @override
  String get accessibilityLabel => 'Polar area chart';

  @override
  String get accessibilityValue => slices.isEmpty
      ? 'No data'
      : '${slices.length} slices, '
            '${AccessibilityFormat.points([for (final s in slices) (s.label, s.value)])}';

  // --- Geometry ---

  /// A pie-style wedge (center -> arc -> center) spanning `sweepDeg` from `startDeg`.
  Path _wedgePath(
    Offset center,
    double radius,
    double startDeg,
    double sweepDeg,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    return Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, _radians(startDeg), _radians(sweepDeg), false)
      ..close();
  }

  // --- Chrome ---

  /// Concentric grid rings plus radial spokes along each wedge boundary.
  void _drawGrid(
    Canvas canvas,
    Offset center,
    double maxRadius,
    int sliceCount,
    double sweepPer,
    Color color,
  ) {
    final gridPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const rings = 4;
    for (var ring = 1; ring <= rings; ring++) {
      final r = maxRadius * ring / rings;
      canvas.drawCircle(center, r, gridPaint);
    }
    for (var i = 0; i < sliceCount; i++) {
      final angle = _radians(-90.0 + i * sweepPer);
      final end = Offset(
        center.dx + math.cos(angle) * maxRadius,
        center.dy + math.sin(angle) * maxRadius,
      );
      canvas.drawLine(center, end, gridPaint);
    }
  }

  /// Wedge labels placed just outside the outer ring, at each wedge's mid-angle.
  void _drawLabels(
    Canvas canvas,
    Offset center,
    double maxRadius,
    List<PolarSlice> slices,
    double sweepPer,
    Color color,
  ) {
    final labelRadius = maxRadius + 14;
    for (var index = 0; index < slices.length; index++) {
      final midDeg = -90.0 + index * sweepPer + sweepPer / 2.0;
      final mid = _radians(midDeg);
      final x = center.dx + math.cos(mid) * labelRadius;
      final y = center.dy + math.sin(mid) * labelRadius;
      drawChartText(
        canvas,
        slices[index].label,
        Offset(x, y),
        color: color,
        fontSize: 10,
        h: HAlign.center,
        v: VAlign.center,
      );
    }
  }
}

/// A polar area (rose) chart: equal-angle wedges whose radius encodes magnitude,
/// revealed by an animated outward growth.
class PolarAreaChart extends StatelessWidget {
  /// Creates a polar area chart for [slices].
  const PolarAreaChart({
    super.key,
    required this.slices,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 900),
  });

  /// The wedges to draw, in order.
  final List<PolarSlice> slices;

  /// Whether to play the entrance reveal animation.
  final bool animate;

  /// Bump this value to replay the entrance animation.
  final int replay;

  /// Duration of the entrance reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: PolarAreaChartRenderer(slices: slices),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}

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

double _radians(double degrees) => degrees * math.pi / 180;

/// One node in a [SunburstChart] hierarchy. Root nodes form the inner ring; their
/// `children` form the outer ring, each subdividing the parent's angular span.
class SunburstNode {
  const SunburstNode({
    required this.label,
    required this.value,
    required this.color,
    this.children = const [],
  });

  final String label;
  final double value;
  final Color color;
  final List<SunburstNode> children;
}

/// Draws a sunburst hierarchy into a canvas as two concentric rings.
class SunburstChartRenderer extends ChartRenderer {
  const SunburstChartRenderer({required this.roots});

  final List<SunburstNode> roots;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    if (roots.isEmpty) return;

    final layout = RadialLayout(size, scale: 0.92);
    final center = layout.center;
    final maxRadius = layout.radius;
    if (!(maxRadius > 0)) return;

    final total = math.max(roots.fold(0.0, (a, b) => a + b.value), 0.0001);

    // Geometry: small center hole, inner ring (roots), outer ring (children).
    final holeRadius = maxRadius * 0.22;
    final innerOuter = maxRadius * 0.60;
    final outerOuter = maxRadius;

    final labelColor = theme.isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

    var cursor = -90.0;
    for (final root in roots) {
      final rootSweep = (root.value / total) * 360 * progress;
      final rootStart = cursor;

      // Inner ring wedge.
      _drawRingWedge(
        canvas: canvas,
        center: center,
        innerRadius: holeRadius,
        outerRadius: innerOuter,
        startAngle: rootStart,
        sweepAngle: rootSweep,
        color: root.color,
      );
      _drawRingLabel(
        canvas: canvas,
        center: center,
        radius: (holeRadius + innerOuter) / 2,
        startAngle: rootStart,
        sweepAngle: rootSweep,
        label: root.label,
        color: labelColor,
      );

      // Outer ring: children subdivide the parent's full angular span.
      final childTotal = math.max(
        root.children.fold(0.0, (a, b) => a + b.value),
        0.0001,
      );
      final fullRootSweep = (root.value / total) * 360;
      var childCursor = rootStart;
      for (final child in root.children) {
        final childSweep =
            (child.value / childTotal) * fullRootSweep * progress;
        // Lighten the child toward white by 30% (matches Compose
        // `lerp(color, White, 0.30)`) by compositing a 30%-opacity white wash
        // over the child color.
        _drawRingWedge(
          canvas: canvas,
          center: center,
          innerRadius: innerOuter,
          outerRadius: outerOuter,
          startAngle: childCursor,
          sweepAngle: childSweep,
          color: child.color,
          tint: const Color(0xFFFFFFFF).withValues(alpha: 0.30),
        );
        _drawRingLabel(
          canvas: canvas,
          center: center,
          radius: (innerOuter + outerOuter) / 2,
          startAngle: childCursor,
          sweepAngle: childSweep,
          label: child.label,
          color: labelColor,
        );
        childCursor += childSweep;
      }

      cursor += rootSweep;
    }
  }

  @override
  String get accessibilityLabel => 'Sunburst chart';

  @override
  String get accessibilityValue =>
      roots.isEmpty ? 'No data' : '${roots.length} root segments';
}

/// Draws an annular wedge as a thick stroked arc along the ring's mid-line, plus
/// a soft white separator stroke at the wedge for crisp segmentation.
void _drawRingWedge({
  required Canvas canvas,
  required Offset center,
  required double innerRadius,
  required double outerRadius,
  required double startAngle,
  required double sweepAngle,
  required Color color,
  Color? tint,
}) {
  if (!(sweepAngle > 0)) return;
  final midRadius = (innerRadius + outerRadius) / 2;
  final thickness = outerRadius - innerRadius;

  final arcRect = Rect.fromCircle(center: center, radius: midRadius);
  final startRad = _radians(startAngle);
  final sweepRad = _radians(sweepAngle);

  canvas.drawArc(
    arcRect,
    startRad,
    sweepRad,
    false,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness,
  );
  // Optional lightening wash composited over the wedge.
  if (tint != null) {
    canvas.drawArc(
      arcRect,
      startRad,
      sweepRad,
      false,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness,
    );
  }
  // Soft white separator stroke along the wedge for crisp segmentation.
  canvas.drawArc(
    arcRect,
    startRad,
    sweepRad,
    false,
    Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
}

/// Draws a centered label at the wedge's mid-angle / mid-radius, but only when
/// the segment is wide enough (>= 18deg) to fit text.
void _drawRingLabel({
  required Canvas canvas,
  required Offset center,
  required double radius,
  required double startAngle,
  required double sweepAngle,
  required String label,
  required Color color,
}) {
  if (!(sweepAngle >= 18)) return;
  final midDeg = startAngle + sweepAngle / 2;
  final midRad = midDeg * math.pi / 180;
  final lx = center.dx + math.cos(midRad) * radius;
  final ly = center.dy + math.sin(midRad) * radius;
  drawChartText(
    canvas,
    label,
    Offset(lx, ly),
    color: color,
    h: HAlign.center,
    v: VAlign.center,
  );
}

/// A hierarchical sunburst chart: inner ring of roots, outer ring of children,
/// drawn clockwise from the top with an animated sweep reveal.
class SunburstChart extends StatelessWidget {
  const SunburstChart({
    super.key,
    required this.roots,
    this.animate = true,
    this.replay = 0,
  });

  final List<SunburstNode> roots;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: SunburstChartRenderer(roots: roots),
    animate: animate,
    duration: const Duration(milliseconds: 900),
    replay: replay,
  );
}

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

import 'package:drafter/src/core/chart_math.dart';
import 'package:flutter/painting.dart';

// ---------------------------------------------------------------------------
// Smooth paths
// ---------------------------------------------------------------------------

/// Builds a smooth cubic-bezier [Path] that passes through every vertex in
/// [points] using a Catmull-Rom spline (tension 0.5). Falls back to straight
/// segments below three points, where a curve is undefined.
Path smoothPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points[0].dx, points[0].dy);
  if (points.length < 3) {
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = points[i - 1 < 0 ? i : i - 1];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = points[i + 2 > points.length - 1 ? i + 1 : i + 2];
    final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
    final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

/// A straight-segment polyline path, used when a series opts out of smoothing.
Path polylinePath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points[0].dx, points[0].dy);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  return path;
}

/// Returns the sub-path of [path] from its start up to fraction [t] in `0..1`,
/// the Flutter equivalent of SwiftUI's `Path.trimmedPath(from:to:)`.
Path trimPath(Path path, double t) {
  final clamped = t.clamp(0.0, 1.0);
  final out = Path();
  for (final metric in path.computeMetrics()) {
    out.addPath(metric.extractPath(0, metric.length * clamped), Offset.zero);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Gradients
// ---------------------------------------------------------------------------

/// A soft vertical gradient shader fading from [color] near [top] to transparent
/// at [bottom]. Mirrors `areaGradient` in the Compose library.
ui.Gradient areaGradientShader(
  Color color, {
  required double top,
  required double bottom,
  double topAlpha = 0.32,
}) {
  return ui.Gradient.linear(
    Offset(0, top),
    Offset(0, bottom),
    [
      color.withValues(alpha: topAlpha),
      color.withValues(alpha: topAlpha * 0.45),
      color.withValues(alpha: 0),
    ],
    const [0.0, 0.5, 1.0],
  );
}

// ---------------------------------------------------------------------------
// Smooth line drawing (with reveal animation)
// ---------------------------------------------------------------------------

/// Draws a single smooth line series with an optional gradient area fill, a
/// tracing left-to-right reveal animation, and an optional highlighted end dot.
/// The Flutter equivalent of `DrawScope.drawSmoothLine`.
void drawSmoothLine(
  Canvas canvas, {
  required List<Offset> points,
  required Color color,
  required double baseline,
  required double progress,
  double strokeWidth = 6,
  bool fill = true,
  bool endDot = true,
  bool smooth = true,
}) {
  if (points.length < 2) return;
  final clamped = progress.clamp(0.0, 1.0);
  final linePath = smooth ? smoothPath(points) : polylinePath(points);

  final startX = points.first.dx;
  final endX = points.last.dx;
  final revealRight = startX + (endX - startX) * clamped;

  // Soft gradient area fill, clipped to the reveal frontier.
  if (fill) {
    var topY = double.infinity;
    for (final p in points) {
      if (p.dy < topY) topY = p.dy;
    }
    final fillPath = Path.from(linePath)
      ..lineTo(endX, baseline)
      ..lineTo(startX, baseline)
      ..close();
    canvas
      ..save()
      ..clipRect(
        Rect.fromLTWH(startX, topY, revealRight - startX, baseline - topY),
      )
      ..drawPath(
        fillPath,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = ui.Gradient.linear(
            Offset(0, topY),
            Offset(0, baseline),
            [
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0.144),
              color.withValues(alpha: 0),
            ],
            const [0.0, 0.5, 1.0],
          ),
      )
      ..restore();
  }

  // Trace the stroke exactly up to the reveal frontier for a clean "drawing" feel.
  final drawn = trimPath(linePath, clamped);
  canvas.drawPath(
    drawn,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  // Glowing dot at the leading edge of the reveal.
  if (endDot && clamped > 0.001) {
    Offset? pos;
    for (final metric in linePath.computeMetrics()) {
      final t = metric.getTangentForOffset(metric.length * clamped);
      if (t != null) pos = t.position;
    }
    if (pos != null) {
      canvas
        ..drawCircle(
          pos,
          strokeWidth * 1.5,
          Paint()..color = const Color(0xFFFFFFFF),
        )
        ..drawCircle(pos, strokeWidth * 0.95, Paint()..color = color);
    }
  }
}

/// Draws a small filled dot with a white halo — used to mark line vertices.
void drawVertexDot(Canvas canvas, Offset center, Color color, double radius) {
  canvas
    ..drawCircle(
      center,
      radius * 1.7,
      Paint()..color = const Color(0xFFFFFFFF),
    )
    ..drawCircle(center, radius, Paint()..color = color);
}

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------

/// Draws [text] anchored at [at] by [h]/[v]. The shared label helper every chart
/// uses (the equivalent of SwiftUI's `context.draw(Text…, at:, anchor:)`).
void drawChartText(
  Canvas canvas,
  String text,
  Offset at, {
  required Color color,
  double fontSize = 9,
  FontWeight weight = FontWeight.normal,
  HAlign h = HAlign.start,
  VAlign v = VAlign.top,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = ChartText.dx(h, painter.width);
  final dy = ChartText.dy(v, painter.height);
  painter.paint(canvas, Offset(at.dx + dx, at.dy + dy));
}

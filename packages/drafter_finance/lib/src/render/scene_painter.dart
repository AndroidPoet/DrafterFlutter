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

import 'package:flutter/widgets.dart' hide TextAlign;

import 'package:drafter_finance_engine/drafter_finance_engine.dart';

/// Converts the engine's packed ARGB into a Flutter [Color].
Color chartColorToFlutter(ChartColor c) =>
    Color.fromARGB(c.alpha, c.red, c.green, c.blue);

/// Builds a smooth cubic-bezier [Path] through every point using a Catmull-Rom
/// spline (tension 0.5). Falls back to straight segments below three points,
/// where a curve is undefined. Mirrors the Compose renderer so the finance
/// series get the same premium, rounded character.
Path _smoothPathThrough(List<FPoint> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points[0].x, points[0].y);
  if (points.length < 3) {
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }
    return path;
  }
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = points[i - 1 < 0 ? i : i - 1];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = points[i + 2 > points.length - 1 ? i + 1 : i + 2];
    final c1x = p1.x + (p2.x - p0.x) / 6;
    final c1y = p1.y + (p2.y - p0.y) / 6;
    final c2x = p2.x - (p3.x - p1.x) / 6;
    final c2y = p2.y - (p3.y - p1.y) / 6;
    path.cubicTo(c1x, c1y, c2x, c2y, p2.x, p2.y);
  }
  return path;
}

/// A straight-segment polyline path, used when a command opts out of smoothing.
Path _polyPathThrough(List<FPoint> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points[0].x, points[0].y);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].x, points[i].y);
  }
  return path;
}

/// Walks a [Scene]'s display list and paints each primitive with native Flutter
/// `Canvas` APIs. This is the entire Flutter renderer — it holds NO chart logic;
/// every coordinate was already computed by the engine. The Compose and SwiftUI
/// renderers are the exact same walk.
///
/// [progress] is a left-to-right reveal in `[0,1]`; `1` draws the whole scene.
/// The scene is clipped to a growing frontier so every series animates in.
///
/// The reveal repaints 60–120×/sec, but a [Scene]'s geometry never changes
/// once built — so every command's `Path`, `Paint`, gradient shader and laid-out
/// `TextPainter` are prepared once and cached against the scene instance (via an
/// [Expando], so they're released when the scene is). Each frame only replays
/// the cached draw ops under the reveal clip.
void drawScene(Canvas canvas, Scene scene, {double progress = 1}) {
  final ops = _preparedOps(scene);
  final clamped = progress.clamp(0.0, 1.0);
  if (clamped >= 1) {
    for (final op in ops) {
      op(canvas);
    }
    return;
  }
  final plot = scene.plot;
  final revealRight = plot.left + (plot.right - plot.left) * clamped;
  canvas.save();
  canvas.clipRect(
    Rect.fromLTRB(plot.left, plot.top, revealRight, plot.bottom),
  );
  for (final op in ops) {
    op(canvas);
  }
  canvas.restore();
}

/// Per-scene cache of prepared draw operations, keyed by the scene instance.
final Expando<List<void Function(Canvas)>> _preparedCache =
    Expando<List<void Function(Canvas)>>('drafterScenePrep');

List<void Function(Canvas)> _preparedOps(Scene scene) =>
    _preparedCache[scene] ??= [
      for (final command in scene.commands) ?_prepareCommand(command),
    ];

/// Builds the (allocation-heavy) draw op for one command once: paths, paints,
/// gradient shaders and text layout are all done here, not per frame. Returns
/// `null` for commands that draw nothing (e.g. a sub-2-point polyline).
void Function(Canvas)? _prepareCommand(DrawCommand command) {
  switch (command) {
    case LineCmd():
      final paint = Paint()
        ..color = chartColorToFlutter(command.color)
        ..strokeWidth = command.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final a = Offset(command.x1, command.y1);
      final b = Offset(command.x2, command.y2);
      return (canvas) => canvas.drawLine(a, b, paint);

    case RectCmd():
      final rect = Rect.fromLTRB(
        command.rect.left,
        command.rect.top,
        command.rect.right,
        command.rect.bottom,
      );
      final paint = Paint()
        ..color = chartColorToFlutter(command.color)
        ..style = command.fill ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = command.strokeWidth;
      if (command.cornerRadius > 0) {
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(command.cornerRadius),
        );
        return (canvas) => canvas.drawRRect(rrect, paint);
      }
      return (canvas) => canvas.drawRect(rect, paint);

    case PolylineCmd():
      if (command.points.length < 2) return null;
      final path = command.smooth
          ? _smoothPathThrough(command.points)
          : _polyPathThrough(command.points);
      final paint = Paint()
        ..color = chartColorToFlutter(command.color)
        ..strokeWidth = command.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      return (canvas) => canvas.drawPath(path, paint);

    case FillPathCmd():
      if (command.points.length < 2) return null;
      final Path path;
      if (command.smooth && command.points.length >= 4) {
        // Curve the data outline, then straight-line down/across the baseline
        // closer points (the last two) so the bottom edge stays flat.
        final body = command.points.sublist(0, command.points.length - 2);
        path = _smoothPathThrough(body);
        for (var i = command.points.length - 2;
            i < command.points.length;
            i++) {
          path.lineTo(command.points[i].x, command.points[i].y);
        }
      } else if (command.smooth) {
        path = _smoothPathThrough(command.points);
      } else {
        path = _polyPathThrough(command.points);
      }
      path.close();
      final paint = Paint()..style = PaintingStyle.fill;
      if (command.gradient) {
        final color = chartColorToFlutter(command.color);
        var top = double.maxFinite;
        var bottom = -double.maxFinite;
        for (final p in command.points) {
          if (p.y < top) top = p.y;
          if (p.y > bottom) bottom = p.y;
        }
        final baseAlpha = color.a;
        paint.shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            color.withValues(alpha: baseAlpha < 0.42 ? 0.42 : baseAlpha),
            color.withValues(alpha: baseAlpha * 0.7),
            color.withValues(alpha: 0),
          ],
          const [0, 0.55, 1],
        );
      } else {
        paint.color = chartColorToFlutter(command.color);
      }
      return (canvas) => canvas.drawPath(path, paint);

    case TextCmd():
      final painter = TextPainter(
        text: TextSpan(
          text: command.text,
          style: TextStyle(
            color: chartColorToFlutter(command.color),
            fontSize: command.sizeSp,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = switch (command.align) {
        TextAlign.start => 0.0,
        TextAlign.center => -painter.width / 2,
        TextAlign.end => -painter.width,
      };
      final at = Offset(command.x + dx, command.y);
      return (canvas) => painter.paint(canvas, at);
  }
}

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
import 'dart:ui';

/// Cross-chart math & layout helpers so no chart re-implements them: axis tick
/// steps, cartesian/radial bounds, and text-alignment offsets. Pure value math.
abstract final class ChartAxis {
  /// A "nice" grid step for a max value, chosen on a log-magnitude basis so
  /// ticks land on 1/2/5 multiples. Mirrors the Compose `calculateGridStep`.
  static double gridStep(double maxValue) {
    if (!(maxValue > 0) || !maxValue.isFinite) return 1;
    final magnitude = (math.log(maxValue) / math.ln10).floorToDouble();
    final base = math.pow(10, magnitude).toDouble();
    if (maxValue / base > 5) return base * 2;
    if (maxValue / base > 2) return base;
    return base / 2;
  }

  /// Evenly spaced tick values from 0...maxValue, inclusive, with `count` steps.
  static List<double> ticks({required double max, required int count}) {
    if (count <= 0) return const [];
    return [for (var i = 0; i <= count; i++) max * i / count];
  }
}

/// The inset plotting rectangle for a cartesian chart (line/bar/scatter).
class ChartBounds {
  /// Insets [size] by a fractional [padding] on every edge (default 10%).
  ChartBounds(Size size, {double padding = 0.1})
    : rect = Rect.fromLTWH(
        size.width * padding,
        size.height * padding,
        size.width - size.width * padding * 2,
        size.height - size.height * padding * 2,
      );

  /// Insets [size] by explicit edge insets (use when axis labels need room).
  ChartBounds.insets(
    Size size, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) : rect = Rect.fromLTWH(
         left,
         top,
         size.width - left - right,
         size.height - top - bottom,
       );

  final Rect rect;

  double get left => rect.left;
  double get top => rect.top;
  double get right => rect.right;
  double get bottom => rect.bottom;
  double get width => rect.width;
  double get height => rect.height;
}

/// Center + radius for a radial chart (pie/gauge/radar/polar/sunburst).
class RadialLayout {
  /// [scale] is the fraction of `min(width,height)/2` the radius fills.
  RadialLayout(Size size, {double scale = 0.8})
    : center = Offset(size.width / 2, size.height / 2),
      radius = math.min(size.width, size.height) / 2 * scale;

  final Offset center;
  final double radius;

  /// The point on a ray at [angle] (radians, 0 = +x, clockwise as y grows down)
  /// at the given [distance] from center.
  Offset pointAt({required double angle, required double distance}) => Offset(
    center.dx + math.cos(angle) * distance,
    center.dy + math.sin(angle) * distance,
  );
}

/// Pads or truncates [labels] to exactly [count] entries, so a mismatched label
/// array can never drive a different number of columns than the data. Missing
/// labels become empty strings; extra labels are dropped.
List<String> normalizedLabels(List<String> labels, int count) {
  if (count <= 0) return const [];
  if (labels.length == count) return labels;
  return [for (var i = 0; i < count; i++) i < labels.length ? labels[i] : ''];
}

/// Horizontal anchor for a label drawn at an origin x.
enum HAlign { start, center, end }

/// Vertical anchor for a label drawn at an origin y.
enum VAlign { top, center, bottom }

abstract final class ChartText {
  /// The dx offset to apply to an origin x so a label of [textWidth] is anchored.
  static double dx(HAlign align, double textWidth) {
    switch (align) {
      case HAlign.start:
        return 0;
      case HAlign.center:
        return -textWidth / 2;
      case HAlign.end:
        return -textWidth;
    }
  }

  /// The dy offset to apply to an origin y so a label of [textHeight] is anchored.
  static double dy(VAlign align, double textHeight) {
    switch (align) {
      case VAlign.top:
        return 0;
      case VAlign.center:
        return -textHeight / 2;
      case VAlign.bottom:
        return -textHeight;
    }
  }
}

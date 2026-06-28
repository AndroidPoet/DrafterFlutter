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

  /// The inset plotting rectangle, in pixels.
  final Rect rect;

  /// The left edge of the plot rectangle.
  double get left => rect.left;

  /// The top edge of the plot rectangle.
  double get top => rect.top;

  /// The right edge of the plot rectangle.
  double get right => rect.right;

  /// The bottom edge of the plot rectangle.
  double get bottom => rect.bottom;

  /// The width of the plot rectangle.
  double get width => rect.width;

  /// The height of the plot rectangle.
  double get height => rect.height;
}

/// The reversible data↔pixel mapping for an index-based cartesian chart
/// (line/area/bar/candlestick). Renderers compute this once and use it for both
/// painting (`xForIndex`/`yForValue`) and hit-testing (`valueForY`/`nearestIndex`),
/// so paint geometry and interaction geometry can never drift apart.
///
/// X is mapped by *index*: [count] evenly spaced columns across [bounds]. Y is a
/// linear value axis from [minValue] (at the bottom) to [maxValue] (at the top).
class CartesianScale {
  /// Creates a scale over [bounds] with [count] columns spanning [minValue] to
  /// [maxValue] on the value axis.
  const CartesianScale({
    required this.bounds,
    required this.count,
    required this.minValue,
    required this.maxValue,
  });

  /// The plot rectangle the scale maps into.
  final ChartBounds bounds;

  /// The number of evenly spaced columns along the x-axis.
  final int count;

  /// The value at the bottom of the y-axis.
  final double minValue;

  /// The value at the top of the y-axis.
  final double maxValue;

  double get _span => maxValue - minValue;

  /// The pixel x of column [index]. A single column is centered; otherwise
  /// columns span the full plot width with `count - 1` equal gaps.
  double xForIndex(int index) {
    if (count <= 1) return bounds.left + bounds.width / 2;
    return bounds.left + bounds.width * index / (count - 1);
  }

  /// The pixel y of data [value] (y grows downward, so larger values sit higher).
  double yForValue(double value) {
    if (_span == 0) return bounds.bottom;
    return bounds.bottom - (value - minValue) / _span * bounds.height;
  }

  /// The data value at pixel [y] — the inverse of [yForValue].
  double valueForY(double y) {
    if (bounds.height == 0) return minValue;
    return minValue + (bounds.bottom - y) / bounds.height * _span;
  }

  /// The column index nearest pixel [px], clamped to `0..count-1`. A non-finite
  /// [px] (which would make `round()` throw) resolves to the first column.
  int nearestIndex(double px) {
    if (count <= 1 || !px.isFinite) return 0;
    final slot = bounds.width / (count - 1);
    if (slot <= 0) return 0;
    final raw = ((px - bounds.left) / slot).round();
    return raw.clamp(0, count - 1);
  }
}

/// Center + radius for a radial chart (pie/gauge/radar/polar/sunburst).
class RadialLayout {
  /// [scale] is the fraction of `min(width,height)/2` the radius fills.
  RadialLayout(Size size, {double scale = 0.8})
    : center = Offset(size.width / 2, size.height / 2),
      radius = math.min(size.width, size.height) / 2 * scale;

  /// The center of the radial chart, in pixels.
  final Offset center;

  /// The outer radius of the radial chart, in pixels.
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
enum HAlign {
  /// Left-align: the origin x is the label's left edge.
  start,

  /// Center the label horizontally on the origin x.
  center,

  /// Right-align: the origin x is the label's right edge.
  end,
}

/// Vertical anchor for a label drawn at an origin y.
enum VAlign {
  /// Top-align: the origin y is the label's top edge.
  top,

  /// Center the label vertically on the origin y.
  center,

  /// Bottom-align: the origin y is the label's bottom edge.
  bottom,
}

/// Text-alignment offset math: converts an [HAlign]/[VAlign] into the pixel
/// delta to apply to a draw origin so a label of a given size anchors correctly.
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

/// Returns [value] when it is finite, otherwise [fallback] (0 by default).
///
/// Renderers funnel raw input values through this at ingestion so an upstream
/// `NaN`/`Infinity` (e.g. from a `0 / 0`) can never reach a `Canvas` primitive
/// or `toInt()` — a non-finite coordinate trips a debug assert, and a non-finite
/// `toInt()` throws `UnsupportedError` even in release builds.
double drafterFinite(double value, [double fallback = 0]) =>
    value.isFinite ? value : fallback;

/// Returns [value] when it is finite, otherwise `null`.
///
/// Useful for filtering non-finite entries out of a value list (e.g. inside a
/// list comprehension) rather than coercing them to a number.
double? drafterFiniteOrNull(double value) => value.isFinite ? value : null;

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

import 'candlestick_engine.dart';
import 'geometry.dart';
import 'linear_scale.dart';
import 'candle.dart';
import 'scene.dart';
import 'series_styles.dart';

/// A clamped, inclusive index range; `null` when there is nothing to draw.
typedef _Range = ({int first, int last});

/// Shared helpers for the value-based series. Kept private — pure geometry.
_Range? _clampWindow(int size, CandleWindow window) {
  if (size == 0) return null;
  final first = window.firstIndex.clamp(0, size - 1);
  final last = window.lastIndex.clamp(first, size - 1);
  return (first: first, last: last);
}

/// A value scale with a little headroom, mapping max -> top of the plot.
LinearScale _valueScale(List<double> values, FRect plot) {
  var lo = double.maxFinite;
  var hi = -double.maxFinite;
  for (final v in values) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  if (lo == double.maxFinite) {
    lo = 0;
    hi = 1;
  }
  if (lo == hi) {
    lo -= 1;
    hi += 1;
  }
  final pad = (hi - lo) * 0.08;
  return LinearScale(
    domainMin: lo - pad,
    domainMax: hi + pad,
    rangeStart: plot.bottom,
    rangeEnd: plot.top,
  );
}

List<FPoint> _points(List<double> values, FRect plot, LinearScale scale) {
  final n = values.length;
  final slot = plot.width / n;
  return [
    for (var i = 0; i < n; i++)
      FPoint(plot.left + slot * i + slot / 2, scale.toPixel(values[i])),
  ];
}

/// A simple line series.
class LineSeriesEngine {
  const LineSeriesEngine._();

  static Scene build(
    List<double> values,
    CandleWindow window,
    FRect plot,
    LineSeriesStyle style,
  ) {
    final range = _clampWindow(values.length, window);
    if (range == null) return Scene(const [], plot);
    final visible = values.sublist(range.first, range.last + 1);
    final scale = _valueScale(visible, plot);
    final pts = _points(visible, plot, scale);
    final commands = pts.length >= 2
        ? <DrawCommand>[
            PolylineCmd(
              points: pts,
              color: style.color,
              strokeWidth: style.lineWidth,
              smooth: style.smooth,
            ),
          ]
        : const <DrawCommand>[];
    return Scene(commands, plot);
  }
}

/// A line with a filled area down to the plot baseline.
class AreaSeriesEngine {
  const AreaSeriesEngine._();

  static Scene build(
    List<double> values,
    CandleWindow window,
    FRect plot,
    AreaSeriesStyle style,
  ) {
    final range = _clampWindow(values.length, window);
    if (range == null) return Scene(const [], plot);
    final visible = values.sublist(range.first, range.last + 1);
    final scale = _valueScale(visible, plot);
    final pts = _points(visible, plot, scale);
    if (pts.length < 2) return Scene(const [], plot);
    final fill = [
      ...pts,
      FPoint(pts.last.x, plot.bottom),
      FPoint(pts.first.x, plot.bottom),
    ];
    return Scene(
      [
        FillPathCmd(
          points: fill,
          color: style.fillColor,
          smooth: style.smooth,
          gradient: true,
        ),
        PolylineCmd(
          points: pts,
          color: style.lineColor,
          strokeWidth: style.lineWidth,
          smooth: style.smooth,
        ),
      ],
      plot,
    );
  }
}

/// A baseline series: line + fill split above/below a [BaselineSeriesStyle.baseValue].
class BaselineSeriesEngine {
  const BaselineSeriesEngine._();

  static Scene build(
    List<double> values,
    CandleWindow window,
    FRect plot,
    BaselineSeriesStyle style,
  ) {
    final range = _clampWindow(values.length, window);
    if (range == null) return Scene(const [], plot);
    final visible = values.sublist(range.first, range.last + 1);
    final scale = _valueScale([...visible, style.baseValue], plot);
    final pts = _points(visible, plot, scale);
    if (pts.length < 2) return Scene(const [], plot);
    final baseY = scale.toPixel(style.baseValue);
    final commands = <DrawCommand>[];

    // Fill from the line down/up to the base line.
    final topFill = [
      ...pts,
      FPoint(pts.last.x, baseY),
      FPoint(pts.first.x, baseY),
    ];
    commands.add(
      FillPathCmd(points: topFill, color: style.topFillColor, gradient: true),
    );

    // Base line.
    commands.add(
      LineCmd(
        x1: plot.left,
        y1: baseY,
        x2: plot.right,
        y2: baseY,
        color: style.bottomLineColor,
        strokeWidth: 1,
      ),
    );

    // Value line, colored per segment by side of the base.
    for (var i = 1; i < pts.length; i++) {
      final mid = (pts[i - 1].y + pts[i].y) / 2;
      final color = mid <= baseY ? style.topLineColor : style.bottomLineColor;
      commands.add(
        LineCmd(
          x1: pts[i - 1].x,
          y1: pts[i - 1].y,
          x2: pts[i].x,
          y2: pts[i].y,
          color: color,
          strokeWidth: style.lineWidth,
        ),
      );
    }
    return Scene(commands, plot);
  }
}

/// A histogram (bars from a base value).
class HistogramSeriesEngine {
  const HistogramSeriesEngine._();

  static Scene build(
    List<double> values,
    CandleWindow window,
    FRect plot,
    HistogramSeriesStyle style,
  ) {
    final range = _clampWindow(values.length, window);
    if (range == null) return Scene(const [], plot);
    final visible = values.sublist(range.first, range.last + 1);
    final scale = _valueScale([...visible, style.baseValue], plot);
    final n = visible.length;
    final slot = plot.width / n;
    final barWidth = math.max(slot * style.barWidthRatio, 1.0);
    final baseY = scale.toPixel(style.baseValue);
    final commands = <DrawCommand>[];
    for (var i = 0; i < visible.length; i++) {
      final v = visible[i];
      final cx = plot.left + slot * i + slot / 2;
      final y = scale.toPixel(v);
      commands.add(
        RectCmd(
          rect: FRect(
            left: cx - barWidth / 2,
            top: math.min(y, baseY),
            right: cx + barWidth / 2,
            bottom: math.max(y, baseY),
          ),
          color: style.color,
          fill: true,
          cornerRadius: style.cornerRadius,
        ),
      );
    }
    return Scene(commands, plot);
  }
}

/// A volume histogram colored by candle direction (up/down).
class VolumeEngine {
  const VolumeEngine._();

  static Scene build(
    List<Candle> candles,
    CandleWindow window,
    FRect plot,
    VolumeStyle style,
  ) {
    final range = _clampWindow(candles.length, window);
    if (range == null) return Scene(const [], plot);
    final visible = candles.sublist(range.first, range.last + 1);
    var maxVol = 0.0;
    for (final c in visible) {
      if (c.volume > maxVol) maxVol = c.volume;
    }
    if (maxVol <= 0) maxVol = 1;
    final scale = LinearScale(
      domainMin: 0,
      domainMax: maxVol,
      rangeStart: plot.bottom,
      rangeEnd: plot.top,
    );
    final n = visible.length;
    final slot = plot.width / n;
    final barWidth = math.max(slot * style.barWidthRatio, 1.0);
    final commands = <DrawCommand>[];
    for (var i = 0; i < visible.length; i++) {
      final c = visible[i];
      final cx = plot.left + slot * i + slot / 2;
      final color = c.close >= c.open ? style.up : style.down;
      commands.add(
        RectCmd(
          rect: FRect(
            left: cx - barWidth / 2,
            top: scale.toPixel(c.volume),
            right: cx + barWidth / 2,
            bottom: plot.bottom,
          ),
          color: color,
          fill: true,
          cornerRadius: style.cornerRadius,
        ),
      );
    }
    return Scene(commands, plot);
  }
}

/// An OHLC bar series (American bars): a high-low stick with open/close ticks.
class BarSeriesEngine {
  const BarSeriesEngine._();

  static Scene build(
    List<Candle> candles,
    CandleWindow window,
    FRect plot,
    BarSeriesStyle style,
  ) {
    final range = _clampWindow(candles.length, window);
    if (range == null) return Scene(const [], plot);
    final visible = candles.sublist(range.first, range.last + 1);
    var minLow = double.maxFinite;
    var maxHigh = -double.maxFinite;
    for (final c in visible) {
      if (c.low < minLow) minLow = c.low;
      if (c.high > maxHigh) maxHigh = c.high;
    }
    final scale = LinearScale(
      domainMin: minLow,
      domainMax: maxHigh,
      rangeStart: plot.bottom,
      rangeEnd: plot.top,
    );
    final n = visible.length;
    final slot = plot.width / n;
    final tick = math.max(slot * style.tickRatio, 2.0);
    final commands = <DrawCommand>[];
    for (var i = 0; i < visible.length; i++) {
      final c = visible[i];
      final cx = plot.left + slot * i + slot / 2;
      final color = c.close >= c.open ? style.up : style.down;
      commands.add(
        LineCmd(
          x1: cx,
          y1: scale.toPixel(c.high),
          x2: cx,
          y2: scale.toPixel(c.low),
          color: color,
          strokeWidth: style.thickness,
        ),
      );
      final openY = scale.toPixel(c.open);
      commands.add(
        LineCmd(
          x1: cx - tick,
          y1: openY,
          x2: cx,
          y2: openY,
          color: color,
          strokeWidth: style.thickness,
        ),
      );
      final closeY = scale.toPixel(c.close);
      commands.add(
        LineCmd(
          x1: cx,
          y1: closeY,
          x2: cx + tick,
          y2: closeY,
          color: color,
          strokeWidth: style.thickness,
        ),
      );
    }
    return Scene(commands, plot);
  }
}

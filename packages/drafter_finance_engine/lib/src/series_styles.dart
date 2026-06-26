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
import 'chart_color.dart';

/// Per-series customization options, modelled on TradingView Lightweight Charts'
/// series option sets — each series exposes the same knobs (colors, widths, base
/// values) so callers get the same level of control.
class LineSeriesStyle {
  const LineSeriesStyle({
    required this.color,
    this.lineWidth = 2,
    this.smooth = true,
  });

  final ChartColor color;
  final double lineWidth;

  /// Curve the line with a Catmull-Rom spline for a smooth, premium feel.
  final bool smooth;

  LineSeriesStyle copyWith({
    ChartColor? color,
    double? lineWidth,
    bool? smooth,
  }) =>
      LineSeriesStyle(
        color: color ?? this.color,
        lineWidth: lineWidth ?? this.lineWidth,
        smooth: smooth ?? this.smooth,
      );
}

class AreaSeriesStyle {
  const AreaSeriesStyle({
    required this.lineColor,
    required this.fillColor,
    this.lineWidth = 2,
    this.smooth = true,
  });

  final ChartColor lineColor;
  final ChartColor fillColor;
  final double lineWidth;

  /// Curve both the line and the fill outline with a Catmull-Rom spline.
  final bool smooth;

  AreaSeriesStyle copyWith({
    ChartColor? lineColor,
    ChartColor? fillColor,
    double? lineWidth,
    bool? smooth,
  }) =>
      AreaSeriesStyle(
        lineColor: lineColor ?? this.lineColor,
        fillColor: fillColor ?? this.fillColor,
        lineWidth: lineWidth ?? this.lineWidth,
        smooth: smooth ?? this.smooth,
      );
}

class BaselineSeriesStyle {
  const BaselineSeriesStyle({
    required this.baseValue,
    required this.topLineColor,
    required this.topFillColor,
    required this.bottomLineColor,
    required this.bottomFillColor,
    this.lineWidth = 2,
  });

  final double baseValue;
  final ChartColor topLineColor;
  final ChartColor topFillColor;
  final ChartColor bottomLineColor;
  final ChartColor bottomFillColor;
  final double lineWidth;
}

class HistogramSeriesStyle {
  const HistogramSeriesStyle({
    required this.color,
    this.baseValue = 0,
    this.barWidthRatio = 0.7,
    this.cornerRadius = 3,
  });

  final ChartColor color;
  final double baseValue;
  final double barWidthRatio;

  /// Rounded-corner radius for each bar, in pixels.
  final double cornerRadius;
}

class BarSeriesStyle {
  const BarSeriesStyle({
    required this.up,
    required this.down,
    this.thickness = 1.5,
    this.tickRatio = 0.3,
  });

  final ChartColor up;
  final ChartColor down;
  final double thickness;
  final double tickRatio;
}

class VolumeStyle {
  const VolumeStyle({
    required this.up,
    required this.down,
    this.barWidthRatio = 0.7,
    this.cornerRadius = 3,
  });

  final ChartColor up;
  final ChartColor down;
  final double barWidthRatio;

  /// Rounded-corner radius for each bar, in pixels.
  final double cornerRadius;
}

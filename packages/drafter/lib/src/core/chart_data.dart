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
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A single labeled data point: one label bound to one value.
///
/// ```dart
/// ChartPoint('Jan', 40)   // labeled
/// ChartPoint.value(40)    // unlabeled
/// ```
@immutable
class ChartPoint {
  /// Creates a labeled point binding [label] to [value].
  const ChartPoint(this.label, this.value);

  /// An unlabeled point (blank x-axis label).
  const ChartPoint.value(this.value) : label = '';

  /// The x-axis label ('' when unlabeled).
  final String label;

  /// The point's value.
  final double value;
}

/// A named, colored series of values for multi-series charts (grouped/stacked
/// lines and bars, stream graphs). The color is bound to the series, so there is
/// no separate `colors` array to fall out of sync.
@immutable
class ChartSeries {
  /// Creates a series of [values] drawn in [color], optionally [name]d.
  const ChartSeries({
    required this.color,
    required this.values,
    this.name = '',
  });

  /// The series name, shown in multi-series tooltip rows ('' when unnamed).
  final String name;

  /// The color the series is drawn in.
  final Color color;

  /// The series' values, one per column.
  final List<double> values;
}

/// A single bar with an optional explicit color (falls back to the theme palette
/// by position when `null`).
@immutable
class BarItem {
  /// Creates a labeled bar of [value] with an optional [color].
  const BarItem(this.label, this.value, {this.color});

  /// An unlabeled bar.
  const BarItem.value(this.value, {this.color}) : label = '';

  /// The bar's x-axis label ('' when unlabeled).
  final String label;

  /// The bar's value (its height).
  final double value;

  /// The bar's color, or `null` to use the theme palette by position.
  final Color? color;
}

/// A single waterfall step: a labeled incremental change with an optional color.
@immutable
class WaterfallStep {
  /// Creates a step labeled [label] changing the running total by [value], with
  /// an optional [color].
  const WaterfallStep(this.label, this.value, {this.color});

  /// The step's label.
  final String label;

  /// The signed change this step applies to the running total.
  final double value;

  /// The step's color, or `null` to use a default (rise/fall) color.
  final Color? color;
}

/// A single scatter point with an optional explicit color.
@immutable
class ScatterPoint {
  /// Creates a point at ([x], [y]) with an optional [color].
  const ScatterPoint({required this.x, required this.y, this.color});

  /// The point's x value.
  final double x;

  /// The point's y value.
  final double y;

  /// The point's color, or `null` to use the theme palette.
  final Color? color;
}

/// A radar series: a color bound to a set of axis → value readings. Axes are
/// keyed by name, so a value can never bind to the wrong axis.
@immutable
class RadarSeries {
  /// Creates a radar series drawn in [color] with axis-name → reading [values].
  const RadarSeries({required this.color, required this.values});

  /// The color the series is drawn in.
  final Color color;

  /// The axis-name → reading map for this series.
  final Map<String, double> values;
}

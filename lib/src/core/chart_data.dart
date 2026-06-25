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
import 'package:flutter/painting.dart';

/// A single labeled data point: one label bound to one value.
///
/// ```dart
/// ChartPoint('Jan', 40)   // labeled
/// ChartPoint.value(40)    // unlabeled
/// ```
class ChartPoint {
  const ChartPoint(this.label, this.value);

  /// An unlabeled point (blank x-axis label).
  const ChartPoint.value(this.value) : label = '';

  final String label;
  final double value;
}

/// A named, colored series of values for multi-series charts (grouped/stacked
/// lines and bars, stream graphs). The color is bound to the series, so there is
/// no separate `colors` array to fall out of sync.
class ChartSeries {
  const ChartSeries({
    this.name = '',
    required this.color,
    required this.values,
  });

  final String name;
  final Color color;
  final List<double> values;
}

/// A single bar with an optional explicit color (falls back to the theme palette
/// by position when `null`).
class BarItem {
  const BarItem(this.label, this.value, {this.color});

  /// An unlabeled bar.
  const BarItem.value(this.value, {this.color}) : label = '';

  final String label;
  final double value;
  final Color? color;
}

/// A single waterfall step: a labeled incremental change with an optional color.
class WaterfallStep {
  const WaterfallStep(this.label, this.value, {this.color});

  final String label;
  final double value;
  final Color? color;
}

/// A single scatter point with an optional explicit color.
class ScatterPoint {
  const ScatterPoint({required this.x, required this.y, this.color});

  final double x;
  final double y;
  final Color? color;
}

/// A radar series: a color bound to a set of axis → value readings. Axes are
/// keyed by name, so a value can never bind to the wrong axis.
class RadarSeries {
  const RadarSeries({required this.color, required this.values});

  final Color color;
  final Map<String, double> values;
}

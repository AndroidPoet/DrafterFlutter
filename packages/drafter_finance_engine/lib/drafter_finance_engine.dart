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

/// Drafter Finance Engine — the pure, UI-free core of the trading-chart SDK.
///
/// This package has **zero Flutter dependency**: it holds all the scales,
/// viewport math, indicators and hit-testing, and emits a platform-agnostic
/// display list ([Scene]) of draw primitives in pixel coordinates. The Flutter
/// `drafter_finance` package (and the Compose / SwiftUI ports) are thin
/// renderers that just walk that list. Shared golden numbers keep every port in
/// lockstep.
library;

export 'src/candle.dart';
export 'src/candlestick_engine.dart'
    show CandleWindow, MaConfig, CandleStyle, CandlestickEngine;
export 'src/chart_color.dart';
export 'src/crosshair.dart';
export 'src/finance_themes.dart';
export 'src/geometry.dart';
export 'src/indicators.dart';
export 'src/linear_scale.dart';
export 'src/scene.dart';
export 'src/series_engines.dart'
    show
        LineSeriesEngine,
        AreaSeriesEngine,
        BaselineSeriesEngine,
        HistogramSeriesEngine,
        VolumeEngine,
        BarSeriesEngine;
export 'src/series_styles.dart';

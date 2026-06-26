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

/// Drafter Finance — native, multiplatform trading charts for Flutter.
///
/// A thin `CustomPainter` renderer over the pure `drafter_finance_engine`: every
/// coordinate and indicator value is computed by the platform-agnostic engine,
/// and the Flutter layer just walks the resulting display list. Same
/// architecture as the Compose and SwiftUI SDKs; shared golden numbers keep all
/// three ports in lockstep.
library;

// Re-export the whole pure engine so consumers get the models, styles and
// themes from a single import.
export 'package:drafter_finance_engine/drafter_finance_engine.dart';

// Flutter renderer + widgets.
export 'src/render/scene_painter.dart' show drawScene, chartColorToFlutter;
export 'src/widgets/finance_candlestick_chart.dart';
export 'src/widgets/finance_series_charts.dart';

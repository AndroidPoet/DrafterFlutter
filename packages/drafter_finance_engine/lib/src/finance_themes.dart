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
import 'candlestick_engine.dart';
import 'chart_color.dart';
import 'series_styles.dart';

/// Ready-made color palettes for every series, supplied as plain style factories.
///
/// Two presets ship in the box; both live here, in the shared engine, so the
/// Flutter, Compose and SwiftUI renderers draw byte-identical colors:
///
/// - [DrafterTheme] — the default. A calm, premium palette (green / coral / indigo)
///   with MA5/10/20 overlays on candles.
/// - [TradingViewTheme] — TradingView Lightweight Charts' exact default colors
///   (up `#26a69a`, down `#ef5350`, line `#2196f3`, …) for a pixel-faithful look.
///
/// Every factory just returns a `*SeriesStyle`, so callers keep full per-field
/// customization — pass a preset, then `copyWith(...)` whatever you want to override.
abstract class FinanceTheme {
  const FinanceTheme();

  CandleStyle candle({bool withMovingAverages = true});
  BarSeriesStyle bar();
  LineSeriesStyle line();
  AreaSeriesStyle area();
  BaselineSeriesStyle baseline(double baseValue);
  HistogramSeriesStyle histogram();
  VolumeStyle volume();
}

/// The default Drafter palette — calm premium tones, no red.
class DrafterTheme extends FinanceTheme {
  const DrafterTheme._();

  static const DrafterTheme instance = DrafterTheme._();

  static final ChartColor _up = ChartColor.rgba(0x49, 0xC1, 0x7A);
  static final ChartColor _down = ChartColor.rgba(0xF2, 0x76, 0x6B);
  static final ChartColor _ma5 = ChartColor.rgba(0xF6, 0xB2, 0x4C);
  static final ChartColor _ma10 = ChartColor.rgba(0x4C, 0x8D, 0xF6);
  static final ChartColor _ma20 = ChartColor.rgba(0x7C, 0x6B, 0xF2);
  static final ChartColor _line = ChartColor.rgba(0x4C, 0x8D, 0xF6);
  static final ChartColor _area = ChartColor.rgba(0x5B, 0x6B, 0xF0);
  static final ChartColor _hist = ChartColor.rgba(0x2F, 0xC4, 0xC0);

  @override
  CandleStyle candle({bool withMovingAverages = true}) => CandleStyle(
        up: _up,
        down: _down,
        movingAverages: withMovingAverages
            ? [MaConfig(5, _ma5), MaConfig(10, _ma10), MaConfig(20, _ma20)]
            : const [],
      );

  @override
  BarSeriesStyle bar() => BarSeriesStyle(up: _up, down: _down);

  @override
  LineSeriesStyle line() => LineSeriesStyle(color: _line);

  @override
  AreaSeriesStyle area() => AreaSeriesStyle(
        lineColor: _area,
        fillColor: _area.copyWith(argb: (_area.argb & 0xFFFFFF) | (0x59 << 24)),
      );

  @override
  BaselineSeriesStyle baseline(double baseValue) => BaselineSeriesStyle(
        baseValue: baseValue,
        topLineColor: _up,
        topFillColor: ChartColor.rgba(_up.red, _up.green, _up.blue, 0x4D),
        bottomLineColor: _down,
        bottomFillColor:
            ChartColor.rgba(_down.red, _down.green, _down.blue, 0x4D),
      );

  @override
  HistogramSeriesStyle histogram() => HistogramSeriesStyle(color: _hist);

  @override
  VolumeStyle volume() => VolumeStyle(
        up: ChartColor.rgba(_up.red, _up.green, _up.blue, 0xCC),
        down: ChartColor.rgba(_down.red, _down.green, _down.blue, 0xCC),
      );
}

/// TradingView Lightweight Charts' exact default colors. Down candles are red
/// (`#ef5350`), matching TradingView pixel-for-pixel — opt in by passing this
/// theme. There are no MA overlays (Lightweight Charts has none by default).
class TradingViewTheme extends FinanceTheme {
  const TradingViewTheme._();

  static const TradingViewTheme instance = TradingViewTheme._();

  static final ChartColor _up = ChartColor.rgba(38, 166, 154); // #26a69a
  static final ChartColor _down = ChartColor.rgba(239, 83, 80); // #ef5350
  static final ChartColor _line = ChartColor.rgba(33, 150, 243); // #2196f3
  static final ChartColor _areaLine = ChartColor.rgba(51, 215, 120); // #33D778
  static final ChartColor _areaFill =
      ChartColor.rgba(46, 220, 135, 0x66); // rgba(46,220,135,0.4)

  @override
  CandleStyle candle({bool withMovingAverages = true}) =>
      CandleStyle(up: _up, down: _down);

  @override
  BarSeriesStyle bar() => BarSeriesStyle(up: _up, down: _down);

  @override
  LineSeriesStyle line() => LineSeriesStyle(color: _line, lineWidth: 3);

  @override
  AreaSeriesStyle area() =>
      AreaSeriesStyle(lineColor: _areaLine, fillColor: _areaFill, lineWidth: 3);

  @override
  BaselineSeriesStyle baseline(double baseValue) => BaselineSeriesStyle(
        baseValue: baseValue,
        topLineColor: _up,
        topFillColor: ChartColor.rgba(38, 166, 154, 0x47),
        bottomLineColor: _down,
        bottomFillColor: ChartColor.rgba(239, 83, 80, 0x47),
      );

  @override
  HistogramSeriesStyle histogram() => HistogramSeriesStyle(color: _up);

  @override
  VolumeStyle volume() => VolumeStyle(
        up: ChartColor.rgba(_up.red, _up.green, _up.blue, 0xCC),
        down: ChartColor.rgba(_down.red, _down.green, _down.blue, 0xCC),
      );
}

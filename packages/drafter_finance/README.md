# drafter_finance

Native, multiplatform **trading charts** for Flutter — candlestick / K-line, OHLC
bars, line, area, baseline, histogram and volume — with technical indicators
(SMA / EMA / RSI / MACD / Bollinger) and a magnet crosshair. No WebView.

The Flutter port of the Drafter Finance SDK. It shares its architecture — and its
**golden numbers** — with the Compose (Kotlin) and SwiftUI ports, so all three
render identically.

## Architecture

A thin `CustomPainter` over the pure-Dart
[`drafter_finance_engine`](https://pub.dev/packages/drafter_finance_engine):

- **Engine** — scales, viewport, indicators, crosshair hit-testing. No Flutter
  import; emits a platform-agnostic display list (`Scene`).
- **Renderer (this package)** — walks the display list with native `Canvas` APIs
  (Catmull-Rom smoothing, soft gradient fills, a left-to-right reveal animation),
  with a per-scene draw-op cache so the reveal stays allocation-free per frame.

## Usage

```dart
import 'package:drafter_finance/drafter_finance.dart';

// Candlestick with a magnet crosshair (drag to scrub):
FinanceCandlestickChart(candles: candles);

// TradingView color preset:
FinanceCandlestickChart(
  candles: candles,
  style: TradingViewTheme.instance.candle(),
);

// Value-series charts:
FinanceLineChart(values: closes);
FinanceAreaChart(values: closes);
FinanceBaselineChart(values: closes, style: DrafterTheme.instance.baseline(closes.first));
FinanceHistogramChart(values: changes);
FinanceVolumeChart(candles: candles);
FinanceBarChart(candles: candles);
```

Two themes ship in the box: `DrafterTheme` (calm premium palette, MA overlays)
and `TradingViewTheme` (TradingView Lightweight Charts' exact default colors).
Every style is a value you can `copyWith(...)` to customize.

See the [`example`](example/) for a runnable demo of every chart type.

## License

Apache 2.0 — see [LICENSE](LICENSE).

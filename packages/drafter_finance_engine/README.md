# drafter_finance_engine

The pure, UI-free engine behind [`drafter_finance`](https://pub.dev/packages/drafter_finance) —
native trading charts for Flutter.

This package has **zero Flutter dependency**. It does all the hard 80% of a
trading chart — scales, viewport math, technical indicators, crosshair
hit-testing — and emits a platform-agnostic **display list** (`Scene`) of draw
primitives in pixel coordinates. A renderer (the `drafter_finance` package on
Flutter, plus the Compose and SwiftUI ports) just walks that list.

Because it's plain Dart, `dart test` runs the full engine suite with no Flutter
toolchain. It is the canonical cross-language spec: the same fixed inputs produce
the same indicator arrays and scene shapes in the Kotlin and Swift engines.

## What's inside

- **Indicators** — SMA, EMA, RSI, MACD, Bollinger Bands.
- **Scales & viewport** — linear scales, padded value ranges, windowing.
- **Engines** — candlestick, OHLC bar, line, area, baseline, histogram, volume.
- **Crosshair** — pointer-to-candle snapping and price read-out math.
- **Display list** — `Scene` + `DrawCommand`s (line / rect / polyline / fill-path
  / text) in absolute pixel coordinates.

## Usage

```dart
import 'package:drafter_finance_engine/drafter_finance_engine.dart';

final rsi = Indicators.rsi(closes, period: 14);
final scene = CandlestickEngine.build(candles, window, plot, style);
// hand `scene` to any renderer
```

If you're building a Flutter app, depend on **`drafter_finance`** instead — it
bundles this engine and the `CustomPainter` widgets.

## License

Apache 2.0 — see [LICENSE](LICENSE).

# drafter_finance_engine

The pure, UI-free engine behind [`drafter_finance`](https://pub.dev/packages/drafter_finance) —
native trading charts for Flutter.

This package has **zero Flutter dependency**. It does the hard 80% of a trading
chart — scales, viewport math, technical indicators, crosshair hit-testing — and
emits a platform-agnostic **display list** (`Scene`): a flat list of draw
primitives already laid out in pixel coordinates. A *renderer* just walks that
list. Because it's plain Dart, `dart test` runs the whole thing with no Flutter
toolchain.

## Which package do I want?

```
┌─────────────────────────┐    produces a Scene     ┌─────────────────────────┐
│  drafter_finance_engine  │ ──────────────────────► │   a renderer            │
│  (pure Dart — this pkg)  │  (pixel-space draw list)│   walks Scene.commands   │
└─────────────────────────┘                          └─────────────────────────┘
        math + layout                                  drawing to a canvas
```

- **Building a Flutter app?** Use **[`drafter_finance`](https://pub.dev/packages/drafter_finance)** —
  it bundles this engine *and* the `CustomPainter` widgets. You never touch the
  engine directly; just drop in `FinanceCandlestickChart(candles: …)`.
- **Use this engine directly when** you're (a) writing your *own* renderer (a
  different toolkit, a server-side raster, a `dart:html` canvas), (b) computing
  indicators with no UI at all, or (c) porting/validating against the Kotlin and
  Swift engines — the three share golden fixtures, so identical inputs give
  identical numbers.

## Install

```bash
dart pub add drafter_finance_engine
```

```dart
import 'package:drafter_finance_engine/drafter_finance_engine.dart';
```

## 1. Indicators (no chart needed)

Each returns a `List<double?>` the same length as the input — `null` during the
warm-up window where the indicator isn't defined yet.

```dart
final closes = [100.0, 104, 103, 107, 110, 108, 112, 111, 115, 118];

final sma = Indicators.sma(closes, 5);
final ema = Indicators.ema(closes, 5);
final rsi = Indicators.rsi(closes);                       // period defaults to 14

final macd = Indicators.macd(closes);                     // fast 12 / slow 26 / signal 9
macd.macd; macd.signal; macd.histogram;                   // each a List<double?>

final bb = Indicators.bollinger(closes, period: 20, mult: 2);
bb.middle; bb.upper; bb.lower;
```

## 2. Build a Scene

Every engine's `build(...)` takes your data, a **window** (the visible index
range), a **plot** (the pixel rectangle to draw into), and a **style**, and
returns a `Scene`.

```dart
const candles = [
  Candle(time: 0, open: 100, high: 106, low: 98,  close: 104, volume: 1200),
  Candle(time: 1, open: 104, high: 109, low: 102, close: 103, volume: 980),
  Candle(time: 2, open: 103, high: 108, low: 100, close: 107, volume: 1500),
  Candle(time: 3, open: 107, high: 112, low: 105, close: 110, volume: 1100),
];

const window = CandleWindow(0, 3);                         // first..last index shown
const plot = FRect(left: 8, top: 8, right: 320, bottom: 200);  // pixels

final candleScene = CandlestickEngine.build(
  candles, window, plot,
  DrafterTheme.instance.candle(),                          // or TradingViewTheme.instance.candle()
);

// Value-series engines take a List<double> instead of candles:
final closes = [for (final c in candles) c.close];
final lineScene = LineSeriesEngine.build(
  closes, window, plot, DrafterTheme.instance.line(),
);
```

Engines available: `CandlestickEngine`, `LineSeriesEngine`, `AreaSeriesEngine`,
`BaselineSeriesEngine`, `HistogramSeriesEngine`, `VolumeEngine`, `BarSeriesEngine`.

## 3. Render a Scene (write your own renderer)

A renderer is just a `switch` over the five `DrawCommand` types. Every
coordinate is already in pixels inside `plot`, and `ChartColor` packs ARGB
(`.argb`, or `.red` / `.green` / `.blue` / `.alpha`). Map each to your canvas:

```dart
void render(MyCanvas canvas, Scene scene) {
  for (final cmd in scene.commands) {
    switch (cmd) {
      case LineCmd():
        canvas.line(cmd.x1, cmd.y1, cmd.x2, cmd.y2, cmd.color, cmd.strokeWidth);
      case RectCmd():
        canvas.rect(cmd.rect, cmd.color, fill: cmd.fill, radius: cmd.cornerRadius);
      case PolylineCmd():
        canvas.polyline(cmd.points, cmd.color, cmd.strokeWidth, smooth: cmd.smooth);
      case FillPathCmd():
        canvas.fillPath(cmd.points, cmd.color, smooth: cmd.smooth, gradient: cmd.gradient);
      case TextCmd():
        canvas.text(cmd.text, cmd.x, cmd.y, cmd.color, cmd.sizeSp, cmd.align);
    }
  }
}
```

That's the entire contract. The Flutter `drafter_finance` package is literally
this switch over a real `Canvas`; the Compose and SwiftUI ports are the same
switch over *their* canvas. To target a new platform you only write this walk —
never the chart math.

## 4. Crosshair hit-testing

Map a pointer x-position to the nearest candle (snapping + read-out):

```dart
final hit = Crosshair.resolve(pointerX, candles, window, plot);
if (hit != null) {
  hit.index;      // candle index under the pointer
  hit.snappedX;   // x to draw the vertical crosshair line at
  hit.candle;     // the Candle, for an OHLC read-out
}
```

## How the two libraries fit together

`drafter_finance_engine` and `drafter_finance` are two halves of one design:

| | `drafter_finance_engine` (this) | `drafter_finance` |
|---|---|---|
| Depends on | nothing but Dart | Flutter + this engine |
| Job | math + layout → `Scene` | walk `Scene` → `Canvas` |
| Use directly when | writing a renderer / headless indicators | building a Flutter UI |

In a Flutter app you just add `drafter_finance` — it depends on this engine
transitively, so a `FinanceCandlestickChart` widget runs `CandlestickEngine.build`
under the hood and paints the resulting `Scene`. You'd reach for this package on
its own only to compute indicators without a UI, or to render the `Scene` with
something other than Flutter's `Canvas`.

## Type reference

| Type | What it is |
|---|---|
| `Candle` | `time, open, high, low, close, volume` |
| `CandleWindow(first, last)` | the visible index range |
| `FRect{left,top,right,bottom}` / `FPoint(x, y)` | pixel geometry |
| `Scene` | `commands` (the draw list) + `plot` |
| `LineCmd` `RectCmd` `PolylineCmd` `FillPathCmd` `TextCmd` | the draw primitives |
| `ChartColor` | packed ARGB (`.argb`, `.red`, `.green`, `.blue`, `.alpha`) |
| `DrafterTheme` / `TradingViewTheme` | ready-made style sets |

## License

Apache 2.0 — see [LICENSE](LICENSE).

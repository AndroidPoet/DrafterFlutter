## 0.1.0

Initial release — native trading charts for Flutter.

* Charts: candlestick / K-line, OHLC bars, line, area, baseline, histogram, volume.
* Magnet crosshair on candlesticks with OHLC + price read-out.
* Two built-in themes: `DrafterTheme` (with MA overlays) and `TradingViewTheme`;
  every style is `copyWith`-customizable.
* Catmull-Rom smoothing, soft gradient fills and a left-to-right reveal animation.
* Per-scene draw-op cache keeps the reveal animation allocation-free per frame.

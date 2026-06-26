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
import 'package:flutter/widgets.dart';

import 'package:drafter_finance_engine/drafter_finance_engine.dart';
import '../render/scene_painter.dart';

/// Default trading style — green/coral candles with MA5/MA10/MA20 overlays.
CandleStyle defaultCandleStyle({bool withMovingAverages = true}) =>
    DrafterTheme.instance.candle(withMovingAverages: withMovingAverages);

/// An interactive candlestick / K-line chart. All geometry and indicator math
/// come from the pure engine; this widget only draws the resulting display list
/// and overlays a scrub crosshair. The Compose and SwiftUI SDKs mirror it 1:1.
///
/// [candles] is an OHLC series, oldest first. [showCrosshair] draws a magnet
/// crosshair + OHLC read-out while dragging.
class FinanceCandlestickChart extends StatefulWidget {
  const FinanceCandlestickChart({
    super.key,
    required this.candles,
    this.style,
    this.showCrosshair = true,
  });

  final List<Candle> candles;
  final CandleStyle? style;
  final bool showCrosshair;

  @override
  State<FinanceCandlestickChart> createState() =>
      _FinanceCandlestickChartState();
}

class _FinanceCandlestickChartState extends State<FinanceCandlestickChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _reveal =
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn);

  Offset? _cursor;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(FinanceCandlestickChart old) {
    super.didUpdateWidget(old);
    if (old.candles.length != widget.candles.length) {
      _cursor = null;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setCursor(Offset? p) => setState(() => _cursor = p);

  // The reveal animation and crosshair drags both repaint, but the candle
  // scene only depends on (size, candles, style) — memoize it so the engine
  // runs once instead of every frame.
  Scene? _scene;
  Size? _sceneSize;
  List<Candle>? _sceneCandles;
  Object? _sceneStyleSrc;

  Scene _sceneFor(Size size, CandleStyle style) {
    if (_scene == null ||
        _sceneSize != size ||
        !identical(_sceneCandles, widget.candles) ||
        !identical(_sceneStyleSrc, widget.style)) {
      final plot = FRect(
        left: 8,
        top: 8,
        right: size.width - 56,
        bottom: size.height - 8,
      );
      final window = CandleWindow(0, widget.candles.length - 1);
      _scene = CandlestickEngine.build(widget.candles, window, plot, style);
      _sceneSize = size;
      _sceneCandles = widget.candles;
      _sceneStyleSrc = widget.style;
    }
    return _scene!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) return const SizedBox.expand();
    final style = widget.style ?? defaultCandleStyle();
    return GestureDetector(
      onTapDown: (d) => _setCursor(d.localPosition),
      onPanStart: (d) => _setCursor(d.localPosition),
      onPanUpdate: (d) => _setCursor(d.localPosition),
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _CandlestickPainter(
            sceneFor: (size) => _sceneFor(size, style),
            candles: widget.candles,
            style: style,
            showCrosshair: widget.showCrosshair,
            cursor: _cursor,
            progress: _reveal.value,
          ),
        ),
      ),
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  _CandlestickPainter({
    required this.sceneFor,
    required this.candles,
    required this.style,
    required this.showCrosshair,
    required this.cursor,
    required this.progress,
  });

  /// Returns the (memoized) candlestick scene for a canvas size, so the engine
  /// isn't re-run on every one of the reveal animation's 60–120 frames/sec.
  final Scene Function(Size size) sceneFor;
  final List<Candle> candles;
  final CandleStyle style;
  final bool showCrosshair;
  final Offset? cursor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || candles.isEmpty) return;
    final plot = FRect(
      left: 8,
      top: 8,
      right: size.width - 56,
      bottom: size.height - 8,
    );
    final window = CandleWindow(0, candles.length - 1);
    drawScene(canvas, sceneFor(size), progress: progress);

    final c = cursor;
    if (showCrosshair && c != null) {
      _drawCrosshair(canvas, c, window, plot);
    }
  }

  void _drawCrosshair(
    Canvas canvas,
    Offset cursor,
    CandleWindow window,
    FRect plot,
  ) {
    final result = Crosshair.resolve(cursor.dx, candles, window, plot);
    if (result == null) return;
    const lineColor = Color(0xFF8A92A2);
    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final clampedY = cursor.dy.clamp(plot.top, plot.bottom);

    // Vertical (snapped to candle) + horizontal (free at cursor) crosshair lines.
    canvas.drawLine(
      Offset(result.snappedX, plot.top),
      Offset(result.snappedX, plot.bottom),
      linePaint,
    );
    canvas.drawLine(
      Offset(plot.left, clampedY),
      Offset(plot.right, clampedY),
      linePaint,
    );

    // Price read-out at the right gutter, mapped from cursor y.
    final span = (plot.bottom - plot.top) == 0 ? 1.0 : (plot.bottom - plot.top);
    final lastIdx = candles.length - 1;
    final visible = candles.sublist(
      window.firstIndex.clamp(0, lastIdx),
      window.lastIndex.clamp(0, lastIdx) + 1,
    );
    var minLow = double.maxFinite;
    var maxHigh = -double.maxFinite;
    for (final cd in visible) {
      if (cd.low < minLow) minLow = cd.low;
      if (cd.high > maxHigh) maxHigh = cd.high;
    }
    final price = maxHigh - (clampedY - plot.top) / span * (maxHigh - minLow);
    _drawText(
      canvas,
      _formatPrice(price),
      Offset(plot.right + 4, clampedY - 7),
      const Color(0xFF1B1E25),
    );

    // OHLC read-out for the snapped candle, top-left.
    final cd = result.candle;
    final ohlc =
        'O ${_formatPrice(cd.open)}  H ${_formatPrice(cd.high)}  '
        'L ${_formatPrice(cd.low)}  C ${_formatPrice(cd.close)}';
    _drawText(
      canvas,
      ohlc,
      Offset(plot.left + 2, plot.top + 2),
      const Color(0xFF1B1E25),
    );
  }

  void _drawText(Canvas canvas, String text, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  static String _formatPrice(double value) {
    final scaled = (value * 100).round();
    final whole = scaled ~/ 100;
    final frac = (scaled < 0 ? -scaled : scaled) % 100;
    final fracStr = frac < 10 ? '0$frac' : '$frac';
    return '$whole.$fracStr';
  }

  @override
  bool shouldRepaint(_CandlestickPainter old) =>
      old.progress != progress ||
      old.cursor != cursor ||
      old.candles != candles ||
      old.style != style ||
      old.showCrosshair != showCrosshair;
}

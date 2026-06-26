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

/// The padded plot rectangle used by every value-based series.
FRect _plotOf(double width, double height) =>
    FRect(left: 8, top: 8, right: width - 8, bottom: height - 8);

/// A scene-painting [CustomPainter] that reveals left-to-right via [progress].
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.build, this.progress);

  /// Builds the scene for a given canvas size (so we react to layout changes).
  final Scene Function(Size size) build;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    drawScene(canvas, build(size), progress: progress);
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.progress != progress || old.build != build;
}

/// Internal host that runs the shared "draw-in" reveal whenever [revealKey]
/// changes and paints [build]'s scene. Gives every series the same premium
/// entrance the Compose SDK uses (1600ms, fast-out-slow-in).
class _RevealChart extends StatefulWidget {
  const _RevealChart({required this.revealKey, required this.build});

  final Object? revealKey;
  final Scene Function(Size size) build;

  @override
  State<_RevealChart> createState() => _RevealChartState();
}

class _RevealChartState extends State<_RevealChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _reveal =
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(_RevealChart old) {
    super.didUpdateWidget(old);
    if (old.revealKey != widget.revealKey) {
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

  // The reveal animation repaints 60–120×/sec, but the scene itself only
  // changes when the size or the data closure changes — so build it once and
  // memoize it, rather than recomputing every spline/metric every frame.
  Scene? _scene;
  Size? _sceneSize;
  Object? _sceneBuild;

  Scene _sceneFor(Size size) {
    if (_scene == null ||
        _sceneSize != size ||
        !identical(_sceneBuild, widget.build)) {
      _scene = widget.build(size);
      _sceneSize = size;
      _sceneBuild = widget.build;
    }
    return _scene!;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _ScenePainter(_sceneFor, _reveal.value),
      ),
    );
  }
}

/// A line series.
class FinanceLineChart extends StatelessWidget {
  const FinanceLineChart({super.key, required this.values, this.style});

  final List<double> values;
  final LineSeriesStyle? style;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.expand();
    final s = style ?? DrafterTheme.instance.line();
    return _RevealChart(
      revealKey: Object.hashAll(values),
      build: (size) => LineSeriesEngine.build(
        values,
        CandleWindow(0, values.length - 1),
        _plotOf(size.width, size.height),
        s,
      ),
    );
  }
}

/// A line + filled area series.
class FinanceAreaChart extends StatelessWidget {
  const FinanceAreaChart({super.key, required this.values, this.style});

  final List<double> values;
  final AreaSeriesStyle? style;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.expand();
    final s = style ?? DrafterTheme.instance.area();
    return _RevealChart(
      revealKey: Object.hashAll(values),
      build: (size) => AreaSeriesEngine.build(
        values,
        CandleWindow(0, values.length - 1),
        _plotOf(size.width, size.height),
        s,
      ),
    );
  }
}

/// A baseline series: line + fill split above/below [BaselineSeriesStyle.baseValue].
class FinanceBaselineChart extends StatelessWidget {
  const FinanceBaselineChart({
    super.key,
    required this.values,
    required this.style,
  });

  final List<double> values;
  final BaselineSeriesStyle style;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.expand();
    return _RevealChart(
      revealKey: Object.hashAll(values),
      build: (size) => BaselineSeriesEngine.build(
        values,
        CandleWindow(0, values.length - 1),
        _plotOf(size.width, size.height),
        style,
      ),
    );
  }
}

/// A histogram (bars from a base value).
class FinanceHistogramChart extends StatelessWidget {
  const FinanceHistogramChart({super.key, required this.values, this.style});

  final List<double> values;
  final HistogramSeriesStyle? style;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.expand();
    final s = style ?? DrafterTheme.instance.histogram();
    return _RevealChart(
      revealKey: Object.hashAll(values),
      build: (size) => HistogramSeriesEngine.build(
        values,
        CandleWindow(0, values.length - 1),
        _plotOf(size.width, size.height),
        s,
      ),
    );
  }
}

/// A volume histogram colored by candle direction (up/down).
class FinanceVolumeChart extends StatelessWidget {
  const FinanceVolumeChart({super.key, required this.candles, this.style});

  final List<Candle> candles;
  final VolumeStyle? style;

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return const SizedBox.expand();
    final s = style ?? DrafterTheme.instance.volume();
    return _RevealChart(
      revealKey: candles.length,
      build: (size) => VolumeEngine.build(
        candles,
        CandleWindow(0, candles.length - 1),
        _plotOf(size.width, size.height),
        s,
      ),
    );
  }
}

/// An OHLC bar series (American bars).
class FinanceBarChart extends StatelessWidget {
  const FinanceBarChart({super.key, required this.candles, this.style});

  final List<Candle> candles;
  final BarSeriesStyle? style;

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return const SizedBox.expand();
    final s = style ?? DrafterTheme.instance.bar();
    return _RevealChart(
      revealKey: candles.length,
      build: (size) => BarSeriesEngine.build(
        candles,
        CandleWindow(0, candles.length - 1),
        _plotOf(size.width, size.height),
        s,
      ),
    );
  }
}

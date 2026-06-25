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
import 'dart:async';

import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:drafter/src/theme/drafter_theme.dart';
import 'package:flutter/widgets.dart';

/// Draws one chart into a [Canvas]. Implementations hold immutable data + style,
/// mirroring the Compose/SwiftUI renderer pattern: a renderer is a pure value
/// that, given a canvas, size, theme, and reveal [progress], draws itself.
abstract class ChartRenderer {
  const ChartRenderer();

  /// Draws the chart. [progress] is the entrance reveal in `0..1` (1 = fully drawn).
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  );

  /// A short label naming the kind of chart, e.g. `"Line chart"`, for semantics.
  String get accessibilityLabel => 'Chart';

  /// A value summarizing the chart's data — counts, range, a few points.
  String get accessibilityValue => '';
}

/// Shared formatting so every renderer's [ChartRenderer.accessibilityValue]
/// reads consistently. Trims trailing zeros so `40.0` announces as `"40"`.
abstract final class AccessibilityFormat {
  static String number(double value) {
    if (value == value.roundToDouble()) return '${value.round()}';
    var text = value.toStringAsFixed(2);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text;
  }

  /// "Jan 40, Feb 65, Mar 30" style list, capped so long series stay terse.
  static String points(List<(String, double)> pairs, {int limit = 12}) {
    final shown = pairs.take(limit).map((p) {
      return p.$1.isEmpty ? number(p.$2) : '${p.$1} ${number(p.$2)}';
    });
    final suffix = pairs.length > limit
        ? ', and ${pairs.length - limit} more'
        : '';
    return shown.join(', ') + suffix;
  }

  /// "ranging 20 to 95" — handy when listing every point would be noise.
  static String range(List<double> values) {
    if (values.isEmpty) return '';
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    return 'ranging ${number(lo)} to ${number(hi)}';
  }
}

/// A thin, reusable widget that hosts any [ChartRenderer] in a [CustomPaint],
/// reads the theme from the environment, and traces the chart in with the shared
/// reveal animation. Every concrete chart widget wraps this — so the
/// animation/theming plumbing lives in exactly one place.
class ChartCanvas extends StatefulWidget {
  const ChartCanvas({
    super.key,
    required this.renderer,
    this.animate = true,
    this.duration = const Duration(milliseconds: 1000),
    this.replay = 0,
  });

  final ChartRenderer renderer;
  final bool animate;
  final Duration duration;

  /// Change this value to replay the entrance animation.
  final int replay;

  @override
  State<ChartCanvas> createState() => _ChartCanvasState();
}

class _ChartCanvasState extends State<ChartCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _reveal = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      unawaited(_controller.forward());
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(ChartCanvas old) {
    super.didUpdateWidget(old);
    if (old.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (old.replay != widget.replay && widget.animate) {
      _controller.reset();
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DrafterTheme.of(context);
    // The painter repaints directly off [_reveal] (no per-frame widget
    // rebuild), and the RepaintBoundary isolates the chart's raster layer so
    // animating it never repaints the surrounding UI.
    return Semantics(
      label: widget.renderer.accessibilityLabel,
      value: widget.renderer.accessibilityValue,
      container: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _RendererPainter(
            renderer: widget.renderer,
            theme: theme,
            animation: _reveal,
          ),
        ),
      ),
    );
  }
}

class _RendererPainter extends CustomPainter {
  _RendererPainter({
    required this.renderer,
    required this.theme,
    required this.animation,
  }) : super(repaint: animation);

  final ChartRenderer renderer;
  final DrafterThemeColors theme;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    renderer.draw(canvas, size, theme, animation.value);
  }

  @override
  bool shouldRepaint(_RendererPainter old) =>
      old.renderer != renderer ||
      old.theme != theme ||
      old.animation != animation;
}

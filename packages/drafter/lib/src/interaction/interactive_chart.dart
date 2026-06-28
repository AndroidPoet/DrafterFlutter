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
import 'dart:math' as math;

import 'package:drafter/src/core/chart_formatting.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/interaction/chart_hit_test.dart';
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:drafter/src/theme/drafter_theme.dart';
import 'package:flutter/widgets.dart';

/// Configures which interactions a [InteractiveChart] enables and how it reports
/// them. All flags are independent; callbacks are optional.
@immutable
class ChartInteraction {
  /// Creates an interaction config. Every flag is independent and every callback
  /// optional, so you can enable just the behaviors you want.
  const ChartInteraction({
    this.tooltip = true,
    this.selection = true,
    this.rangeSelection = false,
    this.onSelected,
    this.onRangeSelected,
    this.rowLabel,
  });

  /// Show a trackball + tooltip following the pointer (hover or drag).
  final bool tooltip;

  /// Select the nearest datum on tap, highlighting it and firing [onSelected].
  final bool selection;

  /// Select a column range on drag, banding it and firing [onRangeSelected].
  final bool rangeSelection;

  /// Called on tap with the hit datum, or `null` when the tap missed.
  final ValueChanged<ChartSelection?>? onSelected;

  /// Called when a drag range-selection ends, or `null` if nothing was spanned.
  final ValueChanged<ChartRange?>? onRangeSelected;

  /// Formats a tooltip row for [mark]. Defaults to `"<series>  <value>"`
  /// (or just the value when the series is unnamed).
  final String Function(PlotMark mark)? rowLabel;

  bool get _anyEnabled => tooltip || selection || rangeSelection;
}

/// Hosts any [ChartRenderer] and, when the renderer is an [InteractiveRenderer],
/// layers Canvas-drawn interactions over it: a trackball tooltip, tap value
/// selection, and drag range selection — all painted on a non-rebuilding overlay
/// so the base chart's reveal animation is untouched.
///
/// ```dart
/// InteractiveChart(
///   renderer: LineChartRenderer(points: points),
///   interaction: ChartInteraction(
///     rangeSelection: true,
///     onSelected: (s) => print(s?.mark.value),
///   ),
/// )
/// ```
class InteractiveChart extends StatefulWidget {
  /// Wraps [renderer] with the interactions configured by [interaction].
  const InteractiveChart({
    super.key,
    required this.renderer,
    this.interaction = const ChartInteraction(),
    this.animate = true,
    this.duration = const Duration(milliseconds: 1000),
    this.replay = 0,
  });

  /// The chart to draw and (if it is an [InteractiveRenderer]) hit-test.
  final ChartRenderer renderer;

  /// Which interactions to enable and how to report them.
  final ChartInteraction interaction;

  /// Whether the base chart plays its entrance reveal animation.
  final bool animate;

  /// How long the base chart's entrance reveal animation runs.
  final Duration duration;

  /// Change this value to replay the base chart's entrance animation.
  final int replay;

  @override
  State<InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<InteractiveChart> {
  /// Drives only the overlay painter — interactions never rebuild the widget
  /// tree or disturb the base chart's animation.
  final ValueNotifier<_Overlay> _overlay = ValueNotifier(const _Overlay());

  // Scene cache: rebuilt only when the size or renderer changes.
  ChartScene? _scene;
  Size? _sceneSize;
  ChartRenderer? _sceneRenderer;

  // Live interaction fields, published as an immutable [_Overlay] snapshot.
  // Cartesian charts (scene has a scale) use [_trackball] + range; non-cartesian
  // charts (pie/treemap/…) use [_hoverMark] + [_pointer] for a per-mark tooltip.
  int? _trackball;
  PlotMark? _hoverMark;
  Offset? _pointer;
  PlotMark? _selected;
  double? _rangeStart;
  double? _rangeCurrent;

  bool get _interactive =>
      widget.renderer is InteractiveRenderer && widget.interaction._anyEnabled;

  ChartScene _sceneFor(Size size) {
    final renderer = widget.renderer;
    if (_scene != null &&
        _sceneSize == size &&
        identical(_sceneRenderer, renderer)) {
      return _scene!;
    }
    final scene = renderer is InteractiveRenderer
        ? (renderer as InteractiveRenderer).buildScene(size)
        : ChartScene.empty;
    _scene = scene;
    _sceneSize = size;
    _sceneRenderer = renderer;
    return scene;
  }

  void _publish() {
    // The MouseRegion can fire onExit during detach, after dispose() has freed
    // the notifier — guard against writing to a disposed ValueNotifier.
    if (!mounted) return;
    _overlay.value = _Overlay(
      trackball: _trackball,
      hoverMark: _hoverMark,
      pointer: _pointer,
      selected: _selected,
      rangeStart: _rangeStart,
      rangeCurrent: _rangeCurrent,
    );
  }

  /// Updates the hover indicator for [pos]: a trackball column on cartesian
  /// charts, or the mark under the pointer on everything else.
  void _track(Offset pos, ChartScene scene) {
    if (scene.scale != null) {
      _trackball = ChartHitTest.nearestIndexAtX(scene, pos.dx);
    } else {
      _hoverMark = ChartHitTest.markAt(scene, pos);
      _pointer = pos;
    }
  }

  void _onHover(Offset pos, ChartScene scene) {
    if (!widget.interaction.tooltip) return;
    _track(pos, scene);
    _publish();
  }

  void _onExit() {
    if (_trackball == null && _hoverMark == null) return;
    _trackball = null;
    _hoverMark = null;
    _pointer = null;
    _publish();
  }

  void _onTapUp(Offset pos, ChartScene scene) {
    if (!widget.interaction.selection) return;
    final mark = ChartHitTest.markAt(scene, pos);
    _selected = mark;
    if (mark != null) _trackball = mark.index;
    _publish();
    widget.interaction.onSelected?.call(
      mark == null ? null : ChartSelection(mark),
    );
  }

  void _onPanStart(Offset pos, ChartScene scene) {
    if (widget.interaction.tooltip) _track(pos, scene);
    // Range selection is cartesian-only (it spans columns).
    if (widget.interaction.rangeSelection && scene.scale != null) {
      _rangeStart = pos.dx;
      _rangeCurrent = pos.dx;
    }
    _publish();
  }

  void _onPanUpdate(Offset pos, ChartScene scene) {
    if (widget.interaction.tooltip) _track(pos, scene);
    if (widget.interaction.rangeSelection && scene.scale != null) {
      _rangeCurrent = pos.dx;
    }
    _publish();
  }

  void _onPanEnd(ChartScene scene) {
    if (widget.interaction.rangeSelection &&
        scene.scale != null &&
        _rangeStart != null &&
        _rangeCurrent != null) {
      final range = ChartHitTest.rangeBetween(
        scene,
        _rangeStart!,
        _rangeCurrent!,
      );
      widget.interaction.onRangeSelected?.call(range);
    }
    _rangeStart = null;
    _rangeCurrent = null;
    _publish();
  }

  @override
  void didUpdateWidget(InteractiveChart old) {
    super.didUpdateWidget(old);
    // A new renderer (or swapped-in data) invalidates the cached scene AND every
    // live interaction field: a stale [_selected]/[_hoverMark] would otherwise
    // paint a highlight ring at a pixel from the OLD geometry over the new chart.
    if (!identical(old.renderer, widget.renderer)) {
      _scene = null;
      _sceneSize = null;
      _sceneRenderer = null;
      _trackball = null;
      _hoverMark = null;
      _pointer = null;
      _selected = null;
      _rangeStart = null;
      _rangeCurrent = null;
      _overlay.value = const _Overlay();
    }
  }

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = ChartCanvas(
      renderer: widget.renderer,
      animate: widget.animate,
      duration: widget.duration,
      replay: widget.replay,
    );
    if (!_interactive) return base;

    final theme = DrafterTheme.of(context);
    final interaction = widget.interaction;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final scene = _sceneFor(size);

        return MouseRegion(
          onHover: interaction.tooltip
              ? (e) => _onHover(e.localPosition, scene)
              : null,
          onExit: (_) => _onExit(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTapUp(d.localPosition, scene),
            onPanStart: (d) => _onPanStart(d.localPosition, scene),
            onPanUpdate: (d) => _onPanUpdate(d.localPosition, scene),
            onPanEnd: (_) => _onPanEnd(scene),
            child: Stack(
              fit: StackFit.expand,
              children: [
                base,
                Positioned.fill(
                  child: IgnorePointer(
                    // Its own layer: overlay repaints (on hover/drag) never
                    // re-raster the base chart, and vice-versa.
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _OverlayPainter(
                          overlay: _overlay,
                          scene: scene,
                          theme: theme,
                          interaction: interaction,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// An immutable snapshot of the live interaction state, the painter's input.
@immutable
class _Overlay {
  const _Overlay({
    this.trackball,
    this.hoverMark,
    this.pointer,
    this.selected,
    this.rangeStart,
    this.rangeCurrent,
  });

  final int? trackball;
  final PlotMark? hoverMark;
  final Offset? pointer;
  final PlotMark? selected;
  final double? rangeStart;
  final double? rangeCurrent;

  // Value equality so the driving [ValueNotifier] only fires when the overlay
  // actually changes. Without this, every pointer-move event would publish a
  // distinct instance and repaint the overlay even when the resolved column is
  // unchanged (e.g. moving the cursor within one trackball column). Marks are
  // compared by identity — they come from the same cached scene.
  @override
  bool operator ==(Object other) =>
      other is _Overlay &&
      other.trackball == trackball &&
      identical(other.hoverMark, hoverMark) &&
      other.pointer == pointer &&
      identical(other.selected, selected) &&
      other.rangeStart == rangeStart &&
      other.rangeCurrent == rangeCurrent;

  @override
  int get hashCode => Object.hash(
    trackball,
    identityHashCode(hoverMark),
    pointer,
    identityHashCode(selected),
    rangeStart,
    rangeCurrent,
  );
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.overlay,
    required this.scene,
    required this.theme,
    required this.interaction,
  }) : super(repaint: overlay);

  final ValueNotifier<_Overlay> overlay;
  final ChartScene scene;
  final DrafterThemeColors theme;
  final ChartInteraction interaction;

  @override
  void paint(Canvas canvas, Size size) {
    if (scene.isEmpty) return;
    final state = overlay.value;
    final bounds = scene.bounds;
    if (bounds == null) return;

    // Drag range band (under everything else).
    if (interaction.rangeSelection &&
        state.rangeStart != null &&
        state.rangeCurrent != null) {
      final left = math.min(state.rangeStart!, state.rangeCurrent!);
      final right = math.max(state.rangeStart!, state.rangeCurrent!);
      drawSelectionBand(
        canvas,
        Rect.fromLTRB(
          left.clamp(bounds.left, bounds.right),
          bounds.top,
          right.clamp(bounds.left, bounds.right),
          bounds.bottom,
        ),
        fill: theme.selectionBand,
        border: theme.selectionBorder,
      );
    }

    if (interaction.tooltip) {
      if (scene.scale != null) {
        _paintTrackball(canvas, size, bounds, state);
      } else {
        _paintHoverMark(canvas, size, state);
      }
    }

    // Tap selection highlight (on top).
    final selected = state.selected;
    if (interaction.selection && selected != null) {
      drawHighlightRing(canvas, selected.center, selected.color, radius: 7);
    }
  }

  /// Cartesian: a vertical trackball line at the active column with a tooltip
  /// listing every series value there.
  void _paintTrackball(
    Canvas canvas,
    Size size,
    ChartBounds bounds,
    _Overlay state,
  ) {
    final index = state.trackball;
    if (index == null) return;
    final marks = ChartHitTest.marksAtIndex(scene, index);
    if (marks.isEmpty) return;
    final x = scene.scale?.xForIndex(index) ?? marks.first.center.dx;
    drawTrackball(
      canvas,
      x: x,
      top: bounds.top,
      bottom: bounds.bottom,
      lineColor: theme.crosshair,
      markers: [for (final m in marks) m.center],
      markerColors: [for (final m in marks) m.color],
    );
    drawTooltip(
      canvas,
      anchor: Offset(x, bounds.top),
      container: size,
      title: marks.first.label.isEmpty ? null : marks.first.label,
      background: theme.tooltipBackground,
      textColor: theme.tooltipText,
      mutedTextColor: theme.tooltipMutedText,
      rows: [for (final m in marks) TooltipRow(_rowText(m), swatch: m.color)],
    );
  }

  /// Non-cartesian: highlight the mark under the pointer and float a one-row
  /// tooltip beside it (pie/donut/polar/sunburst/treemap/heatmap/funnel/…).
  void _paintHoverMark(Canvas canvas, Size size, _Overlay state) {
    final mark = state.hoverMark;
    if (mark == null) return;
    drawHighlightRing(canvas, mark.center, mark.color, radius: 7);
    drawTooltip(
      canvas,
      anchor: state.pointer ?? mark.center,
      container: size,
      title: mark.label.isEmpty ? null : mark.label,
      background: theme.tooltipBackground,
      textColor: theme.tooltipText,
      mutedTextColor: theme.tooltipMutedText,
      rows: [TooltipRow(_rowText(mark), swatch: mark.color)],
    );
  }

  String _rowText(PlotMark m) {
    final custom = interaction.rowLabel;
    if (custom != null) return custom(m);
    final value = ChartFormatting.format(m.value);
    return m.seriesName.isEmpty ? value : '${m.seriesName}  $value';
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.scene != scene ||
      old.theme != theme ||
      old.interaction != interaction;
}

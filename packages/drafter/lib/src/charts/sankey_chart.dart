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
import 'dart:ui' as ui;

import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// A single node in a [SankeyChart].
///
/// - `id`: stable identifier referenced by [SankeyLink.from] / [SankeyLink.to].
/// - `label`: human-readable text drawn beside the node bar.
/// - `column`: the layer (0, 1, 2, ...) the node belongs to; columns spread
///   evenly across the chart width from left to right.
/// - `color`: the colour of the node bar and the tint of its outgoing bands.
@immutable
class SankeyNode {
  /// Creates a Sankey node with a stable [id], display [label], [column], and bar [color].
  const SankeyNode({
    required this.id,
    required this.label,
    required this.column,
    required this.color,
  });

  /// Stable identifier referenced by [SankeyLink.from] / [SankeyLink.to].
  final String id;

  /// Human-readable text drawn beside the node bar.
  final String label;

  /// The layer (0, 1, 2, ...) the node belongs to, ordered left to right.
  final int column;

  /// The colour of the node bar and the tint of its outgoing bands.
  final Color color;
}

/// A flow between two nodes. Its [value] determines the band thickness at both
/// endpoints.
@immutable
class SankeyLink {
  /// Creates a flow of magnitude [value] from node [from] to node [to].
  const SankeyLink({
    required this.from,
    required this.to,
    required this.value,
  });

  /// The id of the source node the flow leaves.
  final String from;

  /// The id of the destination node the flow enters.
  final String to;

  /// The magnitude of the flow, driving band thickness at both endpoints.
  final double value;
}

/// A node positioned in pixel space, ready to draw.
class _PlacedNode {
  const _PlacedNode({
    required this.node,
    required this.x,
    required this.top,
    required this.width,
    required this.fullHeight,
    required this.isFirst,
    required this.isLast,
  });

  final SankeyNode node;
  final double x;
  final double top;
  final double width;
  final double fullHeight;
  final bool isFirst;
  final bool isLast;
}

/// Draws a Sankey flow diagram into a canvas.
class SankeyChartRenderer extends ChartRenderer implements InteractiveRenderer {
  /// Creates a renderer for the given [nodes] and [links].
  SankeyChartRenderer({required this.nodes, required this.links});

  /// The nodes to place into columns and draw as bars.
  final List<SankeyNode> nodes;

  /// The flows drawn as gradient bands between nodes.
  final List<SankeyLink> links;

  // Memoized node layout: the column grouping + throughput accumulation +
  // placement is progress-independent, so it's computed once per size and reused
  // across every animation frame and by buildScene (instead of rebuilt
  // ~60×/second during the reveal). A sentinel distinguishes "not computed yet"
  // from a legitimately null (degenerate) layout.
  Size? _placeSize;
  bool _placeComputed = false;
  ({
    Map<String, _PlacedNode> placed,
    double Function(String) throughput,
    double chartLeft,
    double chartTop,
    double chartWidth,
  })?
  _placeCache;

  /// The progress-independent node layout shared by [draw] and [buildScene], so
  /// the hit-test boxes line up exactly with the painted node bars. Returns
  /// `null` on the same empty/degenerate guards [draw] bails on. Memoized by
  /// [size] since the layout is reveal-independent.
  ({
    Map<String, _PlacedNode> placed,
    double Function(String) throughput,
    double chartLeft,
    double chartTop,
    double chartWidth,
  })?
  _placeNodes(Size size) {
    if (_placeComputed && _placeSize == size) return _placeCache;
    final computed = _computePlaceNodes(size);
    _placeSize = size;
    _placeCache = computed;
    _placeComputed = true;
    return computed;
  }

  ({
    Map<String, _PlacedNode> placed,
    double Function(String) throughput,
    double chartLeft,
    double chartTop,
    double chartWidth,
  })?
  _computePlaceNodes(Size size) {
    if (nodes.isEmpty) return null;

    // 8% inset on each side for node labels (mirrors the Compose host).
    const inset = 0.08;
    final chartLeft = size.width * inset;
    final chartTop = size.height * inset;
    final chartWidth = size.width * (1 - inset * 2);
    final chartHeight = size.height * (1 - inset * 2);
    if (!(chartWidth > 0) || !(chartHeight > 0)) return null;

    // Index nodes by id; skip links that reference unknown nodes.
    final nodeById = <String, SankeyNode>{};
    for (final node in nodes) {
      nodeById[node.id] = node;
    }

    // Per-node throughput = max(total inflow, total outflow).
    final inflow = <String, double>{};
    final outflow = <String, double>{};
    for (final link in links) {
      if (nodeById[link.from] != null && nodeById[link.to] != null) {
        outflow[link.from] = (outflow[link.from] ?? 0) + link.value;
        inflow[link.to] = (inflow[link.to] ?? 0) + link.value;
      }
    }
    double throughput(String id) {
      final value = math.max(inflow[id] ?? 0, outflow[id] ?? 0);
      // Guard against a NaN/Infinity link value propagating into node heights,
      // hit-test regions, or the valueToPx scale.
      return value.isFinite && value > 0 ? value : 0;
    }

    // Group by column and order columns left -> right.
    final columns = <int, List<SankeyNode>>{};
    for (final node in nodes) {
      columns.putIfAbsent(node.column, () => []).add(node);
    }
    final columnKeys = columns.keys.toList()..sort();
    if (columnKeys.isEmpty) return null;
    final maxColumn = columnKeys.last;

    final nodeWidth = math.min(math.max(chartWidth * 0.045, 6), 26).toDouble();
    final verticalGap = math.max(chartHeight * 0.04, 6).toDouble();

    // Scale node heights so the tallest column's stack fits the chart height.
    final maxThroughputSum = math.max(
      columnKeys
          .map(
            (key) =>
                (columns[key] ?? []).fold(0.0, (a, n) => a + throughput(n.id)),
          )
          .fold(0.0, math.max),
      1,
    );
    final maxColumnCount = columnKeys
        .map((key) => (columns[key] ?? []).length)
        .fold(0, math.max);
    final availableForBars = math.max(
      chartHeight - math.max(maxColumnCount - 1, 0) * verticalGap,
      1,
    );
    final valueToPx = availableForBars / maxThroughputSum;

    // Place every node.
    final placed = <String, _PlacedNode>{};
    for (var colIndex = 0; colIndex < columnKeys.length; colIndex++) {
      final colKey = columnKeys[colIndex];
      final group = (columns[colKey] ?? []).toList()
        ..sort((a, b) => a.label.compareTo(b.label));
      final heights = group
          .map((n) => math.max(throughput(n.id) * valueToPx, 2))
          .toList();
      final stackHeight =
          heights.fold(0.0, (a, b) => a + b) +
          math.max(group.length - 1, 0) * verticalGap;
      final startY = chartTop + (chartHeight - stackHeight) / 2;

      final x = maxColumn == 0
          ? chartLeft + (chartWidth - nodeWidth) / 2
          : chartLeft + (chartWidth - nodeWidth) * (colKey / maxColumn);

      var cursorY = startY;
      for (var i = 0; i < group.length; i++) {
        final node = group[i];
        final h = heights[i].toDouble();
        placed[node.id] = _PlacedNode(
          node: node,
          x: x,
          top: cursorY,
          width: nodeWidth,
          fullHeight: h,
          isFirst: colIndex == 0,
          isLast: colIndex == columnKeys.length - 1,
        );
        cursorY += h + verticalGap;
      }
    }

    return (
      placed: placed,
      throughput: throughput,
      chartLeft: chartLeft,
      chartTop: chartTop,
      chartWidth: chartWidth,
    );
  }

  /// One [PlotMark] per node: its box [PlotMark.region] (and centre) is the
  /// painted node bar at full height, [PlotMark.value] its throughput. Links /
  /// ribbons are not hit-tested.
  @override
  ChartScene buildScene(Size size) {
    final layout = _placeNodes(size);
    if (layout == null) return ChartScene.empty;
    final placed = layout.placed.values.toList();
    if (placed.isEmpty) return ChartScene.empty;
    return ChartScene(
      bounds: ChartBounds(size, padding: 0),
      categories: [for (final pn in placed) pn.node.label],
      marks: [
        for (var i = 0; i < placed.length; i++)
          PlotMark(
            index: i,
            seriesIndex: 0,
            seriesName: '',
            label: placed[i].node.label,
            value: layout.throughput(placed[i].node.id),
            center: Offset(
              placed[i].x + placed[i].width / 2,
              placed[i].top + placed[i].fullHeight / 2,
            ),
            color: placed[i].node.color,
            region: Rect.fromLTWH(
              placed[i].x,
              placed[i].top,
              placed[i].width,
              placed[i].fullHeight,
            ),
          ),
      ],
    );
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    final layout = _placeNodes(size);
    if (layout == null) return;

    final prog = progress.clamp(0.0, 1.0);
    final placed = layout.placed;
    final throughput = layout.throughput;
    final chartTop = layout.chartTop;

    // Running offsets so multiple links share each edge without overlapping.
    final outOffset = <String, double>{};
    final inOffset = <String, double>{};
    final revealRight = layout.chartLeft + layout.chartWidth * prog;

    // Draw the bands first (behind node bars).
    for (final link in links) {
      final from = placed[link.from];
      final to = placed[link.to];
      if (from == null || to == null) continue;

      final fromTotal = math.max(throughput(from.node.id), 0.0001);
      final toTotal = math.max(throughput(to.node.id), 0.0001);
      final fromThickness = from.fullHeight * (link.value / fromTotal);
      final toThickness = to.fullHeight * (link.value / toTotal);

      final oStart = outOffset[link.from] ?? 0;
      final iStart = inOffset[link.to] ?? 0;
      outOffset[link.from] = oStart + fromThickness;
      inOffset[link.to] = iStart + toThickness;

      final startX = from.x + from.width;
      final endX = to.x;
      final startTop = from.top + oStart;
      final startBottom = startTop + fromThickness;
      final endTop = to.top + iStart;
      final endBottom = endTop + toThickness;

      _drawBand(
        canvas: canvas,
        startX: startX,
        endX: endX,
        startTop: startTop,
        startBottom: startBottom,
        endTop: endTop,
        endBottom: endBottom,
        fromColor: from.node.color,
        toColor: to.node.color,
        revealRight: revealRight,
        canvasHeight: size.height,
      );
    }

    // Draw node bars (animated growth in height) + labels.
    for (final pn in placed.values) {
      final animHeight = pn.fullHeight * prog;
      final centerY = pn.top + pn.fullHeight / 2;
      final barTop = centerY - animHeight / 2;
      final corner = pn.width / 2.5;
      final barRect = Rect.fromLTWH(pn.x, barTop, pn.width, animHeight);
      final barRRect = RRect.fromRectAndRadius(
        barRect,
        Radius.circular(corner),
      );

      canvas
        ..drawRRect(barRRect, Paint()..color = pn.node.color)
        // Soft white inner stroke for a crisp, premium edge.
        ..drawRRect(
          barRRect,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25,
        );

      _drawNodeLabel(
        canvas: canvas,
        node: pn.node,
        labelColor: theme.label,
        canvasWidth: size.width,
        x: pn.x,
        width: pn.width,
        barTop: barTop,
        chartTop: chartTop,
        progress: prog,
      );
    }
  }

  @override
  String get accessibilityLabel => 'Sankey diagram';

  @override
  String get accessibilityValue =>
      '${nodes.length} nodes, ${links.length} flows';

  /// Draws one flow band as a filled cubic S-curve with a horizontal from->to
  /// gradient, revealed by clipping to the left of `revealRight`.
  void _drawBand({
    required Canvas canvas,
    required double startX,
    required double endX,
    required double startTop,
    required double startBottom,
    required double endTop,
    required double endBottom,
    required Color fromColor,
    required Color toColor,
    required double revealRight,
    required double canvasHeight,
  }) {
    final midX = (startX + endX) / 2;
    final path = Path()
      ..moveTo(startX, startTop)
      ..cubicTo(midX, startTop, midX, endTop, endX, endTop)
      ..lineTo(endX, endBottom)
      ..cubicTo(midX, endBottom, midX, startBottom, startX, startBottom)
      ..close();

    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, revealRight, canvasHeight))
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = ui.Gradient.linear(
            Offset(startX, 0),
            Offset(endX, 0),
            [
              fromColor.withValues(alpha: 0.5),
              toColor.withValues(alpha: 0.5),
            ],
          ),
      )
      ..restore();
  }

  /// Draws a node's label centered above its bar, clamped to the canvas so it
  /// stays fully on-screen at small sizes. Fades in with the reveal progress.
  void _drawNodeLabel({
    required Canvas canvas,
    required SankeyNode node,
    required Color labelColor,
    required double canvasWidth,
    required double x,
    required double width,
    required double barTop,
    required double chartTop,
    required double progress,
  }) {
    if (node.label.isEmpty) return;
    final color = labelColor.withValues(alpha: progress);

    // At small sizes the 8% side inset is too narrow to hold edge-column labels,
    // so anchoring them outside the bar pushes the text past the canvas and
    // clips it. Draw every label centered above its bar instead, and clamp the
    // center by the resolved text's half-width so the WHOLE label stays
    // on-canvas (not just its center), then keep it below the chart top so a
    // near-full-height bar never clips the label off the top edge.
    // Measure via the shared text cache (width is color-independent), then draw
    // through the cached helper instead of building a TextPainter every frame.
    final half = measureChartText(node.label, fontSize: 10) / 2;
    final lower = math.min(half + 2, canvasWidth / 2);
    final upper = math.max(canvasWidth - half - 2, canvasWidth / 2);
    final cx = math.min(math.max(x + width / 2, lower), upper);
    final ly = math.max(barTop - 4, chartTop + 4);
    drawChartText(
      canvas,
      node.label,
      Offset(cx, ly),
      color: color,
      fontSize: 10,
      h: HAlign.center,
      v: VAlign.bottom,
    );
  }
}

/// A Sankey flow diagram with gradient flow bands and an animated left-to-right
/// reveal.
class SankeyChart extends StatelessWidget {
  /// Creates a Sankey chart for the given [nodes] and [links].
  const SankeyChart({
    super.key,
    required this.nodes,
    required this.links,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 900),
  });

  /// The nodes laid out into columns.
  final List<SankeyNode> nodes;

  /// The flows drawn between nodes.
  final List<SankeyLink> links;

  /// Whether to animate the reveal on first build.
  final bool animate;

  /// Increment to replay the reveal animation.
  final int replay;

  /// The duration of the reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: SankeyChartRenderer(nodes: nodes, links: links),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}

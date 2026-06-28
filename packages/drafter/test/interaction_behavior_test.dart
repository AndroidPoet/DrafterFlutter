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
import 'package:drafter/drafter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _line = LineChartRenderer(
  points: const [
    ChartPoint('A', 10),
    ChartPoint('B', 20),
    ChartPoint('C', 30),
    ChartPoint('D', 40),
  ],
);

const _pie = PieChartRenderer(
  slices: [
    PieSlice(value: 30, color: Color(0xFF4C8DF6), label: 'P1'),
    PieSlice(value: 50, color: Color(0xFF2FC4C0), label: 'P2'),
    PieSlice(value: 20, color: Color(0xFF7C6BF2), label: 'P3'),
  ],
);

/// A renderer that counts how many times its scene is built, to prove the
/// interaction layer caches the scene and doesn't rebuild it on every gesture.
class _CountingRenderer extends ChartRenderer implements InteractiveRenderer {
  _CountingRenderer(this.inner);

  final LineChartRenderer inner;
  int sceneBuilds = 0;

  @override
  void draw(Canvas canvas, Size size, DrafterThemeColors theme, double p) =>
      inner.draw(canvas, size, theme, p);

  @override
  ChartScene buildScene(Size size) {
    sceneBuilds++;
    return inner.buildScene(size);
  }
}

Future<void> _pump(WidgetTester tester, Widget chart) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DrafterTheme(
        colors: DrafterThemeColors.light,
        child: Center(
          child: SizedBox(width: 400, height: 280, child: chart),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('hover', () {
    testWidgets('cartesian hover paints a trackball without throwing', (
      tester,
    ) async {
      await _pump(tester, InteractiveChart(renderer: _line));
      final center = tester.getCenter(find.byType(InteractiveChart));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(center);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('non-cartesian hover highlights a mark without throwing', (
      tester,
    ) async {
      await _pump(tester, const InteractiveChart(renderer: _pie));
      final center = tester.getCenter(find.byType(InteractiveChart));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(center);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('exiting the chart clears the hover without throwing', (
      tester,
    ) async {
      await _pump(tester, InteractiveChart(renderer: _line));
      final center = tester.getCenter(find.byType(InteractiveChart));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(center);
      await tester.pump();
      // Move far outside the chart → MouseRegion.onExit fires.
      await mouse.moveTo(const Offset(2000, 2000));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('selection', () {
    testWidgets('a tap that misses every datum reports null', (tester) async {
      var called = false;
      ChartSelection? selection = const ChartSelection(
        PlotMark(
          index: 0,
          seriesIndex: 0,
          seriesName: '',
          label: '',
          value: 0,
          center: Offset.zero,
          color: Color(0xFF000000),
        ),
      );
      await _pump(
        tester,
        InteractiveChart(
          renderer: _line,
          interaction: ChartInteraction(
            onSelected: (s) {
              called = true;
              selection = s;
            },
          ),
        ),
      );

      // Tap the extreme top-left corner — far above the line's data points.
      final topLeft = tester.getTopLeft(find.byType(InteractiveChart));
      await tester.tapAt(topLeft + const Offset(2, 2));
      await tester.pump();

      expect(called, isTrue);
      expect(selection, isNull);
    });

    testWidgets('selection: false makes taps inert', (tester) async {
      var called = false;
      await _pump(
        tester,
        InteractiveChart(
          renderer: _line,
          interaction: ChartInteraction(
            selection: false,
            onSelected: (_) => called = true,
          ),
        ),
      );

      final center = tester.getCenter(find.byType(InteractiveChart));
      await tester.tapAt(center);
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('range drag is ignored on a non-cartesian chart', (
      tester,
    ) async {
      var called = false;
      await _pump(
        tester,
        InteractiveChart(
          renderer: _pie,
          interaction: ChartInteraction(
            rangeSelection: true,
            onRangeSelected: (_) => called = true,
          ),
        ),
      );

      final center = tester.getCenter(find.byType(InteractiveChart));
      await tester.dragFrom(center, const Offset(80, 0));
      await tester.pump();

      // Pie has no column scale, so a drag selects no range.
      expect(called, isFalse);
    });
  });

  group('scene caching & lifecycle', () {
    testWidgets('the scene is built once and reused across gestures', (
      tester,
    ) async {
      final counting = _CountingRenderer(_line);
      await _pump(tester, InteractiveChart(renderer: counting));

      final center = tester.getCenter(find.byType(InteractiveChart));
      // Several interactions at a fixed size must NOT rebuild the scene.
      await tester.tapAt(center);
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(center);
      await tester.pump();
      await mouse.moveTo(center + const Offset(10, 0));
      await tester.pump();

      expect(counting.sceneBuilds, 1);
    });

    testWidgets('swapping the renderer resets state without throwing', (
      tester,
    ) async {
      await _pump(tester, InteractiveChart(renderer: _line));
      // Select a datum on the first renderer.
      final topLeft = tester.getTopLeft(find.byType(InteractiveChart));
      await tester.tapAt(topLeft + const Offset(253, 84));
      await tester.pump();

      // Rebuild with a DIFFERENT renderer — the cached scene + stale selection
      // must be dropped (didUpdateWidget), with no exception.
      await _pump(tester, const InteractiveChart(renderer: _pie));
      expect(tester.takeException(), isNull);
      expect(find.byType(InteractiveChart), findsOneWidget);
    });

    testWidgets('disposing while hovering does not throw', (tester) async {
      await _pump(tester, InteractiveChart(renderer: _line));
      final center = tester.getCenter(find.byType(InteractiveChart));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(center);
      await tester.pump();

      // Replace the whole subtree — the chart is disposed while the pointer is
      // still inside it (onExit can fire during teardown).
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

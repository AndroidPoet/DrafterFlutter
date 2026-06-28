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
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// Propagates the active [DrafterThemeColors] to the chart subtree, the Flutter
/// equivalent of Compose's `LocalDrafterTheme` / SwiftUI's `@Environment`.
/// Charts read the resolved colors once via [DrafterTheme.of] instead of
/// recomputing them.
class DrafterTheme extends InheritedWidget {
  /// Provides [colors] to the chart subtree below [child].
  const DrafterTheme({super.key, required this.colors, required super.child});

  /// Convenience: pick light/dark by a boolean (e.g. brightness == dark).
  DrafterTheme.brightness({
    super.key,
    required bool dark,
    required super.child,
  }) : colors = dark ? DrafterThemeColors.dark : DrafterThemeColors.light;

  /// The resolved color set provided to descendant charts.
  final DrafterThemeColors colors;

  /// The active chart theme for [context]. Defaults to [DrafterThemeColors.light]
  /// when no [DrafterTheme] is found above.
  static DrafterThemeColors of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<DrafterTheme>();
    return widget?.colors ?? DrafterThemeColors.light;
  }

  @override
  bool updateShouldNotify(DrafterTheme oldWidget) => oldWidget.colors != colors;
}

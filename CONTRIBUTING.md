# Contributing to Drafter

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

## Getting started

Drafter is a pure Flutter package — clone the repo and fetch dependencies:

```bash
git clone https://github.com/AndroidPoet/DrafterFlutter.git
cd DrafterFlutter
flutter pub get
flutter test
```

Run the bundled gallery of every chart on your platform of choice:

```bash
cd example
flutter run            # or: flutter run -d macos / -d chrome
```

## Preparing a pull request for review

Ensure your change is formatted, analyzes cleanly under
[`very_good_analysis`](https://pub.dev/packages/very_good_analysis), and passes
the tests:

```bash
dart format .
flutter analyze
flutter test
```

Please correct any failures before requesting a review. CI runs the same
format, analyze, and test steps on every pull request.

## Adding a new chart

Each chart follows the same three-part pattern (see `lib/src/charts/area_chart.dart`
for the reference implementation):

1. An immutable data model in `lib/src/core/chart_data.dart` (or alongside the chart).
2. A pure `ChartRenderer` that draws into a `Canvas`.
3. A thin `StatelessWidget` that hosts the renderer in `ChartCanvas` for theming
   and the reveal animation.

Keep drawing logic inside the renderer so it stays testable and reusable, and
read colors from the injected `DrafterThemeColors` rather than hard-coding them.
Charts are double-heavy graphics math — note `prefer_int_literals` is disabled on
purpose, since forcing int literals on coordinates/accumulators breaks `double`
inference.

## Code reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult
[GitHub Help](https://docs.github.com/en/github/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests)
for more information on using pull requests.

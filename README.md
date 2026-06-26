# Drafter for Flutter

A monorepo of native, dependency-free Flutter charting libraries. Each package
is published to pub.dev independently and versioned on its own git tag.

| Package | What it is | pub.dev |
| --- | --- | --- |
| [`drafter`](packages/drafter) | The general charting library — ~27 chart types, Catmull-Rom curves, soft gradient fills, reveal animation | `drafter` |
| [`drafter_finance`](packages/drafter_finance) | Native trading charts — candlestick, OHLC, line, area, baseline, histogram, volume, indicators, magnet crosshair | `drafter_finance` |
| [`drafter_finance_engine`](packages/drafter_finance_engine) | The pure-Dart engine behind `drafter_finance` (no Flutter) — scales, indicators, hit-testing, display list | `drafter_finance_engine` |

## Layout

A [pub workspace](https://dart.dev/tools/pub/workspaces) — one shared lockfile,
each package resolved together:

```
packages/
  drafter/                  general charting library
  drafter_finance_engine/   pure-Dart trading-chart engine
  drafter_finance/          Flutter trading charts over that engine
```

## Releasing

Releases are automated via GitHub Actions + pub.dev OIDC (no stored tokens).
Bump a package's version, then push a tag matching its pattern:

```bash
git tag drafter-v0.2.1                 && git push --tags   # publishes drafter
git tag drafter_finance_engine-v0.1.0  && git push --tags   # publishes the engine
git tag drafter_finance-v0.1.0         && git push --tags   # publishes the renderer
```

Each tag triggers only its package's workflow. The trading-chart engine must go
live before `drafter_finance` (which depends on it).

## License

Apache 2.0.

# Pivot Fractal Offline Research Boundaries

Current research starts from strict `PIVOT_FRACTAL_V1` schema V9 exports and
ends in local DuckDB/Parquet datasets, deterministic audits, reports, and
offline XGBoost candidates. Nothing in this workflow runs inside MT5 or changes
broker execution.

Use `docs/workflows/pivot-fractal-statistics-flow.md` for export, validation,
dataset, audit, training, and human acceptance commands.

## Runtime Separation

```text
deterministic pivot first touch
-> route and broker safety decisions inside MQL5
-> optional V9 fact persistence
-> strict offline validation
-> leakage-safe dataset and audit
-> optional offline XGBoost experiment
```

- Feature export never authorizes, denies, resizes, delays, or redirects a
  trade.
- The MQL5 runtime has no model loader, model score, research threshold,
  inference mode, pattern matcher, or playback denial.
- Broker session, permissions, Bid/Ask, structural geometry, stops/freeze,
  volume, margin, `OrderCheck`, send retcodes, magic, ticket ownership,
  trailing, and reconciliation remain deterministic MQL5 responsibilities.
- Missing or malformed feature data invalidates research evidence while the
  independently valid broker path remains unchanged.

## Strict Input Contract

The validator requires schema `9`, engine `PIVOT_FRACTAL_V1`, feature set
`schema_v9_pivot_fractal_xgb`, exact frozen headers, unique keys, seven ordered
levels per valid window, exactly six context rows per complete attempt,
execution-chain integrity, ticket-owned trailing, and broker-confirmed entry
plus close evidence for outcomes.

Older exporter revisions fail closed. Use the historical repository revision
that created those rows; do not adapt, relabel, or combine them with V9.

## Leakage Boundary

Allowed model features are facts available at first touch:

- pivot timeframe, level, direction, normalized ladder geometry, and source
  range;
- previous M1 Bid close, trigger Bid/Ask, spread, and trigger-time calendar;
- six context rows of Stoch Structure slots `0..2` and raw `%B` shifts `0..5`;
- observation-time broker facts that do not depend on later send or outcome.

The following are labels or audit-only facts and must not enter training
features: window terminal state, route admission result, pre-send/send result,
broker fill, trailing milestones, final stop, close facts, duration, terminal
reason, and realized profit.

## Retest And Confluence Boundary

The offline retest table freezes the previous completed close relative to the
anchor's immutable tested pivot price. It records `BUY_RETEST`, `SELL_RETEST`,
`EQUAL_NEUTRAL`, or explicit `UNAVAILABLE` for M1, M15, M30, H1, H4, and D1.
M1 is a context/audit fact as well as the first-touch direction check; it is not
duplicated in the opt-in model columns.

Do not confuse macro side context with an independent macro touch. A confluence
member exists only for an actual V9 first-touch attempt and remains active on
`[member_trigger_broker_time, member_window_terminal_broker_time)`. The member
set is causal, bounded, and frozen at each same-trigger batch. Mixed BUY/SELL
members, reversal interpretations at any level, and arbitrary timeframe
combinations are expected research facts. Support/resistance names do not force
direction, combinations are unordered, and `retest_sequence` is deliberately
absent.

The opt-in feature contract `pivot_first_touch_confluence_v1` contains only
five macro retest categories and bounded peer/context counts. It excludes M1
retest type, IDs, canonical pattern strings, targets, outcomes, trailing facts,
and every future-only field. DuckDB/Parquet remains the authoritative query
layer; XGBoost is only an optional offline consumer.

## Target Families

- `broker_outcome`: filled positions with broker-confirmed closes; use for
  profitability or realized-outcome research.
- `admission`: all first-touch attempts, including denied and unfilled rows;
  use for separate operational admission analysis.

Do not mix the two families or treat denied attempts as broker losses. The
pivot audit may compare structural break-even with realized money, but it does
not manufacture simulated TP-before-SL labels.

## Splitting And Artifacts

Chronological holdout and walk-forward folds keep each
`(run_id, symbol, window_id)` group in one partition so confluence identities
from the same window cannot cross train/evaluation boundaries.

Confluence feature datasets additionally group by `research_group_id`, which is
the symbol plus D1 active broker window and intentionally omits run ID. This
keeps duplicate historical periods across runs together. A valid feature
ablation uses the exact same row identities, targets, groups, gap, folds, and
holdout for both the base and confluence columns; native base and confluence
metrics with different grouping policies are not directly comparable.

Generated datasets, audits, reports, and models remain under ignored
`artifacts/` directories. Model folders are marked `OFFLINE_RESEARCH_ONLY` and
are not deployment packages. A future runtime integration would require a new
explicit plan, frozen feature parity evidence, safety review, tester-only
staging, human acceptance, and separate live-rollout authorization.

The completed natural-run evidence, paired cost measurements, right-censoring
handling, and fixed ablation are recorded in
`docs/research/pivot-retest-confluence-offline-acceptance.md`.

## Historical Work

Archived execution, exporter, ML, and pattern experiments remain immutable
under `docs/plans/archive/` and `docs/research/archive/`. They explain their own
historical revisions only and are not active runbooks.

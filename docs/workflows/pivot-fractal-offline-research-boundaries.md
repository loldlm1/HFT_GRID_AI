# Pivot Fractal Offline Research Boundaries

Current research starts from strict `PIVOT_FRACTAL_V2` schema V10 exports and
ends in local DuckDB/Parquet datasets, deterministic audits, reports, and
offline XGBoost candidates. Nothing in this workflow runs inside MT5 or changes
broker execution.

Use `docs/workflows/pivot-fractal-statistics-flow.md` for export, validation,
dataset, audit, training, and human acceptance commands.

## Runtime Separation

```text
deterministic Macro pivot trigger
-> route and broker safety decisions inside MQL5
-> optional V10 fact persistence
-> strict offline validation
-> leakage-safe research matrix and binary cohort
-> deterministic audit and optional offline XGBoost
```

- Feature export never authorizes, denies, resizes, delays, or redirects a
  trade.
- The MQL5 runtime has no model loader, model score, research threshold,
  inference mode, pattern matcher, or playback denial.
- Broker session, permissions, Bid/Ask, structural geometry, stops/freeze,
  volume, margin, `OrderCheck`, send retcodes, magic, ticket ownership, and
  reconciliation remain deterministic MQL5 responsibilities.
- Missing or malformed feature data invalidates research evidence while the
  independently valid broker path remains unchanged.

## Strict Input Contract

The validator requires schema `10`, engine `PIVOT_FRACTAL_V2`, feature set
`schema_v10_macro_micro_pivot_bands`, exact frozen headers, one Macro window,
unique consumed identities, seven ordered levels, PP arming coherence, direct
support-buy/resistance-sell direction, exact structural routes, price-distance
1R, broker execution-chain ownership, decomposed costs, and strict summary
counts.

Each run contains exactly six TSV files. V9 and older exporter revisions fail
closed. Use the historical repository revision that created those rows; do not
adapt, relabel, or combine them with V10.

## Trigger-Time Feature Boundary

The approved model features are available when a pivot trigger is observed:

- categorical `symbol`, `level_id`, `direction`, analysis weekday, and
  analysis session;
- normalized Micro shift-0 and Macro shift-1 bandwidth;
- Micro `%B 0..5`;
- Macro pivot `%B 0..5` using the immutable pivot price;
- trigger gap and spread normalized by structural risk distance;
- Macro source range normalized by Macro band width;
- cyclical analysis-time values.

Continuous values enter XGBoost directly. Audit reports may show quantile or
range bins for human interpretation, but bins do not replace the model inputs.

Raw Bid/Ask, pivot/source prices, SL/TP, volume, IDs, tickets, and account
balance remain identity or audit facts. Route/admission decisions, broker
checks, request/send results, fills, closes, slippage, costs, duration,
terminal reason, and P&L are future or outcome facts and must not enter model
features.

## Binary Outcome Boundary

The primary target is strict broker TP/SL:

- target `1`: feature-complete, fully closed, consistent `BROKER_TP` outcome;
- target `0`: feature-complete, fully closed, consistent `BROKER_SL` outcome.

Manual, mixed-reason, stop-out, expert, other, feature-incomplete, denied,
failed-send, and censored rows remain required audit facts. They are excluded,
not relabeled as losses. Realized P&L and slippage are diagnostics and must not
be used to select the primary binary cohort because that would introduce
post-outcome selection bias.

Exact price-distance 1R does not imply exact monetary symmetry. Research must
keep quote expected loss/profit, reference-budget utilization, fill/close
slippage, commission, swap, fee, gross/net P&L, budget R, and executable-risk R
as separate explainable quantities.

## Splitting And Configuration

Purged chronological holdout and expanding walk-forward folds keep every row
from the same `(symbol, Macro timeframe, active Macro bar open)` in one
partition across duplicate run IDs. A training row is eligible only when its
broker close time is strictly earlier than the minimum broker trigger time in
the validation fold. Analysis time never orders causal splits.

The initial research contract fails closed when runs mix config IDs,
Macro/Micro timeframes, Bands policy, lot mode/size, reference balance, feature
set, or account currency. Fixed-lot and fixed-reference risk studies remain
separate.

## Artifacts And Promotion

Generated datasets, audits, reports, and models remain under ignored
`artifacts/` directories. Model folders are marked `OFFLINE_RESEARCH_ONLY` and
are not deployment packages. A future runtime integration requires a new
explicit plan, frozen feature parity evidence, safety review, tester-only
staging, human acceptance, and separate live-rollout authorization.

## Historical Work

Archived V9 execution, exporter, retest/confluence, ML, and pattern experiments
remain immutable under `docs/plans/archive/` and `docs/research/archive/`.
They explain their own historical revisions only and are not active runbooks or
acceptance evidence for V2/V10.

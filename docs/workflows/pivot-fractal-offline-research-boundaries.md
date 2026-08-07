# Pivot Fractal Offline Research Boundaries

Current research starts from strict `PIVOT_FRACTAL_V2` schema V11 exports and
ends in local DuckDB/Parquet datasets, deterministic audits, reports, and
offline XGBoost trial candidates. Nothing in this workflow changes the single
real structural 1R broker path.

Use `docs/workflows/pivot-fractal-statistics-flow.md` for export, validation,
dataset, audit, training, and human acceptance commands.

## Runtime Separation

```text
deterministic Macro pivot trigger
-> route and broker safety decisions inside MQL5
-> one real structural 1R broker attempt
-> optional V11 virtual matrix and parity fact persistence
-> strict offline validation
-> leakage-safe policy trials, chains, broker outcomes, and calibration
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

The validator requires schema `11`, engine `PIVOT_FRACTAL_V2`, feature set
`schema_v11_pivot_trial_matrix`, exact frozen headers, one Macro window, unique
origins, the sixteen-cell index-0 matrix, contiguous policy retries, exact
integer-R geometry, quote-side ownership, distance and boundary rules, broker
execution ownership, parity joins, decomposed money lanes, and strict summary
counts.

Each run contains exactly eight TSV files. V9/V10 exporter revisions fail
closed. Use the historical repository revision that created those rows; do not
convert, relabel, dual-write, or combine them with V11.

## Trigger-Time Feature Boundary

The approved model features are available at the matrix or retry entry:

- categorical `symbol`, `level_id`, `direction`, `sl_policy`, TP multiple,
  retry index, analysis weekday, and analysis session;
- frozen origin Micro raw width and normalized entry Micro/Macro bandwidth;
- entry Micro `%B 0..5`;
- entry Macro pivot `%B 0..5` using the immutable origin pivot;
- trigger/retry gap and spread normalized by trial risk distance;
- Macro source range normalized by Macro band width;
- cyclical analysis-time values.

Continuous values enter XGBoost directly. Audit reports may show quantile or
range bins for human interpretation, but bins do not replace the model inputs.

Raw Bid/Ask, pivot/source prices, SL/TP, volume, IDs, tickets, and account
balance remain identity or audit facts. Eligibility, continuation, first touch,
terminal reason, duration, virtual gross, parity, broker checks, request/send
results, fills, closes, slippage, costs, and P&L are future or outcome facts and
must not enter model features.

## Outcome Boundaries

The primary target is virtual matrix first touch:

- target `1`: feature-complete eligible `TP_FIRST` matrix trial;
- target `0`: feature-complete eligible `SL_FIRST` matrix trial.

Ineligible and censored rows remain required facts with no target. Parity rows
are calibration-only and never enter model or policy support. Training weights
sum to `1.0` per `origin_id` within each dataset so retries do not manufacture
independent market support.

The separate broker target remains strict broker TP/SL:

- target `1`: feature-complete, fully closed, consistent `BROKER_TP` outcome;
- target `0`: feature-complete, fully closed, consistent `BROKER_SL` outcome.

Manual, mixed-reason, stop-out, expert, other, feature-incomplete, denied,
failed-send, and censored rows remain required audit facts. They are excluded,
not relabeled as losses. Realized P&L and slippage are diagnostics and must not
be used to select the primary binary cohort because that would introduce
post-outcome selection bias.

Virtual nominal R and virtual quote gross are counterfactual price-path facts.
They do not contain commission, swap, fee, latency, broker slippage, or net
profit. Broker deal history alone owns actual gross, costs, net, budget R, and
execution R. Parity calibration compares exact accepted request geometry to
the broker outcome. Parity observes threshold candidates only during the actual
trade session; broker-terminal-before-observed-touch shadows are censored and
excluded. Unexplained fully observed in-session TP/SL disagreement fails
integrity. Natural run completion remains independent from unlabelled row-level
run-end censoring.

## Splitting And Configuration

Purged chronological holdout and expanding walk-forward folds keep every row
from the same `(symbol, Macro timeframe, active Macro bar open)` in one
partition across duplicate run IDs. A virtual training row is eligible only
when its terminal time is strictly earlier than the minimum declared broker
time in the validation fold. Analysis time never orders causal splits.

The research contract fails closed when runs mix config IDs, Macro/Micro
timeframes, Bands policy, matrix percentages/TPs, quote sides, distance policy,
retry/capacity policy, lot mode/size, reference balance, feature set, or account
currency. Fixed-lot and fixed-reference risk studies remain separate.

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
acceptance evidence for V2/V11.

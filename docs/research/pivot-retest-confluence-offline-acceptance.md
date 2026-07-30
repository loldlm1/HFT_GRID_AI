# Pivot Retest Confluence Offline Acceptance

**Date:** 2026-07-30
**Status:** Accepted for offline research; not approved for MT5 runtime use

## Scope And Provenance

This acceptance uses only the natural strict V9 run:

```text
run_id: sprint9_natural_us30_final_20260112_20260725
symbol: US30
schema: 9
engine: PIVOT_FRACTAL_V1
broker session: EXNESS_SESSION
pivot timeframes: M15, M30, H1, H4, D1
target family: broker_outcome
```

The source run completed naturally from broker time `2026-01-12 00:00:00`
through `2026-07-24 20:54:59`. Its summary reports `export_status=OK`,
`completion_status=NATURAL`, and zero feature-incomplete, duplicate-identity,
referential-integrity, or row-integrity errors. The rejected `us30_test_run_1`
run is not present in any acceptance manifest.

| Source table | Rows |
| --- | ---: |
| Pivot windows | 23,370 |
| Pivot levels | 163,590 |
| First-touch attempts | 49,716 |
| Feature rows (six per attempt) | 298,296 |
| Execution checks | 147,047 |
| Trailing events | 40,538 |
| Broker-confirmed outcomes | 48,431 |

The causal clock is broker time. Analysis timestamps and DST offsets remain
export context only.

## Derived Integrity

The first-touch identity remains `(symbol, timeframe, active_bar_open, level)`.
Each attempt receives exactly six immutable prior-close contexts: M1, M15, M30,
H1, H4, and D1. A macro context is not a claim that the macro timeframe had an
independent touch; it is the latest causal completed close relative to the
anchor's tested price. An independent member exists only when a strict V9
first-touch attempt exists for that member identity.

| Derived fact | Result |
| --- | ---: |
| Retest-context rows | 298,296 (6 x 49,716) |
| Future or expired context matches | 0 |
| Unavailable macro contexts | 0 |
| M1 direction mismatches | 0 |
| Confluence member rows | 384,086 |
| Confluence snapshots | 49,716 |
| Maximum active members | 29 (bound 35) |
| Mean active members | 7.7256 |
| Future member rows | 0 |
| Expired member rows | 0 |
| Duplicate member keys | 0 |
| Snapshot interval violations | 0 |

Members are active on the half-open broker interval
`[member_trigger, member_window_terminal)`. Same-time candidates see one frozen
batch. Directions are not required to agree, timeframe order is not required,
and support/resistance roles remain dynamic. There is no `retest_sequence`.
Pattern combinations are unordered sets; canonical token ordering is for stable
storage and display only.

The run contains `48,443` broker-confirmed fills but only `48,431` closed
outcomes. The twelve fills without a close at the run boundary are right
censored and remain outside the broker-outcome target; they are not relabeled as
losses. The audit separately retains `1,273` denied attempts and does not mix
admission facts with broker outcomes.

## Pattern Audit

The audit retained all atomic rows and summarized pairs only for interpretation:

- `1,019` unordered pairs were observed before support filtering.
- `706` pairs met the minimum support of `20` distinct D1 research groups.
- Example mixed-direction pattern `BUY:PERIOD_M15:PP + SELL:PERIOD_D1:R1`
  has `4,112` anchor rows across `72` D1 groups.

The pair reports expose anchor support, group support, active intervals, broker
outcomes, and Wilson intervals. Minimum support never deletes atomic facts and no
high-order power set is materialized.

## Feature Lanes

The default dataset/model lane remains unchanged:

- Base contract: `82` raw features and `183` encoded features.
- Grouping: `pivot_window_identity`.
- Dataset: `artifacts/datasets/pivot_retest_base_acceptance/`.
- Model: `artifacts/models/pivot_retest_base_acceptance/`.

The opt-in confluence lane adds only trigger-time, bounded facts:

- Confluence contract: `98` raw features and `214` encoded features.
- Five categorical macro retest types (`M15` through `D1`), plus eleven bounded
  counts for macro sides and active peers.
- M1 retest type is persisted for audit but excluded because it restates the
  first-touch direction.
- IDs, canonical token strings, targets, outcomes, trailing facts, and all
  future-only columns are excluded.
- Grouping: `symbol_d1_active_broker_window`.
- Dataset: `artifacts/datasets/pivot_retest_confluence_acceptance/`.
- Model: `artifacts/models/pivot_retest_confluence_acceptance/`.

Both lanes contain exactly `48,431` training rows and identical identity/target
sets. All model manifests say `OFFLINE_RESEARCH_ONLY` and
`runtime_artifact_emitted=false`.

## Paired Build And Audit Cost

The two full builds used the same source run, target family, workstation, and
output filesystem. Wall time is affected by filesystem cache state, so the
stage timings and bytes are the more stable comparison.

| Build | Wall time | User + system | Peak RSS | Parquet bytes |
| --- | ---: | ---: | ---: | ---: |
| Base | 6:02.98 | 254.61 s | 1,864,768 KB | 44,811,172 |
| Confluence | 4:06.03 | 241.20 s | 1,875,644 KB | 44,986,169 |

The confluence build added `174,997` normalized Parquet bytes. Its measured
causal stages were `4.182 s` for retest context, `1.739 s` for the bounded
confluence sweep, and `10.848 s` for persistence. The base run measured
`5.657 s`, `1.777 s`, and `11.945 s` respectively. The implementation contains
no quadratic full-history interval join; active membership is a bounded event
sweep with a maximum of 35 members per snapshot.

A warm repeat of the base build completed in `4:18.19` with context `3.349 s`,
sweep `1.680 s`, and persistence `8.924 s` (peak RSS `1,878,476 KB`). The first
base pass was a cold-cache observation just above the five-second context
budget; the repeat and confluence acceptance pass the budget. The variance is
recorded rather than treated as a performance guarantee.

The unordered audit completed in `48.69 s` with peak RSS `1,472,344 KB`.

## Fixed Ablation

The ordinary base and confluence models use their declared native grouping
policies. To isolate feature effect, the acceptance also created
`artifacts/datasets/pivot_retest_base_d1_ablation/`: the confluence training
matrix with the 16 confluence feature columns removed, while retaining the same
`research_group_id` values. The parity evidence is in
`artifacts/acceptance_logs/pivot_retest_ablation_parity.json`.

The matched lanes use the same `167` D1 groups, `134` training groups (`38,713`
rows), `33` holdout groups (`9,718` rows), four walk-forward folds, and a one
group gap. Prediction files have zero identity/target mismatches for `30,270`
fold rows and `9,718` holdout rows.

The matched baseline was materialized by selecting the confluence training
matrix while excluding exactly these sixteen columns:

```text
m15_retest_type, m30_retest_type, h1_retest_type, h4_retest_type, d1_retest_type
macro_buy_retest_count, macro_sell_retest_count, macro_neutral_count
active_peer_count, active_timeframe_count, active_buy_peer_count,
active_sell_peer_count, aligned_peer_count, opposed_peer_count,
neutral_peer_count, same_trigger_peer_count
```

Its manifest declares the base feature contract but retains
`research_group_id`. `EXCEPT ALL` checks over identity and target columns are
zero in both directions for the default base, confluence, and matched baseline
matrices; the same check is recorded in
`artifacts/acceptance_logs/pivot_retest_ablation_parity.json`.

### Classification

Values are `base / confluence`; lower log loss is better.

| Partition | Rows | Balanced accuracy | ROC AUC | Average precision | Precision | Recall | Log loss |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Fold 1 | 7,579 | 0.503337 / 0.502442 | 0.516112 / 0.515632 | 0.309039 / 0.305549 | 0.378151 / 0.324444 | 0.020436 / 0.033152 | 0.612983 / 0.616584 |
| Fold 2 | 7,625 | 0.501290 / 0.501195 | 0.550583 / 0.545568 | 0.345114 / 0.341359 | 0.362500 / 0.358025 | 0.012273 / 0.012273 | 0.616902 / 0.618329 |
| Fold 3 | 7,389 | 0.501993 / 0.502020 | 0.566607 / 0.568018 | 0.336589 / 0.340701 | 0.365854 / 0.382353 | 0.013921 / 0.012065 | 0.600075 / 0.599213 |
| Fold 4 | 7,677 | 0.499459 / 0.500549 | 0.542896 / 0.536847 | 0.325580 / 0.323497 | 0.260870 / 0.333333 | 0.005233 / 0.007414 | 0.614797 / 0.615851 |
| Holdout | 9,718 | 0.500829 / 0.499949 | 0.539221 / 0.544951 | 0.321753 / 0.326162 | 0.352941 / 0.280000 | 0.006429 / 0.002500 | 0.603869 / 0.601237 |

### Regression

Values are `base / confluence`; actual mean profit is the same target sample.

| Partition | Rows | MAE | RMSE | Actual mean profit | Predicted mean profit | Correlation |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Fold 1 | 7,579 | 6.189061 / 5.941649 | 10.161993 / 9.963853 | -0.139689 | 2.309377 / 1.890814 | -0.017953 / -0.018620 |
| Fold 2 | 7,625 | 5.215982 / 5.108693 | 10.215454 / 9.989227 | -0.025464 | 0.256245 / 0.137975 | -0.052149 / -0.042390 |
| Fold 3 | 7,389 | 3.388274 / 3.401265 | 6.261431 / 6.348841 | -0.182730 | -0.083580 / -0.054986 | 0.094518 / 0.081041 |
| Fold 4 | 7,677 | 4.059051 / 4.076119 | 8.244734 / 8.281470 | -0.142656 | -0.996561 / -1.016953 | -0.174350 / -0.196108 |
| Holdout | 9,718 | 5.291941 / 4.890477 | 7.421762 / 6.987253 | -0.267366 | 2.573610 / 2.005973 | 0.024580 / 0.050933 |

### Interpretation

The confluence lane does not show a stable classification improvement:
balanced accuracy is effectively chance, recall remains very low, and fold ROC
AUC/AP changes are mixed. Holdout ROC AUC, average precision, and log loss move
slightly in the favorable direction, while precision and recall worsen. The
regression holdout error and correlation improve, but folds 3 and 4 degrade
slightly and predicted profit remains positively biased while actual mean profit
is negative. This is inconclusive research evidence, not production alpha.

## Reproduction And Boundaries

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root /tmp/hft-grid-ai-sprint9-evidence/PivotFractalV9/runs \
  --run-id sprint9_natural_us30_final_20260112_20260725 \
  --dataset-id pivot_retest_base_acceptance \
  --target-family broker_outcome --overwrite

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root /tmp/hft-grid-ai-sprint9-evidence/PivotFractalV9/runs \
  --run-id sprint9_natural_us30_final_20260112_20260725 \
  --dataset-id pivot_retest_confluence_acceptance \
  --target-family broker_outcome \
  --research-feature-set-id pivot_first_touch_confluence_v1 --overwrite

.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id pivot_retest_confluence_acceptance \
  --audit-id pivot_retest_confluence_acceptance \
  --minimum-group-support 20 --overwrite
```

DuckDB/Parquet remains authoritative for filtering and aggregation. XGBoost is
an optional offline consumer. No model, pattern, score, or confluence result
authorizes, denies, delays, or changes an MT5 order. A future runtime proposal
would require a separate plan, feature-parity evidence, safety review, tester
acceptance, and explicit rollout authorization.

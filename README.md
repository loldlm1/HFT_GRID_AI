# HFT Grid AI

MetaTrader 5 Expert Advisor for deterministic H1 pivot evidence, nested M10
deep-pivot research, configured-Micro indicator capture, and one small broker
execution path. The entrypoint is `HFT_Grid_AI.mq5`.

## Active Flow

```text
broker tick
-> reconcile the one real structural H1 1R broker lane
-> resolve active H1 structural/midpoint virtual lanes
-> refresh causal H1 and M10 classic-pivot windows
-> consume live-Bid H1 pivot triggers
-> capture one H1-origin Micro/Macro feature snapshot
-> submit at most one structural 1R FOK broker request
-> declare structural and 50%-midpoint H1 virtual lanes at 1R/2R/3R/5R
-> freeze active same-direction H1 parents
-> consume one shared M10 deep event per pivot identity
-> capture one configured-Micro snapshot on that event
-> resolve shared deep 1R/2R/3R geometry per parent link
-> export strict schema V13 virtual, deep, broker, and calibration facts
```

Defaults are Micro `M3`, Deep `M10`, and Macro `H1`. Every timeframe follows
broker-native bars; the EA never creates wall-clock aggregates or synthetic
missing candles.

## Inputs

The public surface is intentionally small:

| Group | Inputs |
| --- | --- |
| Market data time | `Broker_Session`, `Macro_Timeframe`, `Deep_Timeframe`, `Micro_Timeframe` |
| Broker execution | `Lot_Type`, `Lot_Strategy_Size` |
| Signal export | `Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id` |
| Developer debug | `Enable_Logs`, `Enable_File_Logs` |

Timeframes must be explicit, supported, distinct, and ordered by
`PeriodSeconds` as `Micro < Deep < Macro`. No removed licensing, account,
protection, spread-threshold, direction/concurrency, multi-leg, runtime-model,
or compatibility input is supported.

## H1 Structural Lifecycle

Classic `PP`, `S1..S3`, and `R1..R3` come from the previous completed Macro
candle. H1 identity is `(symbol, Macro timeframe, active bar open, level)`;
the first trigger consumes it even if broker routing is denied or fails.

- `S1..S3` trigger buys on live `Bid <= level`.
- `R1..R3` trigger sells on live `Bid >= level`.
- PP first arms from a strict Bid side, then triggers on the return touch.
- Buys trigger on Bid and enter at Ask; sells trigger and enter at Bid.

The next outward pivot is the structural stop. `S3` and `R3` use the existing
one-step extrapolated boundary. Export-enabled origins declare exactly eight
H1 research lanes:

| Entry policy | Entry time | Targets | Re-entry |
| --- | --- | --- | --- |
| `STRUCTURAL` | Original H1 trigger | `1R`, `2R`, `3R`, `5R` | None |
| `MIDPOINT_50` | First executable touch of the exact halfway level toward the stop | `1R`, `2R`, `3R`, `5R` | None |

The midpoint remains armed while any structural lane from the origin is active,
including after the source H1 bar rolls. If every structural lane exits first,
untouched midpoint lanes finish as `NOT_TRIGGERED`. Once touched, all four
midpoint ratios share the actual midpoint entry timestamp and run independently.

## Deep M10 Evidence

M10 observation is research-only and is enabled only while at least one entered
same-direction H1 virtual lane or confirmed broker position is active. H1
terminal transitions run before deep discovery on each tick.

- One event identity is `(symbol, Deep timeframe, active Deep bar, level)`.
- Direction is the consumed event outcome, not a second identity dimension.
- One event owns one configured-Micro feature vector; default `M3` is descriptive,
  not hard-coded when the input differs.
- Parent links associate the event with every active eligible H1 parent without
  duplicating the feature vector.
- Deep geometry is shared at the event for `1R`, `2R`, and `3R` only.
- Outcomes are link-scoped. A parent exit produces `CENSORED_PARENT_EXIT`, and
  a run stop produces `CENSORED_RUN_END`; neither is an SL loss.
- No deep lane can reach `OrderSend` or alter the real broker lane.

Admission is atomic. If the full event/link/trial/outcome fan-out cannot fit,
the pivot identity is consumed and one `CAPACITY_REJECTED` event is exported
without partial children.

## Features And Durations

Export uses four cached handles only: Macro/Micro Bands and Macro/Micro
Stochastic. Bands are fixed to period `21`, shift `0`, deviation `2.0`, SMA,
and `PRICE_WEIGHTED`; Stochastic is fixed to `5/3/3`, `MODE_SMA`, and
`STO_CLOSECLOSE`.

- H1-origin Micro/Macro features live once on `signal_origins.tsv`.
- Deep configured-Micro features live once on `deep_pivot_events.tsv`.
- `%B` uses the immutable touched pivot and remains unclipped.
- Raw, SMA 5, SMA slope, state, Band base-line/slope, and shift-0 widths are
  exported for the documented shifts.
- Missing features affect research completeness only; they never block a valid
  broker route.

`h1_structural_lifecycle_seconds` is the exact broker-time duration of a
completed H1 virtual or broker parent from its own entry to close.
`m10_parent_age_seconds` is the exact age of that parent when the M10 event
triggers. Values are not rounded or capped. Downstream minute filters must use
exact predicates such as `seconds <= minutes * 60`; completed H1 duration is
retrospective and must not be treated as a deployable causal feature.

## Broker Boundary

Only the structural H1 `1R` lane can create exposure. The fresh pre-send quote
rebuilds exact 1:1 price-distance TP geometry, and the EA rechecks session,
permissions, Bid/Ask, stops/freeze, volume, FOK support, margin, and
`OrderCheck` immediately before `OrderSend`.

Broker SL/TP are immutable after fill. There is no trailing, break-even,
partial close, resize, or protection-modification path. One accepted request
creates one exact broker-parity shadow for calibration only. V13 uses a distinct
magic namespace and never adopts older-engine positions.

## Strict V13 Research

When export is enabled, MT5 writes exactly twelve TSV files under:

```text
Common\Files\PivotFractalV13\runs\<run_id>\
```

```text
run_manifest.tsv
pivot_windows.tsv
signal_origins.tsv
virtual_trials.tsv
virtual_outcomes.tsv
deep_pivot_events.tsv
deep_pivot_parent_links.tsv
deep_virtual_trials.tsv
deep_virtual_outcomes.tsv
execution_checks.tsv
broker_outcomes.tsv
run_summary.tsv
```

Validate, build, audit, and select one explicit offline training grain with:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV13/runs> \
  --run-id <run_id> \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV13/runs> \
  --run-id <run_id> \
  --dataset-id <dataset_id>

.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id <dataset_id> \
  --audit-id <audit_id> \
  --minimum-group-support 30

.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <dataset_id> \
  --model-id <model_id> \
  --feature-set-id schema_v13_hft_deep_pivot_features.h1
```

Use `schema_v13_hft_deep_pivot_features.deep_parent` for the separate deep
cohort. The builder keeps deep event features at native event grain and joins
them only during explicit deep training. Censored, ineligible, parity, and
not-triggered facts never become target-zero losses. All model artifacts remain
`OFFLINE_RESEARCH_ONLY` and cannot influence MT5 execution.

## Validation Status

Sprints 1-6 have strict static and Python evidence. Sprint 7 publishes the V13
handoff. One final real MetaEditor compile and human Strategy Tester/chart
acceptance remain mandatory in Sprint 8 before the downstream Django V13
cutover can begin. Live rollout is not authorized.

## Documentation

- `AGENTS.md`: implementation, safety, and sprint validation rules.
- `docs/architecture/market-data-broker-executor.md`: runtime ownership model.
- `docs/workflows/pivot-fractal-statistics-flow.md`: export and research flow.
- `docs/workflows/pivot-fractal-offline-research-boundaries.md`: causal and
  retrospective research boundaries.
- `docs/environment/mt5-agentic-workflows.md`: paths, compile, and artifacts.
- `docs/research/pivot-fractal-v13-producer-handoff.md`: downstream contract.
- `docs/plans/archive/` and `docs/research/archive/`: historical evidence.

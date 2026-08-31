# Pivot Fractal V13 Statistics Flow

## End-To-End Flow

```text
H1 pivot trigger
-> H1-origin Micro/Macro snapshot
-> structural/midpoint H1 1R/2R/3R/5R lanes
-> optional structural 1R broker request and parity shadow
-> active same-direction H1 parent registry
-> shared causal M10 pivot event
-> one configured-Micro event snapshot
-> parent links and shared deep 1R/2R/3R trials
-> link-scoped TP/SL/censor outcomes
-> twelve strict V13 TSV files
-> typed DuckDB/Parquet artifacts
-> V13 audit
-> explicit offline H1 or deep training grain
```

Export and offline research remain observational. They cannot alter the one
structural H1 `1R` broker path.

## Evidence Grains

| File | Grain | Authoritative facts |
| --- | --- | --- |
| `run_manifest.tsv` | key/value per run | Schema, engine, timeframes, fixed policies, capacities, approval boundary |
| `pivot_windows.tsv` | H1 or M10 window | Previous completed candle, pivot ladder, PP state, lifecycle |
| `signal_origins.tsv` | consumed H1 pivot | Trigger, H1 geometry, one Micro/Macro feature vector |
| `virtual_trials.tsv` | H1 lane or parity shadow | Entry policy, R, entry, normalized geometry, eligibility |
| `virtual_outcomes.tsv` | H1/parity trial | First touch, H1 duration, binary eligibility/exclusion |
| `deep_pivot_events.tsv` | consumed M10 pivot | Direction, trigger, one configured-Micro vector, admission |
| `deep_pivot_parent_links.tsv` | event x active H1 parent | Parent identity, entry, `m10_parent_age_seconds` |
| `deep_virtual_trials.tsv` | event x deep R | Shared entry/stop/target geometry at `1R/2R/3R` |
| `deep_virtual_outcomes.tsv` | parent link x deep trial | TP/SL or parent/run censor evidence |
| `execution_checks.tsv` | observed broker check | Fresh authorization and request/send/reconciliation facts |
| `broker_outcomes.tsv` | confirmed real position | Fill/close, money, costs, broker H1 duration |
| `run_summary.tsv` | one run seal | Exact counts, high-water marks, integrity, completion |

H1 features never live on lane rows. Deep features never live on parent-link or
ratio rows. Broker parity is calibration-only and not one of the eight H1 lanes.

## H1 Lane Semantics

Each origin declares `STRUCTURAL` and `MIDPOINT_50` at `1R`, `2R`, `3R`, and
`5R`. There are no Bands-width policies or retries. Structural entry is the H1
trigger. Midpoint entry occurs only on the exact halfway touch toward the next
outward pivot. A pending midpoint remains armed while any structural lane from
the origin is active; H1 bar rollover and R5 alone do not control it.

Completed H1 TP/SL rows own exact `h1_structural_lifecycle_seconds`. A midpoint
duration starts at midpoint entry. `NOT_TRIGGERED`, `INELIGIBLE`, and
`CENSORED_RUN_END` remain explicit and have no completed duration or binary
target.

## Deep Event Semantics

M10 capture requires at least one entered eligible same-direction H1 virtual
parent or confirmed broker fill. Parent state is frozen immediately before
discovery, after H1 terminal transitions. One consumed M10 identity owns one
configured-Micro snapshot and three shared trials. Links are never added
retroactively.

Every link records exact `m10_parent_age_seconds` at the M10 trigger. Deep
outcomes are resolved separately for each link and ratio. A parent exit censors
only unresolved outcomes for that parent; other linked parents continue. Deep
`5R`, retries, per-ratio events, and broker sends do not exist.

`CAPACITY_REJECTED` means the complete event fan-out could not be reserved. It
has no partial links/trials/outcomes and no binary target.

## Duration Research Rules

The producer stores exact broker seconds with no maximum:

```text
h1_structural_lifecycle_seconds = parent close - parent entry
m10_parent_age_seconds = M10 trigger - parent entry
```

Downstream public selectors are separate and `<=`-only:

```text
h1_structural_lifecycle_seconds <= selected_minutes * 60
m10_parent_age_seconds <= selected_minutes * 60
```

The H1 selector requires a confirmed completed virtual or broker lifecycle and
is retrospective segmentation. It cannot be used as a causal child condition,
model feature, or deployable execution claim because it is unknown at trigger
time. The M10-age selector is causal at trigger time and applies only to deep
parent links. Applying both selectors uses AND semantics without deleting later
raw evidence or imposing a producer capture cap.

## Validate And Build

```bash
export PIVOT_RUNS_ROOT="<Common Files>/PivotFractalV13/runs"
export PIVOT_RUN_ID="<run_id>"
export PIVOT_DATASET_ID="<dataset_id>"
export PIVOT_AUDIT_ID="<audit_id>"

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id "$PIVOT_RUN_ID" \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id "$PIVOT_RUN_ID" \
  --dataset-id "$PIVOT_DATASET_ID"

.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id "$PIVOT_DATASET_ID" \
  --audit-id "$PIVOT_AUDIT_ID" \
  --minimum-group-support 30
```

The builder writes typed copies of all twelve source files plus:

- `h1_lane_long.parquet`: all eight H1 lane outcomes;
- `h1_lane_wide.parquet`: one eight-cell origin comparison row;
- `eligible_h1_trials.parquet`: feature-complete H1 TP/SL rows;
- `deep_parent_long.parquet`: all link/ratio outcomes without copied event
  features;
- `eligible_deep_trials.parquet`: feature-complete deep TP/SL rows;
- `broker_virtual_calibration.parquet`: accepted-request parity pairs.

Origin weights sum to one per deterministic H1 origin across repeated runs.
Deep event weights are a separate support diagnostic. Audit reports row, event,
parent, and unique-origin support independently.

## Offline Training

Training requires one explicit grain:

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id "$PIVOT_DATASET_ID" \
  --model-id <h1_model_id> \
  --feature-set-id schema_v13_hft_deep_pivot_features.h1

.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id "$PIVOT_DATASET_ID" \
  --model-id <deep_model_id> \
  --feature-set-id schema_v13_hft_deep_pivot_features.deep_parent
```

The deep loader joins event features from `deep_pivot_events.parquet` only for
explicit training. H1 and deep cohorts cannot be silently combined. Duration,
terminal status, censoring, targets, broker money, and other future-only fields
are prohibited from model features. Artifacts remain
`OFFLINE_RESEARCH_ONLY`; no MT5 loader or runtime filter exists.

## Acceptance Sequence

1. Run Python compileall and all contract tests.
2. Validate and build a strict V13 run.
3. Audit with the required unique-origin support floor.
4. Confirm native feature ownership, lane/ratio counts, weights, censors,
   capacity, broker ownership, and parity.
5. Run the one final MetaEditor compile: `0 errors, 0 warnings`, regenerated
   `.ex5` metadata.
6. Human-test midpoint touch/no-touch, all H1 ratios, shared M10/Micro evidence,
   parent-specific censoring, R5 continuation without hard-coding, one broker
   structural 1R lane, export-off parity, DST, performance, and chart behavior.
7. Complete `docs/research/pivot-fractal-v13-producer-handoff.md` and its dated
   acceptance record before any Django V13 cutover.

Compilation and fixtures cannot replace the human Strategy Tester/chart gate.
No step authorizes live rollout.

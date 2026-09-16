# Deterministic Pivot V14 Research

This directory validates strict Pivot Fractal V14 exports and builds typed,
grain-aware offline research artifacts for `PIVOT_FRACTAL_V2`. It never loads a
model into MT5, authorizes execution, or emits a runtime-compatible artifact.

The [runtime contract](../../docs/architecture/market-data-broker-executor.md)
owns pivot/entry/stop/lifecycle behavior; the [current index](../../docs/README.md)
selects accepted source and evidence. Export, virtual/deep state and offline
artifacts cannot authorize, deny, delay, resize, duplicate, close or modify the
broker lane. Missing features affect research completeness only.

## Input Contract

Origin blocks are `origin_macro_*` and `origin_deep_*`; event blocks are
`deep_deep_*` and `deep_micro_*`. Each has a completeness flag; the snapshot
flag is the conjunction of its two flags. Missing blocks keep raw evidence and
exclude only the corresponding model cohort. Each snapshot uses its own
trigger and owning pivot; later Deep events never populate Macro features.

Links carry `parent_direction`, `deep_direction`, and `direction_relationship`.
Outcome `direction` is the Deep direction; `parent_direction` resolves the
origin. Both directions require entered eligible Macro parents; no standalone
Deep collection or retrospective parent attachment is allowed.

Each run contains exactly twelve TSV files in this order:

| File | Grain | Authoritative facts |
| --- | --- | --- |
| `run_manifest.tsv` | key/value per run | Schema, engine, periods, fixed policies, capacities and approval boundary |
| `pivot_windows.tsv` | H1 or M10 window | Completed source candle, ladder, PP state and window lifecycle |
| `signal_origins.tsv` | consumed H1 pivot | Trigger, geometry and one Macro/Deep feature vector |
| `virtual_trials.tsv` | H1 lane or parity shadow | Entry policy, R, entry, normalized geometry and eligibility |
| `virtual_outcomes.tsv` | H1/parity trial | First touch, H1 duration and binary eligibility/exclusion |
| `deep_pivot_events.tsv` | consumed M10 pivot | Direction, trigger, one Deep/Micro vector and admission |
| `deep_pivot_parent_links.tsv` | event x active H1 parent | Parent/event directions, ALIGNED/OPPOSED, entry and `m10_parent_age_seconds` |
| `deep_virtual_trials.tsv` | event x deep R | Shared 1R/2R/3R entry/stop/target geometry |
| `deep_virtual_outcomes.tsv` | parent link x deep trial | TP/SL or parent/run censor evidence |
| `execution_checks.tsv` | broker check | Observation, fresh checks, request/send and reconciliation facts |
| `broker_outcomes.tsv` | confirmed real position | Fill/close, money, costs and completed H1 duration |
| `run_summary.tsv` | run seal | Counts, high-water marks, integrity and completion |

The producer feature set is `schema_v14_hft_deep_pivot_features`. Compatible
runs must agree on `Micro < Deep < Macro` timeframes, H1 entry policies and
ratios, deep ratios, fixed indicator settings, capacity rules, money policy,
account currency, and feature identity. Active tooling rejects older schemas;
it does not convert or dual-load them.

V14 keeps evidence at explicit native grains:

- `signal_origins.tsv` owns one H1 Macro/Deep feature vector per origin.
- `deep_pivot_events.tsv` owns one Deep/Micro vector per shared M10 event.
- Parent links associate an event with active H1 virtual or broker parents.
- Deep outcomes resolve one `(parent link, deep trial)` pair.
- Broker parity remains calibration evidence outside H1/deep target cohorts.

The source root is `Common\Files\PivotFractalV14\runs\<run_id>\`. No older
root, header or feature identity is an intake alias. Preserve original source
exports; malformed or incompatible configurations are rejected, not migrated.
For Exness custom-symbol inputs, complete the applicable
[source/import/broker gates](../exness_tick_history/README.md#operator-validation-queue)
before selecting accepted research data. Keep broker/custom cohorts separate
and input-provenance sidecars outside the twelve-file run directory.

## Validate

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV14/runs> \
  --run-id <run_id> \
  --validate-only
```

Repeat `--run-id` for compatible runs. Every source column has one frozen
`VARCHAR`, `TIMESTAMP`, `BOOLEAN`, `BIGINT`, or `DOUBLE` type; unknown files,
headers, columns, and incompatible configurations fail closed.

### Large-Run Parent Chronology

The focused operational audit below uses bounded DuckDB memory and disk spill.
It checks parent identities, admission intervals, outcome chronology, censor
timestamps, binary labels and supporting counts. It does not replace the complete
semantic `--validate-only` gate above, which still loads full TSV rows into Python.

```bash
.venv/bin/python tools/deterministic_signal_ml/parent_chronology.py \
  --runs-root <PivotFractalV14/runs> --run-id <run_id> \
  --memory-limit-mb 4096 --report <new-report-outside-run.json>
```

Exit code 1 means a failed audit or invalid input. Reports are never written
inside source runs. All twelve exact V14 headers and the producer seal are checked;
the report lists the eight tables whose chronology columns were scanned.

Confirmed broker entry and close may occupy the same serialized second; an
exact lifecycle duration of zero is valid. Reversed clocks remain invalid. A
parent-exit censor uses the actual parent close time even if reconciliation
observes closure later; observed censor quotes are not completed trade returns.

A naturally completed historical run with **only** late broker-parent censor
timestamps may be recovered explicitly into a new directory:

```bash
.venv/bin/python tools/deterministic_signal_ml/parent_chronology.py \
  --runs-root <original-runs> --run-id <original-run-id> \
  --recover-run-id <distinct-recovered-id> \
  --recovered-runs-root <retained-output-directory> \
  --memory-limit-mb 4096 --report <new-recovery-report.json>
```

Recovery copies the twelve files, relabels their run ID and replaces only affected
terminal broker/analysis/offset triplets using the linked broker close record.
It preserves statuses, exclusion labels, null durations, quotes and features.
An adjacent `.corrections.jsonl` retains every original observation clock/quote
and replacement clock; `.provenance.json` retains original and derivative SHA-256
hashes, audit results and the exact transformation. These sidecars are part of the
recovered artifact and must stay with it. A derivative is never presented as a new
tester run or output of the fixed EA.

Recovery refuses existing destinations, sources changing during the operation,
incomplete seals, ambiguous identities, missing parent evidence, late completed
outcomes, invalid admission intervals and all other audit failures. More than
100,000 corrections require separate review; the map is intentionally bounded.
The corrected run is published only after its parent chronology audit passes.
Run full semantic validation separately when practical; passing this focused
audit alone is not full statistical acceptance or broker-equivalence evidence.

The [2026-09-09 acceptance record](../../docs/research/parent-close-chronology-acceptance-2026-09-09.md)
documents the retained XAUUSD derivative, validation scope and tester evidence.

## Build

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root <PivotFractalV14/runs> \
  --run-id <run_id> \
  --dataset-id <dataset_id>
```

The builder writes typed Parquet copies of all twelve source tables plus:

- `h1_lane_long.parquet`: all structural/midpoint H1 `1R/2R/3R/5R` outcomes,
  including ineligible, not-triggered, and run-censored evidence.
- `h1_lane_wide.parquet`: one eight-cell comparison row per H1 origin.
- `eligible_h1_trials.parquet`: feature-complete binary H1 TP/SL rows only.
- `deep_parent_long.parquet`: link-scoped deep `1R/2R/3R` outcomes without a
  duplicated Deep/Micro feature vector.
- `eligible_deep_trials.parquet`: feature-complete binary parent/ratio rows;
  event features remain absent and are joined only by the explicit deep trainer.
- `broker_virtual_calibration.parquet`: accepted-request parity paired with
  broker-history outcomes; it never enters either model target cohort.

Origin weights sum to `1.0` per deterministic `origin_id`, including repeated
run IDs. Deep event weights separately sum to `1.0` per `deep_event_id` for
support diagnostics. Training recomputes origin-balanced weights inside each
chronological training subset.

`h1_structural_lifecycle_seconds` is retrospective evidence and is non-null
only for a confirmed completed H1 virtual or broker lifecycle.
`m10_parent_age_seconds` is causal at the M10 trigger. Neither value is rounded
or capped. Downstream minute filters must use exact `<= minutes * 60`
predicates; censored, ineligible, and not-triggered rows remain separate support
evidence.

The two public minute selectors are independent inclusive predicates and combine
with AND. The H1 selector applies only to completed parent lifecycles and is
retrospective; it cannot be a causal child admission condition. The M10-age
selector applies to the linked parent at the deep trigger. Neither caps capture,
deletes later raw events or relabels censors; there is no implicit 30/60/120-minute
maximum. Midpoint duration begins at its actual midpoint entry. NOT_TRIGGERED,
INELIGIBLE and CENSORED_RUN_END rows have null completed H1 duration.

## Audit

```bash
.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id <dataset_id> \
  --audit-id <audit_id> \
  --minimum-group-support 30
```

The audit verifies manifest/table counts, H1 eight-lane cardinality, deep
event/link/trial/outcome joins, native Deep/Micro feature ownership,
origin/event weight
balances, parent-exit censoring, capacity peaks, broker ownership, and parity
agreement. Reports separate row, event, parent, and unique-origin support and
use origin-balanced performance summaries. A censor or ineligible row is never
relabeled as a binary loss.

Binary cohorts contain only feature-complete, eligible TP_FIRST/SL_FIRST rows.
Capacity, parity, denied/failed-send and incomplete evidence stays outside model
targets. Parent links are frozen at discovery, never added retroactively; a
CAPACITY_REJECTED event has no partial children. Shared deep outcomes remain
link-scoped, so another active parent may continue after one parent's censor.

## Train

Training requires one explicit evidence grain:

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <dataset_id> \
  --model-id <model_id> \
  --feature-set-id schema_v14_hft_deep_pivot_features.h1
```

```bash
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id <dataset_id> \
  --model-id <model_id> \
  --feature-set-id schema_v14_hft_deep_pivot_features.deep_parent
```

The H1 trainer reads `eligible_h1_trials.parquet`. The deep trainer reads
`eligible_deep_trials.parquet` and joins the Deep/Micro vector from
`deep_pivot_events.parquet` by `(run_id, config_id, deep_event_id)` at load time.
The two cohorts cannot be silently combined.

Both trainers use fixed seeds, origin-balanced sample weights, a purged
chronological holdout, and expanding walk-forward folds. All rows sharing the
same `(symbol, Macro timeframe, active Macro bar open)` remain in one partition
across duplicate runs. A training row is retained only when its terminal time
is strictly earlier than the validation boundary. Every training link/ratio of a
validation Deep identity is excluded across Macro bars and repeated exports.
Holdout Deep identities are also excluded from all model-selection folds.

H1 ablations add base lane/time context, widths, Macro Bands, Deep Bands,
Macro Stochastic, and Deep Stochastic. Deep ablations add base parent/M10-age
and direction relationship context, both widths, Deep/Micro Bands, and
Deep/Micro Stochastic. The actual manifest timeframes remain authoritative.
Lifecycle duration, terminal
status, targets, censoring, broker money, and other future-only fields are
prohibited from both feature sets.

Saved classifiers remain offline candidates under `artifacts/models/`. Their
manifest records the evidence grain, cutoff, weighting policy, and warnings,
and always carries `approval_state=OFFLINE_RESEARCH_ONLY` and
`runtime_artifact_emitted=false`.

## Fixture Gate

```bash
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
.venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
```

The tracked V14 fixture is intentionally too small to train a deployable model.
It includes aligned/opposed links, incomplete origin features, invalid money,
and parent/run censors. Focused mutations cover PP return, atomic rejection,
missing event blocks and malformed contracts. It proves strict build/audit joins and that both trainer selections reach their
minimum-support gate. Real ablations require the configured row, origin, class,
and chronological-window support.

## Acceptance And Downstream Boundary

For a new accepted producer/input: run affected Python contracts; validate/build
the strict run; audit with the configured unique-origin support floor (default
30); review native feature ownership, lane ratios, weights, censors, capacities,
broker ownership and parity. Insufficient support remains explicit, not waived.
Apply the [compile and human tester gates](../../docs/environment/mt5-agentic-workflows.md#strategy-tester-and-chart-acceptance)
when their source/behavior inputs change. Compilation/fixtures do not replace
chart verification, and chronology-only auditing is not full semantic acceptance.

The [MT5 V14 plan](../../pivot-fractal-v14-mt5-plan.md) owns the new producer
handoff gates; M4 will freeze exact downstream pins after native acceptance.
The [historical V13 handoff](../../docs/research/pivot-fractal-v13-producer-handoff.md)
records old pins and is not a V14 intake contract. Use the current index for
[Django intake compatibility](../../docs/README.md#downstream-django-intake).
For a fresh intake, provide exactly the twelve TSVs from a successful natural
completion; keep diagnostics/provenance sidecars outside the run directory and
wait for the downstream application's READY state. Its own repository governs
application changes, uploads and destructive data operations. Private raw runs,
generated datasets/models, binaries and account metadata are not vendored.

Superseded document history is recoverable through the current index. Active
tooling rejects V13 and earlier through minimal negative cases; no old-schema
loader or full legacy fixture remains. Offline
training produces no MT5 loader, runtime score/filter or online learner. No
artifact or acceptance sequence authorizes live rollout.

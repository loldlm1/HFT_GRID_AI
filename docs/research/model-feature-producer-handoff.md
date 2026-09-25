# Shared Model Feature Producer Handoff

This handoff defines what a later backend plan can consume from the MQL5
producers. The [canonical contract](../architecture/model-feature-dataset.md)
owns exact fields and behavior; the [project index](../README.md) owns current
acceptance status. No Django repository, importer, migration, API, discovery
program or deployment was changed or certified by this refactor.

## Version And Source Pins

| Identity | Accepted value |
| --- | --- |
| Dataset family / core schema | `MQL5_MODEL_FEATURES` / `1` |
| Base feature set | `macro_micro_standard_v1` |
| Extension schema | `1` |
| Pivot / outcome policy | `PIVOT_MACRO_V1` / `PIVOT_MACRO_OUTCOME_V1` |
| Candle / outcome policy | `CANDLE_PATTERN_ATR_V2` / `CANDLE_ATR_OUTCOME_V1` |
| EA property versions | Both `2.00` |
| Original framework implementation commit | `c0a118903bc19845c4faeed0ae59ffb852652f70` |
| Native compiler | MetaEditor 6184, optimized AVX2, zero errors/warnings |
| Default roles | Macro H1, Micro M3; fixed M1 structure source |
| Producer root | `Common/Files/MQL5ModelDatasetV1/runs/<run_id>/` |

The current Pivot entrypoint is `Pivot_Macro.mq5` / `Pivot_Macro.ex5`. The
2026-09-24 naming follow-up retains version `2.00`, engine `PIVOT_MACRO_V1` and
broker/dataset semantics. Its native compile, unchanged executable-source/include
checks and replacement source/binary pin are retained in
`.codex-artifacts/pivot-ea-rename-20260924/`. Current compile procedures use that
name; historical tester settings still identify the entrypoint used at the time.

The original accepted B03 binaries remain pinned for the recorded native runs:

| Entrypoint | EX5 bytes | SHA-256 |
| --- | ---: | --- |
| `HFT_Grid_AI.mq5` | 271412 | `495e221be7ab85f875fbe1c35b065e4e3ca38c3b99af35d68249ba92a1431b76` |
| `Candle_Pattern_Discovery.mq5` | 162966 | `c101563e9cb75a837f7403f0aab593f941531ec52c76653fb62ce75e8f9b2dea` |

The ignored `.codex-artifacts/model-feature-framework/s5/accepted-pin.json`
contains every source/include digest, binary size/mtime/hash and actual source
commit. It covers 40 Pivot files and 17 Candle files. Historical matching binaries
remain under `s1/`; previous accepted shared builds remain under `s3/` and `s4/`.
Restore code and its matching binary together while the owned tester is idle.
Rollback never rewrites a sealed run. Preserve operator/recovered data and
handoffs; D08 permits receipt-backed deletion of owned comparison/test exports.

The runtime optimization retains these dataset/engine identities. Its S4
source closure and release binaries are pinned in
`.codex-artifacts/model-runtime-optimization/s4/build-final.json` at implementation
commit `48f1f5f`. Candle includes the S3 indexed writer; Pivot also avoids repeated
trial-state copies and non-touch outcome construction. The original B03 receipt
above remains historical. The [current index](../README.md) records which
focused and full-history gates have actually passed; later backend planning must
use that status with the matching runtime receipts. The latest release adds the
D11 shared readiness fix: request indicator data before checking calculated-bar
readiness, so an initially unavailable Macro percent B can recover in nonvisual
testing. Latest pins: runtime `s5/build-readiness.json` and
`s5/readiness-compile.json`; the execution journal records the S5 commit.

The user deferred full-history reruns/validation to manual follow-up (D10) and
authorized the readiness repair using fast native tests (D11). The fresh full
run IDs below identify the corrected release. A reserved ID is not an accepted
dataset; earlier exports are never edited or backfilled.
MT5's [No Delay mode](https://www.metatrader5.com/en/terminal/help/algotrading/testing)
uses ideal execution at requested prices without requotes; historical spread
still applies. This does not simulate realistic latency/liquidity slippage.
No zero-versus-positive-delay comparison is required. A later Codex thread owns
the backend upgrade; this work only supplies the MQL5 contract and datasets.
Comparison/test exports may be removed after dependent checks under D08; retain
their evidence receipts and preserve both selected datasets as they are produced.

## Manual Full-History Handoff

The runtime plan closes on short/medium and first-year optimization validation,
plus 24 fast native cases/40 checks for the final readiness repair. Both latest
EAs compile with zero errors/warnings; all 76 shared tests pass. Full-history
acceptance is explicitly deferred. No Django code or training was performed.
Ten additional exact raw-byte/prefix comparisons pass.

| Engine | Selected full run ID | State when automation was handed over |
| --- | --- | --- |
| Candle | `RUNTIME_S5_CANDLE_READY_FULL_ZERO` | Configured, not started; generation and strict intake remain manual |
| Pivot | `RUNTIME_S5_PIVOT_READY_FULL_ZERO` | Configured, not started; generation and strict intake remain manual |

These are handoff-time states, not a live status API. The earlier Candle job
`7689260149195731650` completed naturally before the readiness repair; preserve
`RUNTIME_S5_CANDLE_FINAL_FULL_ZERO` as historical evidence, not a corrected
training dataset. Its full strict intake was not run. No full job, automatic
watcher, resource guard or queued launch remains active.

Linux dataset root:
`/home/admin/.wine/drive_c/users/admin/AppData/Roaming/MetaQuotes/Terminal/Common/Files/MQL5ModelDatasetV1/runs/`.
The Windows equivalent is
`C:\users\admin\AppData\Roaming\MetaQuotes\Terminal\Common\Files\MQL5ModelDatasetV1\runs\`.
Both corrected, strictly accepted one-week datasets are available now:
`RUNTIME_S5_CANDLE_READY_WARM_READY` and `RUNTIME_S5_PIVOT_READY_WARM_READY`
(2015-08-17 to 2015-08-24 exclusive). Their per-file hashes/counts are in runtime
`s5/candle-ready-warm-ready-validation.json` and
`s5/pivot-ready-warm-ready-validation.json`. Retained first-year datasets remain
valid evidence for the earlier optimization, with their pre-repair feature gaps.

Full-run configurations and exact input files are
`runtime-s5-candle-ready-full-zero.ini` / `.set` and
`runtime-s5-pivot-ready-full-zero.ini` / `.set`, under the terminal's
`MQL5/Profiles/Tester/` and copied into runtime `s5/`. Use
`Candle_Pattern_Discovery.ex5` and `Pivot_Macro.ex5`, respectively. Settings:
`XAUUSD_Exness_2015`, real ticks, H1/M3, Exness clock policy, zero execution delay,
reference lot input `0.001`, simulated USD 10,000,000, leverage 500, export on,
Visual/debug off. Requested interval: 2015-08-10 to 2026-09-08 exclusive.
Prepared history ends 2026-09-07 23:59:58.893 UTC; the tester uses August 10 as
startup history. This does not cover the operator's earlier September 23 end.
Source gaps, settings hashes and binary pins are in `s5/feed-pin.json`,
`s5/manual-full-cases.json` and `s5/build-readiness.json`.

1. Verify the current binary/settings hashes and an idle owned tester, then run
   Candle with its saved configuration/inputs. Save native JSON and XML/XLSX
   reports before another run; a tool timeout does not stop native execution.
   Do not restart an existing run ID. A stopped/failed candidate needs a fresh ID.
2. With the owned tester idle, run Pivot using its saved configuration and inputs.
   Follow the [resource guards](../environment/mt5-agentic-workflows.md#model-runtime-benchmarks).
3. Require the complete ten/eleven-file set and an OK/NATURAL seal, then run strict
   intake for each final directory. Store reports outside the source:

```bash
MODEL_DATASET_ROOT='/home/admin/.wine/drive_c/users/admin/AppData/Roaming/MetaQuotes/Terminal/Common/Files/MQL5ModelDatasetV1/runs'
.venv/bin/python -m tools.model_dataset.reader "$MODEL_DATASET_ROOT/RUNTIME_S5_CANDLE_READY_FULL_ZERO" --report .codex-artifacts/model-runtime-optimization/s5/candle-ready-full-zero-validation.json
.venv/bin/python -m tools.model_dataset.reader "$MODEL_DATASET_ROOT/RUNTIME_S5_PIVOT_READY_FULL_ZERO" --report .codex-artifacts/model-runtime-optimization/s5/pivot-ready-full-zero-validation.json
```

4. Reconcile actual coverage/ticks, inspect feature readiness and verify the
   receipt hashes after copying. Update `s5/manual-handoff.json` and the current
   index before describing either full dataset as accepted. Never backfill nulls
   from future observations or mix the baseline and final runs.

The repaired startup case recovers Macro percent B in 1,014/1,116 Candle and
141/156 Pivot snapshots; earlier snapshots correctly remain unavailable until
warmup completes. The corrected warm-start week has Macro percent B in all
1,532 Candle and 248 Pivot snapshots. Other explicit gaps remain unchanged
(94 and 20 snapshots); a strict PASS does not promise complete features everywhere.
All broker orders/deals and realized results remain equal. In the partial Pivot
case, 93 completed broker outcomes regain research eligibility under the existing
policy once their entry snapshots are complete; their TP/SL results do not change.
Evidence: `s5/readiness-validation.json` and `s5/readiness-feature-availability.json`.

Old year/full datasets keep their original missing values. The diagnostic
`s5/handoff-feature-readiness.json` records that pre-repair issue; it does not
describe the corrected release. Do not mix old and corrected exports solely
because both use schema 1: retain the source/binary pin and per-family readiness.

D08 cleanup removes 138 identified S1-S4 comparison/test exports (2,358,030,442
bytes), retaining their reports, settings, diagnostic evidence and file hashes.
The exact paths and verified disposition are in `s5/dataset-cleanup-inventory.json`
and `s5/dataset-cleanup-receipt.json`. S5 year/full references remain for manual
follow-up; operator/recovered data, raw history and private handoff bundles stay
untouched. One unclassified warmup folder is conservatively retained.
After D11 validation, another 20 temporary exports (144,361,955 bytes) are removed
with `s5/readiness-cleanup-{inventory,receipt}.json`; the two corrected one-week
datasets retain their accepted hashes. All native reports/audits and binary
backups remain available; temporary profile slots are restored.

## Intake And Grains

Select the entire identity tuple and exact engine file set before interpreting
rows. Numeric schema `1` alone is insufficient: historical Candle schema `1`
belongs to another family. Unknown versions, profiles and extensions fail intake.

| Table | Grain and consumer use |
| --- | --- |
| `run_manifest.tsv` | Immutable key/value identity, periods, feature/clock/engine policies and instrument specification |
| `macro_windows.tsv` | Native Macro candle and its previous completed source candle, raw/trade ladder and context audit |
| `signal_events.tsv` | Pivot consumed origin or Candle pattern root; never one event per reward ratio |
| `feature_snapshots.tsv` | Immutable observed quote/bar/profile capture, referenced by attempts |
| `entry_attempts.tsv` | Directional decision; Candle originals and re-entries retain explicit parentage |
| `trials.tsv` | Broker, virtual or parity policy/ratio; admission and submitted geometry |
| `execution_checks.tsv` | Observed request/check/reconciliation facts; never assumed fills |
| `outcomes.tsv` | One terminal record per trial, actual entry/exit and later observation kept distinct |
| `run_summary.tsv` | Successful or failed seal, exact counts, feature gaps, warmup bounds/fingerprint and resource peaks |
| `pivot_origins.tsv` | Pivot-only consumption identity, trigger/stop/midpoint geometry and origin terminal facts |
| `candle_signals.tsv`, `candle_attempts.tsv` | Candle-only pattern OHLC, direction category, generation, execution ATR and expiry/re-entry facts |

Pivot requires ten TSVs; Candle requires eleven. Validate all files with
`tools.model_dataset.reader.ModelRun`, retain its SHA-256 receipt and verify it
when transferring the source. The reader uses Decimal tokens and a bounded
temporary SQLite index; it does not mutate the dataset. Require OK/NATURAL and
no failure marker, extra/missing file, changed hash, invalid scalar or orphan
reference. A naturally completed run may contain explicitly censored trials.

Use the reader's compatibility signature before combining configurations. Keep
engine policies and BROKER/VIRTUAL/PARITY roles explicit. Parity is calibration
evidence and is always excluded from target cohorts. Count a decision once,
regardless of how many virtual ratios reference it. Retain Candle direction and
parent membership during temporal splitting; a completed outcome was not known
at entry.

## Feature Meaning

Macro and Micro each export six shifts, 0 through 5:

- Native Stochastic K and D: 5/3/3, SMA, Close/Close. D is the native SMA(3)
  signal; there is no additional Stochastic SMA(5).
- Ordinary percent B and SMA(5): Bands 21/0/2.0, weighted price. Each shift uses
  its own `(high + low + 2 * close) / 4`. There is no bandwidth or frozen
  pivot/Bid substitution. Values are not clipped to 0..100.
- Native ATR(13) x 1.0 and SMA(5). This measurement does not authorize broker
  stops; Candle retains its separate shift-1 execution ATR.

Shift 0 freezes the forming candle at observation. An average at shift `s` uses
`s..s+4`; ten native source values support six averaged outputs. Missing families
remain null with explicit completeness/reason fields. An earlier snapshot cannot
be backfilled using later indicator availability.

Two simple Macro support/resistance features use the signal's captured Bid:

- `signal_zone`: the interval between adjacent Macro pivots, an exact AT level,
  or outside S3/R3. No thickness parameter or Deep role exists.
- `signal_vs_tested_pivot`: ABOVE/AT/BELOW_SUPPORT or RESISTANCE, or UNTESTED.
  Select the latest touch and the outermost simultaneous tie. Preserve PP
  departure/return, recorded role, gap/reclaim facts and the Macro reset.

For example, with PP=100, R1=106 and R2=112, Bid=107 lies in `R1_TO_R2`.
If the latest tested level is R1 as resistance, the relation is
`ABOVE_RESISTANCE`. This describes where the signal is; it does not predict that
the breakout will hold. An unavailable ladder is distinct from UNTESTED.

Fixed M1 Stochastic Structure exports the last confirmed high/low/event and a
separate live forming candidate, including candidates not yet drawn on the chart.
Only closed M1 bars mutate committed state. Each shift-0 projection starts from
a copy, so a temporary 80/20 crossing can disappear without creating a confirmed
swing. Preserve HIGH/LOW initial classes, HH/LH/HL/LL/EQ and the high/low kind.

Warmup uses at most 4,096 prior closed M1 bars; record actual bounds/count/hash and
COMPLETE/TRUNCATED/PARTIAL/UNAVAILABLE. Runtime catch-up is at most 256 closed bars
per callback. Incomplete catch-up exposes no live candidate. This bounded context
is not equivalent to an indicator replayed over unlimited chart history.

## Scalars, Clocks And Instruments

The wire format is UTF-8 TSV with exact headers and `\N` nulls. Preserve the
original finite decimal token; producer doubles use 17 significant digits.
Neither zero nor an empty string denotes missing data. Native integer tickets
remain separate from opaque text IDs, including Pivot's `broker_<hash>` identity.
Do not infer fixed decimal places from display digits or discard actual deal
milliseconds. SECOND precision means the source supplied only whole seconds.

Raw broker clocks and the observed sequence govern causality, native candles,
entry/exit scheduling and durations. Analysis time is a derived research wall
clock and cannot sort events across a backward fold. In fixed mode the offset
is zero. Explicit Exness mode uses `EXNESS_NEW_YORK_V1` for every verified
UTC/Shift=0 symbol: US DST, winter -60 minutes, summer zero, years 2007..2099.

Synthetic reference values, not native market observations:

| Example | Result |
| --- | --- |
| H=10, L=0, C=2, lower=0, upper=10 | Weighted price 3.5; percent B=35 |
| Five percent-B values 35, 40, 45, 50, 55 | SMA(5)=45 |
| Raw `1452772800123` (2016-01-14 12:00:00.123 UTC), Exness mode | Analysis `1452769200123`, offset -60, MILLISECOND |
| Raw `1458129600123` (2016-03-16 12:00:00.123 UTC), Exness mode | Same analysis integer, offset 0, MILLISECOND |
| Raw clock unavailable | Raw/analysis/offset/precision all `\N` |

Retain raw broker/feed/symbol and specification metadata. Producers declare
canonical mappings UNMAPPED. A symbol suffix is not evidence of parity: a later
consumer needs an external verified source/specification mapping before joining
symbols or brokers. Existing Exness preparation/import evidence remains valid
under its original scope; the V14 `research-provenance` command is not a new-family
importer. These bounded tests do not establish broker-feed equivalence.

Use only `CAUSAL_FEATURE` fields for the base feature registry. Request/fill
facts are `EXECUTION_FACT`; results, complete durations and labels are
`OUTCOME_ONLY`; identity/source metadata is `PROVENANCE`. Broker costs are actual
facts. Virtual costs/net remain unknown. Completed `duration_ms` is exit minus
entry, including legitimate zero; censored/unentered duration and labels are null.

## Legacy Mapping

The [complete field map](../architecture/model-feature-dataset.md#engine-policies-and-legacy-mapping)
classifies every legacy field. The important grain/version changes are:

| Legacy meaning | New meaning |
| --- | --- |
| Pivot V14 / `PIVOT_FRACTAL_V2` / twelve files | New family/core 1 / `PIVOT_MACRO_V1` / ten files |
| Candle schemas 1/2/3 / `CANDLE_PATTERN_ATR_V1` / eight files | New family/core 1 / `CANDLE_PATTERN_ATR_V2` / eleven files |
| Pivot origin / Candle root | `signal_events.signal_id` plus typed engine extension |
| Inline features and ratio rows | Frozen `feature_snapshots`, joined through an attempt; ratios do not create extra decisions |
| Pivot Deep events, parent links, trials and age selectors | Removed from the active producer; historical reader/data retained |
| Frozen pivot/Bid percent B, bandwidth, baseline/slopes, extra Stochastic SMA5 | Retired defaults; no relabeling as the new weighted-price feature |
| Pivot WINDOW_EXPIRED | EXPIRED with unchanged lifecycle boundary |
| Second-only or synthetic minimum-plus-one terminal clock | Explicit actual milliseconds where available; SECOND precision otherwise |
| Legacy monetary R | Reconstruct from retained gross profit and expected monetary stop loss; common `gross_r` is price-distance R |

Do not convert old exports in place, invent earlier forming structure or
milliseconds, dual-write old/new formats, or feed the new rows into old importers.
Preserve historical readers, fixtures, recovered data and correction sidecars.
The completed Candle execution record is [archived](../plans/archive/candle-pattern-discovery-plan.md)
with its original commit/path recovery; its old consumer acceptance does not
certify the new family.

## Reproducible Bundle

The private release bundle is `.codex-artifacts/model-feature-framework/s6/`:

| Artifact | Purpose |
| --- | --- |
| `consumer-contract.json` | Generated ordered fields, types/nullability, classifications, clock companions and engine profiles |
| `producer-pin.json`, `native-runs.json` | Accepted source/EX5 pins and exact native run/settings/hash receipts |
| `examples/` and `examples-validation.json` | Two valid synthetic exports and six intentional header/seal/parity failures, covering both engines |
| `reference-values.json`, `legacy-field-map.json` | Machine-readable clock/indicator examples and the canonical old/new mapping |
| `validation.json`, `SHA256SUMS` | Final verification and bundle checksums |

Native exports remain in the Common Files root. Representative final runs are
`MODEL_PIVOT_S4_H1_B03_20260924`, `MODEL_CANDLE_S4_H1_B03_20260924`,
`MODEL_PIVOT_S5_MARCH_FX_B03_20260924` and
`MODEL_CANDLE_S5_PARTIAL_INITIAL_B03_20260924`. Full evidence covers 21 strict
exports, 5,863 snapshots, export-on/off and old/new broker comparisons, two
one-week prefixes, six file/header/seal faults and two refused reused identities.
The [validation runbook](../environment/mt5-agentic-workflows.md#shared-model-dataset-acceptance)
defines reproducible commands, report handling and resource limitations.

Availability note, 2026-09-25: the original B03 source folders were unavailable
at runtime-sprint lookup, while their reports/settings remained. S3 recreated
equivalent native baselines from the immutable current-schema binaries;
`.codex-artifacts/model-runtime-optimization/s3/matrix-baseline-map.json`
locates those fresh receipts. Verify actual source availability before intake;
an archived run name alone does not establish that its files still exist.

Sprint 6 verifies all 21 accepted run file sets and hashes, plus their settings
and retained indicator/structure source audits. Its four representative exports
pass a fresh strict-reader check. Other acceptance is reused only for unchanged
inputs. The bundle includes those results and the exact prior evidence receipts.
Verify `SHA256SUMS` from the bundle directory with `sha256sum --check SHA256SUMS`;
the manifest covers bundle files, while `native-runs.json` pins the external
native datasets/settings and `producer-pin.json` pins the source/EX5 files.

Generate the contract and validate a copied candidate without modifying it:

```bash
.venv/bin/python -m tools.model_dataset.schema_contract --check-mql-header services/model_features/schema.mqh
.venv/bin/python -m tools.model_dataset.schema_contract --write-json .codex-artifacts/model-feature-framework/s6/consumer-contract.json
.venv/bin/python -m tools.model_dataset.reader "$MODEL_RUN_PATH" --report "$MODEL_REPORT_PATH"
rtk test .venv/bin/python -m unittest discover -s tools/model_dataset/tests -t . -p 'test_*.py'
```

Report destinations must be outside the sealed source. Keep account-related
metadata, native datasets, logs, binaries and private evidence untracked. A later
backend planner should read this handoff and the then-current backend source,
verify the bundle hashes, design explicit new-family intake/research semantics,
and define its own acceptance and rollout plan. No backend compatibility is
assumed from a producer-side validation pass.

## Adding An Engine

1. Declare a new engine identity, extension version, exact table grains and
   outcome policy in `tools/model_dataset/schema_contract.py`. Preserve existing
   profiles; breaking common feature/wire changes require an explicit new version.
2. Implement engine semantic checks and meaningful synthetic fixtures in the
   existing unittest package. Reuse `COMMON_TABLES` and the causal registry;
   register only typed extension fields and explicit relationships.
3. Regenerate the MQL header and JSON contract. Add the new profile's file routing
   and policy metadata explicitly; registration is compile-time, not dynamic.
4. Add an engine adapter that supplies `ModelCaptureConfig`, read-only quotes and
   engine facts. Reuse shared clock, number, indicator, pivot-context, structure
   and writer services. Observe before decisions, freeze each capture once, and
   keep order ownership/lifecycle controllers in the engine.
5. Compile the actual entrypoint, validate native exports against independent
   feature inputs, compare export-on/off broker behavior and exercise failure
   isolation. Pin source/binary/data/settings and document engine-specific targets.
6. Declare callback/bar/capture work, handle/state/buffer caps, cleanup, retries
   and cache invalidation under the [performance contract](../architecture/market-data-broker-executor.md#performance-contract).
   Reuse generated field IDs and shared providers; retain execution ownership.
   Prove exact row/clock/outcome ordering, then measure repeated release builds,
   early/late occupancy and day/week/month/long-history growth. Shared changes
   require both existing engines' regression checks. Keep native history memory
   separate from bounded application state and retain stopped/failed evidence.

No runtime ML policy or broker decision is implied by adding a feature. Human
chart review, full-history scale, recovered-run semantic acceptance and formal
feed/broker equivalence remain the [open operational gates](../README.md#remaining-operational-gates).
Live deployment is outside this handoff.

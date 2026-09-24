# Plan: MQL5 Engine Feature Framework

- **Generated:** 2026-09-24
- **Status:** Completed - six sprints; operational gates remain open in the project index.
- **Execution authorization:** User requested execution of all six sprints on 2026-09-24, including the planned validation and commit gates.
- **Proposal:** Not requested; this plan implements the decisions from the discussion.
- **Complexity:** High
- **Planning baseline:** `5df19f1849d6208ddae64fa29951f0f81477aa6e` on
`bot/pivot_points_fractal`.

Post-completion naming update, 2026-09-24: the Pivot entrypoint is now
`Pivot_Macro.mq5` / `Pivot_Macro.ex5`. The completed execution record below retains
its original filenames and build pins. Use the current
[environment runbook](docs/environment/mt5-agentic-workflows.md) for new builds;
the engine ID and dataset contract remain unchanged.

Post-completion planning follow-up, 2026-09-24: the
[model runtime optimization plan](mql5-model-runtime-optimization-plan.md)
investigates the reported long-history slowdown in both engines. It is a new
planning scope; this framework execution remains complete and is not restarted.

## 1. Outcome And Scope

Turn this MQL5 repository into reusable engine-based feature capture. Separate
Pivot and Candle EAs use shared indicator, clock, pivot-context, serialization
and dataset services. Each engine retains its own signal discovery, broker
execution, virtual policies and typed extension facts. A new engine should need
an engine adapter, declared extensions and contract fixtures, not copied base
features or another clock/serialization implementation.

The new Pivot producer has Macro/Micro capture and no Deep discovery. Both
producers write a new common dataset contract. Preserve old source exports and
their local readers under their existing identities.

- **In scope:** MQL5 producers and includes, a shared dataset contract, local
  Python validation, meaningful fixtures using the existing unittest workflow,
  native MT5 acceptance, documentation and a producer handoff.
- **Out of scope:** Any Django repository, database, migration, application
  importer, API, UI, discovery implementation or backend validation. A later
  plan in that repository consumes the completed handoff and its then-current
  source. Do not inspect or modify it during this plan.
- **Also out of scope:** New strategy families, runtime ML decisions, model
  training experiments, new frameworks/dependencies, MQL5 test EAs/scripts,
  new test infrastructure/CI, source-feed changes, live trading or deployment.
- **Preserved trading scope:** Existing Pivot Macro behavior and Candle
  pattern/ATR/re-entry/expiry behavior. Removing Deep is removal of a research
  path, not a replacement broker strategy.
- **Execution boundary:** Implement the six ordered sprints and their commit gates.
  Preserve the recorded decisions and MQL5-only scope. Execution receipts and
  continuity belong in ignored `.codex-artifacts/model-feature-framework/` and
  `.codex-hook-state/`.

## 2. Decision Record

| ID | Decision | Authority and consequence |
| --- | --- | --- |
| D01 | Shared base features with typed engine extensions | Original user request; common services must work for both existing engines. |
| D02 | Stochastic main %K and its native period-3 SMA %D, 5/3/3, Close/Close | Explicit answer A; the old additional SMA(5) of both Stochastic lines is not a default feature. |
| D03 | Ordinary weighted-price %B and SMA(5) | Explicit clarification and confirmation; each shift uses its own candle price, not one frozen Bid or pivot across historical Bands. |
| D04 | ATR(13) x 1.0 and SMA(5) | Original requested default; indicator measurement is independent of engine stop authorization. |
| D05 | Fixed M1 Stochastic Structure, 5/3/3, Close/Close | Original request; preserve this source independently of Macro/Micro settings. |
| D06 | Capture both confirmed structure and the current forming shift-0 structure | Latest explicit clarification: the forming value is required even before the zigzag draws it. |
| D07 | Bounded recorded pre-run structure warmup | Explicit answer A; unavailable history remains explicit and never blocks a broker request. |
| D08 | Existing adjacent Macro pivot intervals | Explicit answer A; no new thickness or overlap parameter. User also requires the signal's relation to reached support/resistance. |
| D09 | Macro/Micro default capture; remove Pivot Deep research | User's requested simplification, carried into the requested plan. Fixed M1 structure remains an explicit feature source. |
| D10 | MQL5 repository only; Django deferred | Explicit scope clarification and acceptance. |
| D11 | Standard raw numbers, clocks, symbol metadata and broker/virtual/parity identities | Original normalization request; raw facts and derived session time remain distinct. |
| D12 | Numbered main replies and bullet details | Already delivered in `5df19f1`; do not redo that commit. |

Implementation defaults derived from the existing contracts:

- Preserve Macro H1 / Micro M3 and validate explicit supported periods with
  `Micro < Macro`. Preserve each engine's supported-period whitelist, including
  its existing monthly-period restriction; do not equate MT5 enum ordering with
  elapsed seconds.
- Preserve six exported indicator shifts, 0 through 5. Export the requested
  main/average series; slopes, comparisons and other derived model transforms
  are not additional producer defaults. No bandwidth or Bands-baseline feature.
- Use the signal's captured Bid for shared pivot-zone classification in both
  directions. Preserve executable Ask/Buy and Bid/Sell entry prices separately.
- Preserve Candle's latest-tested-level selection, outermost simultaneous tie
  rule, PP departure/return rule and per-Macro reset for shared tested context.
- Keep separate EA entrypoints, public lot/export/debug controls and fixed
  1,000,000 reference-balance lot math. Do not restore removed controls.
- Keep `Broker_Session=FIXED_TIME_SESSIONS` as the existing default; explicit
  Exness mode uses the shared versioned New York policy for verified UTC/Shift=0
  sources across symbols.
- Use 4,096 closed M1 bars as the versioned maximum initial structure warmup,
  with the actual count, bounds and completeness recorded. This is a fixed
  feature-policy constant, not another public input. Runtime catch-up is bounded
  to 256 closed M1 bars per callback; an unfinished catch-up marks that feature
  unavailable without delaying or changing engine decisions.
- Preserve the current standalone indicator as a reference, including its
  packaging and chart behavior. The new data-only provider reuses its algorithm
  semantics and attribution without requiring chart objects or an iCustom EX5.

**Pending required decisions:** None. The latest user answer replaces the earlier
confirmed-only structure recommendation. Above/at/below categories, warmup limits
and file names below are concrete implementation choices for the requested scope,
not claims that the user selected those identifier spellings.

## 3. Architecture And Ownership

### 3.1 Shared services and engine adapters

Use ordinary MQL5 structs, enums and functions with compile-time engine
descriptors. No dynamic plugin loader, reflection, service locator or runtime
strategy selector is needed.

Pass an explicit capture configuration, read-only observed tick and descriptor
into shared services. Their include closure must not import either engine's
inputs, broker state or lifecycle controller. Reuse pure pivot calculations and
core enums; complete any necessary primitive ownership cleanup when both engines
have migrated, with both include trees revalidated.

| Owner | Responsibility |
| --- | --- |
| Shared feature service | Native indicator handles, immutable as-of snapshots, Macro pivot context, M1 confirmed/forming structure and completeness reasons. |
| Shared dataset service | Numeric tokens, clocks, identities, headers, append/seal integrity and bounded research buffers. |
| Pivot adapter | Macro origin/consumption facts, structural/midpoint trials, structural broker 1R, parity and engine extensions. |
| Candle adapter | Pattern facts, separate direction attempts, actual broker entries, ATR protection, expiry, re-entry and engine extensions. |
| Local Python package | Strict new-contract reader, feature registry, engine semantics, provenance checks and consumer-readable contract export. |
| Legacy Python packages | Existing Pivot V14 and Candle schemas 1/2/3 only; historical source interpretation remains unchanged. |

Broker and virtual lifecycle state stays with its current engine. Shared capture
receives facts; it never authorizes, denies, delays, sizes, duplicates, closes or
modifies a real request. Bounded research admission/failure must not become an
engine entry condition. Keep Candle's execution ATR handle independent of optional
research handle ownership and cleanup.

### 3.2 New identities and physical contract

Use these new identities, frozen in Sprint 1:

- Dataset family `MQL5_MODEL_FEATURES`, core schema `1`.
- Base feature set `macro_micro_standard_v1`.
- Engine IDs `PIVOT_MACRO_V1` and `CANDLE_PATTERN_ATR_V2`, each with an explicit
  extension-schema version and outcome-policy identity.
- New EA property versions `2.00` at each engine's adoption sprint.
- New root `Common/Files/MQL5ModelDatasetV1/runs/<run_id>/`.
- Separate ownership namespaces for the new engines. Preserve the existing
  stable symbol-scoped magic derivation pattern for Pivot; define a distinct
  deterministic Candle namespace as well. Never adopt old-engine exposure.

The manifest pins core/engine/base-feature/extension versions, clock and label
policies, effective periods in seconds, warmup policy, producer version/build,
configuration identity, source precision and instrument metadata. A descriptor
enumerates exact required files, ordered columns, types and allowed values.
Unknown versions, tables, columns and extension combinations are rejected.

Bind the exact source/include digest, eventual sprint commit and EX5 hash through
an immutable external build/run receipt and the exported run identity/checksums.
Do not stamp an uncommitted build with the previous HEAD as though that commit
contained it, or rewrite a sealed run after its source commit is created.

| Common file | Grain and purpose |
| --- | --- |
| `run_manifest.tsv` | Frozen run identity, configuration, instrument facts and policy versions. |
| `macro_windows.tsv` | One native Macro window, previous completed source OHLC and raw/trade-normalized pivot ladder. |
| `signal_events.tsv` | One engine signal/origin with stable identity, discovery sequence, raw quote and signal/source clocks. |
| `feature_snapshots.tsv` | One immutable declared capture instant/stage; Macro/Micro indicator vectors, Macro context and M1 structure. |
| `entry_attempts.tsv` | One engine entry decision, signal/snapshot references, direction, entry kind and optional parent attempt. |
| `trials.tsv` | One scenario with geometry, ratio, eligibility and explicit BROKER/VIRTUAL/PARITY role. |
| `execution_checks.tsv` | Actual engine checks, fresh quotes, submitted geometry, request/deal references and retcodes. |
| `outcomes.tsv` | One terminal trial outcome with actual/reference entry, close/observation evidence, costs, duration and label eligibility. |
| `run_summary.tsv` | Seal, integrity/completion status, exact counts, feature-gap counts and bounded-resource peaks. |

Typed extension files are `pivot_origins.tsv` for Pivot and
`candle_signals.tsv` / `candle_attempts.tsv` for Candle. The former retains
direction-independent pivot consumption, source level and origin geometry.
Candle extensions retain source candle/pattern facts, pattern direction,
ALIGNED/OPPOSED category, generation, re-entry cause and expiry policy facts.
The descriptor requires only the active engine's extension files. Empty valid
tables still have exact headers and counts.

Sprint 1 maps every retained old broker, geometry, eligibility and lifecycle
fact to these tables or the appropriate extension before freezing ordered
headers. Do not flatten ratios/children into repeated training observations.
Snapshots may be shared by attempts only when quote, observed sequence, capture
stage and all feature-source identities match.

Keep capture stages explicit: Pivot origin features belong to its trigger;
Candle attempt features belong to the original/re-entry decision. Preserve
existing delayed-midpoint capture semantics: its entry time is not permission
to rewrite the origin snapshot or invent an entry-time feature vector. A future
engine can declare a separate entry snapshot under a new feature profile.

### 3.3 Indicator feature contract

For each Macro/Micro role export shifts 0..5 of:

| Series | Exact meaning |
| --- | --- |
| `stochastic_k` | Native main buffer of 5/3/3, MODE_SMA, STO_CLOSECLOSE. |
| `stochastic_d` | Native period-3 SMA signal buffer from the same handle. |
| `percent_b` | `100 * (weighted_price[s] - lower[s]) / (upper[s] - lower[s])`. |
| `percent_b_sma_5` | Arithmetic mean of that series at shifts `s..s+4`. |
| `atr_13` | Native iATR(13), multiplier 1.0. |
| `atr_13_sma_5` | Arithmetic mean of native ATR at shifts `s..s+4`. |

`weighted_price[s] = (high[s] + low[s] + 2 * close[s]) / 4`.
Bands retain 21 / shift 0 / deviation 2.0 / SMA / PRICE_WEIGHTED.
Historical shifts use their own candle prices and envelopes. Shift 0 uses the
current candle as observed at the trigger, never its later final OHLC.
Percent-B is expressed on the existing 0..100 percentage scale and is unclipped;
values outside that range are valid.

Ten raw shifts suffice for six SMA(5) outputs. Record role/source-bar clocks and
availability, and guard the bar/tick identity around buffer/rate reads. A rollover
or inconsistent quote during capture yields an explicit incomplete feature
snapshot; do not silently recapture later under the earlier signal clock.
Native ATR can validly be zero in feature data; Candle still independently
requires usable positive ATR for its existing execution geometry.

Do not export the old frozen-pivot/frozen-Bid percent-B series under these names,
additional Stochastic SMA(5) series, bandwidth or Bands baseline/slope fields.
Keep raw trigger and pivot prices as facts. Engine-specific extra features need
their own names, definitions and versioned extension; do not add unrequested
legacy feature aliases to the new default set.

Cache by symbol/timeframe/indicator parameters. At most seven distinct research
handles are needed: two roles times Bands/Stochastic/ATR plus M1 Stochastic,
deduplicated when Micro is M1. Initialize/release safely after partial failure;
no per-tick creation. Export-off creates no research handles or context state.
Candle's existing execution ATR remains available when export is off or failed.

### 3.4 Macro pivot zones and tested support/resistance

Use the previous completed native Macro candle; source levels stay fixed during
the active Macro window. Default Macro is H1. Record two simple categorical
features using the captured signal Bid:

1. `signal_zone`: BELOW_S3, AT_S3, S3_TO_S2, AT_S2, S2_TO_S1, AT_S1,
   S1_TO_PP, AT_PP, PP_TO_R1, AT_R1, R1_TO_R2, AT_R2, R2_TO_R3, AT_R3,
   ABOVE_R3.
2. `signal_vs_tested_pivot`: ABOVE_SUPPORT, AT_SUPPORT, BELOW_SUPPORT,
   ABOVE_RESISTANCE, AT_RESISTANCE, BELOW_RESISTANCE, or UNTESTED.

Retain audit facts: selected tested level ID/price/role, interval bounds where
finite, last touch time/sequence, signed distance in price and points, age in
milliseconds, reclaim and gap-cross flags. Outside-ladder intervals have an
explicit open bound, not a fabricated extension price. Missing ladder data is
unavailable; UNTESTED means a valid ladder exists but no level was tested.

Shared context follows Candle's first-observed-beyond-level and gap rules.
PP requires strict departure followed by return. Choose the most recently
tested level, with the existing outermost same-sequence tie rule. Preserve its
role at the test; crossing it does not automatically relabel support as
resistance. Compare the raw Bid with trade-normalized levels without rounding
away a strict departure or adding an arbitrary zone width.

Example: S1 was tested as support, then Bid is between S1 and PP:
`signal_zone=S1_TO_PP`, `tested_level=S1`,
`signal_vs_tested_pivot=ABOVE_SUPPORT`.
Engine-specific Pivot origin level and executable entry interval remain separate
facts; they must not overwrite the shared latest-tested context.

### 3.5 Confirmed and forming M1 structure

Use the transition/classification semantics in
`indicators/Stochastic_Structure.mq5`: strict 80/20 transitions, Close/Close
candidate prices, the confirming candle starting the next leg, and trade-tick
equality for equal highs/lows. Preserve HIGH/LOW initial states and HH/LH/HL/LL/EQ;
EQ carries the high/low kind so equal highs and lows remain distinguishable.

Keep two separate views:

- **Confirmed:** committed closed-M1 state, last confirmed high and low classes,
  prices, pivot times and confirmation times, plus the most recent confirmed
  event kind/class.
- **Forming:** the active candidate kind/class/price/time after applying current
  M1 Close and Stochastic K(0) to a temporary copy of that committed state.
  Record observation time, current M1 bar time and explicit FORMING status.

A shift-0 reversal may project a new leg, but it cannot commit a pivot or advance
confirmed history. Rebuild each projection from closed state, not from the prior
tick's projection; this prevents a transient intrabar cross from persisting.
The projection's same-kind comparison uses information already available at
capture. A forming feature is a causal observation, not a future confirmed label.
Saved snapshots never change when the projection moves or later confirms.

Warm up from at most 4,096 available closed M1 bars preceding the first observed
run tick. Pin actual first/last source bars, count, policy version and a source
fingerprint in run evidence. Skip undefined native indicator warmup values;
never fabricate an initial swing. Initial/comparator-missing and truncated-history
states are explicit. Do not claim equivalence to an unlimited-history chart:
conformance compares the same source prefix and records initialization limits.

Process new closed M1 bars once in order, using real bar boundaries across
weekends/gaps. Batch reads and bounded catch-up replace per-tick history scans.
History changes, missing bars, unready buffers or pending catch-up mark the
affected structure view incomplete; no future replay fills an earlier snapshot.
No chart-object reads, chart-timeframe buffer compression or rendering belongs
in the producer feature provider.

### 3.6 Numbers, clocks and instrument provenance

- Serialize finite runtime doubles with 17 significant digits and parse their
  original tokens as Decimal in Python. This preserves runtime doubles; it does
  not manufacture greater precision than the source. Use decimal point, explicit
  units, `\N` for null and 0/1 for booleans. Reject NaN/Infinity/sentinel leaks.
- Keep raw prices, point, digits, trade tick size, volume bounds/step, contract
  size, calculation/chart mode and base/profit/margin/account currencies.
  Geometry normalization remains engine-owned. Do not apply one global decimal
  count or round source quotes for display before storing them.
- Distinguish signal/source-bar, decision, request, actual fill, actual close,
  deadline and reconciliation/observation clocks. New tick/deal facts use actual
  integer milliseconds when available; bar/legacy-second facts retain explicit
  SECOND precision even when represented as milliseconds.
- A per-run monotonic observed-event sequence breaks same-time ties. Actual deal
  time may precede its reconciliation observation; retain both. Do not sort
  late-reported actual facts as though they were known earlier.
- Completed duration is exact `close_raw_msc - entry_raw_msc`, nullable for
  unentered or censored rows, and excluded from causal model features. Zero is
  valid. Derived selectors use millisecond arithmetic without rounding.
- Preserve raw broker clocks for scheduling, windows, causality and durations.
  For every present raw clock export its analysis clock and offset, with matching
  null triplets. The normalized analysis clock is not a UTC instant.
- Reuse Candle's `EXNESS_NEW_YORK_V1` policy and explicit UTC_SHIFT_0 prerequisite:
  US DST for all symbols, including metals; summer offset 0, winter -60 minutes;
  2007..2099 coverage. Fixed mode remains raw/zero-offset. Verify independently
  with IANA America/New_York. Unsupported/unknown mappings are explicit.
- Export exact source symbol and broker/feed identity without account numbers,
  credentials or tokens. Bind a canonical instrument only through verified
  source/specification provenance; never infer equivalence by stripping suffixes.
  Unmapped instruments retain raw facts and an explicit mapping status.
  Cross-symbol aggregation requires verified mappings and compatible specs.
- Freeze the run's instrument specification. A material specification change
  invalidates research integrity and requires a fresh run; it does not control
  the broker lane. Keep retained source/Exness provenance sidecars outside the
  strict run directory and bind their checksums in the handoff.

Price/ATR normalization for model inputs, fitted scalers and model selection
belong to later research. They do not replace raw capture facts.

### 3.7 Lifecycle and compatibility invariants

Keep Pivot's direction-independent first consumption, Bid trigger/PP arming,
fresh structural 1R FOK request, immutable protection, eight Macro virtual lanes
(STRUCTURAL/MIDPOINT_50 x 1R/2R/3R/5R), midpoint rollover and final-structural-exit
NOT_TRIGGERED behavior. Every accepted request retains exact submitted-geometry
parity regardless of stricter research distance eligibility.

Keep Candle's completed-Micro Harami/Engulfing discovery, separate ALIGNED/OPPOSED
attempts, ATR(13) x 1.0 shift-1 protection, both broker directions, one re-entry
after confirmed original broker SL, each entry's full Macro-duration deadline,
actual expiry closure evidence, virtual R2/R3 and exact R1 parity.

Keep broker versus virtual costs distinct: unavailable virtual costs/net remain
unknown. Rejected, ineligible, not-triggered, capacity-rejected, time-exit and
censored outcomes retain explicit engine policy and binary eligibility.
No incomplete feature turns a trade into a loss. Parity stays out of target
cohorts. Parent/root links survive where Candle re-entry needs them.

Remove Deep input, contexts, handles, events, links, trials, outcomes, parent-age
selector facts and active-state bookkeeping from the new Pivot producer. Do not
remove generic M10 support as a valid Macro/Micro period, Candle parent links,
Macro midpoint behavior or a broker check merely because it once appeared near
Deep code.

New datasets are incompatible with old importers by design. Keep legacy readers,
fixtures, source runs and recovery/provenance sidecars intact. No automatic
conversion, dual export, relabeling of old features or claim of recovered
subsecond/forming-structure data. Old EAs remain recoverable through Git and
retained matching binaries, not active runtime compatibility aliases.

## 4. Named Resources

### 4.1 Existing sources and contracts

- `AGENTS.md`, `README.md`, `docs/README.md`,
  `docs/architecture/market-data-broker-executor.md`,
  `docs/environment/mt5-agentic-workflows.md`.
- `HFT_Grid_AI.mq5`, `Candle_Pattern_Discovery.mq5`,
  `services/trading_tools.mqh`, `services/trading_management.mqh`,
  `services/trading_signals.mqh`, `services/frontend.mqh`.
- `services/trading_management/ea_inputs.mqh`,
  `services/trading_management/indicator_definitions_loader.mqh`,
  `services/trading_management/pivot_fractal_engine_config.mqh`,
  `services/core/enums.mqh`, `services/utils/market_data_time.mqh`.
- `services/trading_signals/pivot_context_features.mqh`,
  `pivot_fractal_engine_state.mqh`, `pivot_fractal_signal_detection.mqh`,
  `pivot_fractal_statistics_export.mqh`, `pivot_signal_struct.mqh`,
  `pivot_signal_lifecycle.mqh`, the `pivot_trial_matrix_*.mqh` modules,
  `execution_broker_reconciliation.mqh`, `execution_broker_context.mqh`,
  `execution_controller.mqh` and `execution_lot_math.mqh` in that directory.
- `services/trading_signals/deep_pivot_lifecycle.mqh` and
  `services/trading_signals/deep_pivot_signal_struct.mqh`: removal candidates
  requiring exact include/callback/reference proof.
- `services/candle_pattern/{config,clock,context,features,schema,export,state,broker,engine}.mqh`.
- `indicators/Stochastic_Structure.mq5`: frozen algorithm/reference indicator;
  source-only packaging and chart work are not refactor targets.
- `tools/candle_pattern_ml/{schema_contract,clock,reader,semantics,research}.py`
  and existing tests: reusable patterns and legacy contract ownership.
- `tools/candle_pattern_ml/tests/test_clock.py` currently compares its generated
  legacy header to `services/candle_pattern/schema.mqh`. That is a real fixture
  dependency; S3 relocates the unchanged header and adjusts that test's path.
- `tools/deterministic_signal_ml/`, `tools/exness_tick_history/` and their
  existing tests/README files: legacy validation and source-provenance owners.

### 4.2 Files to create during implementation

- `services/model_features.mqh`: ordered shared-service aggregator.
- `services/model_features/types.mqh`, `clock.mqh`, `indicators.mqh`,
  `pivot_context.mqh`, `stochastic_structure.mqh`, `export.mqh`,
  `schema.mqh` in that directory. Serialization helpers belong in types/export;
  do not add a separate abstraction for every scalar operation.
- `services/candle_pattern/dataset_adapter.mqh` and
  `services/trading_signals/pivot_dataset_adapter.mqh`.
- `tools/model_dataset/__init__.py`, `schema_contract.py`,
  `feature_contract.py`, `clock.py`, `reader.py`, `semantics.py`,
  `engines/__init__.py`, `engines/pivot.py`, `engines/candle.py`.
- `tools/model_dataset/tests/__init__.py`, `fixtures.py`,
  `test_contract.py`, `test_features.py`, `test_clock.py`,
  `test_structure.py`, `test_pivot.py`, `test_candle.py`,
  `test_extensions.py`. Reuse unittest; no new runner or dependency.
- `tools/candle_pattern_ml/tests/fixtures/schema_v3.mqh`: byte-identical
  relocation of the legacy generated header, retained as a contract fixture.
- `docs/architecture/model-feature-dataset.md`: authoritative common contract
  and new-engine integration procedure.
- `tools/model_dataset/README.md`: local command and operational usage.
- `docs/research/model-feature-producer-handoff.md`: final version/source pins,
  representative runs, legacy mappings and acceptance limits for later Django
  planning. It is a handoff, not a backend implementation plan.

### 4.3 Environment and retained evidence

- Physical checkout: `/home/admin/mql5_projects/HFT_Grid_AI`; the Wine-visible
  alias is the current workspace supplied by the user.
- Native root: `C:/MetaTrader 5-1/MQL5`. Compile existing entrypoints under
  `Experts/HFT_Grid_AI/`; tester settings belong under `Profiles/Tester/`.
- Reuse `.venv/bin/python`, Python 3.12, existing pinned dependencies and
  stdlib Decimal/SQLite/zoneinfo. No package install/upgrade is planned.
- New private evidence root:
  `.codex-artifacts/model-feature-framework/s1/` through `s6/`.
  Runtime settings, hashes, reports, exports and binaries remain ignored.
- Reuse applicable baselines from `.codex-artifacts/v14-optimization/`,
  `.codex-artifacts/candle-clock-normalization/`,
  `.codex-artifacts/candle-lot-normalization/` and
  `.codex-artifacts/stochastic-structure-implementation/`.
  Their receipts are historical evidence, not passes for the new implementation.

## 5. Task Context And Prerequisites

### 5.1 Guidance and graph evidence

- Reused guidance search: `data pipeline schema versioning feature engineering
  architecture`, at most five candidates, pinned library revision
  `4b57740b1048475aeb21d9adfc9ecea0affa97b7`.
  Selected `data-engineering-data-pipeline` for schema evolution, quality and
  lineage principles. No support files, cloud stack, setup or dependencies were
  needed. Local broker/data rules and Planner remain authoritative.
- Understand-Anything graphs refreshed during planning on 2026-09-24.
  `services`: 46 file nodes, no parsed MQL5 relationships; file-only coverage.
  Artifact:
  `/home/admin/.cache/codex-skill-stack/graphs/3b77e337ea639ce9e6fedf5192c979f3d2adf8f78a5fc3a065a977215d95ff6c/knowledge-graph.json`.
- `tools/candle_pattern_ml`: 12 files, 38 nodes, 44 edges; 11 Python files were
  structurally parsed and reused on refresh, README file-only, 35 unresolved
  imports. Artifact:
  `/home/admin/.cache/codex-skill-stack/graphs/0f1371f8d905923131a137a2aba934a5b370687fdb739e34da882ed3d20b4ba3/knowledge-graph.json`.
- Graph helper-reported source revision:
  `6df3065f1d8ddc2ce3615314d1d493f36d6b1c80`; repository baseline is the
  separate hash at this plan's start. Readiness/fingerprints were refreshed;
  graphs do not establish complete MQL5 dependencies. Entry aggregators, Deep
  references, feature formulas, Candle clocks/context and structure transitions
  were confirmed directly in source.
- Final implementation refresh on 2026-09-24: `services` has 44 file-only MQL
  nodes and no parsed edges; `tools/model_dataset` has 19 files, 66 nodes,
  75 edges, 18 parsed Python files and 41 unresolved imports. The services
  artifact above is refreshed. The new reader artifact is
  `/home/admin/.cache/codex-skill-stack/graphs/c999b9f304aaa21409c57bb0c34ed7a085bb2f0b8c6e601a4803ba2685aa965e/knowledge-graph.json`.
  The pinned helper revision is unchanged. Source/binary evidence is independently
  bound to S5 `c0a1189`; exact 40-file Pivot/17-file Candle include closures and
  manual broker-boundary/deletion review cover the MQL graph limitation.

### 5.2 Official references and tool routes

The following official MetaQuotes references were fetched successfully during
planning on 2026-09-24. Earlier requests without a browser User-Agent returned
403; direct retrieval with that header resolved the documentation limitation.

- [iBands](https://www.mql5.com/en/docs/indicators/ibands)
- [iStochastic](https://www.mql5.com/en/docs/indicators/istochastic)
- [iATR](https://www.mql5.com/en/docs/indicators/iatr)
- [Applied price and Stochastic price constants](https://www.mql5.com/en/docs/constants/indicatorconstants/prices)
- [CopyBuffer](https://www.mql5.com/en/docs/series/copybuffer)
- [MqlTick](https://www.mql5.com/en/docs/constants/structures/mqltick)

Use local Git/native source reads for this checkout and RTK for noisy results.
The retained plugin's `references/project-mcp-routing.md` was consulted.
MetaEditor and MT5 `get_workspace_info` both succeeded during planning, reporting
build 6184, AVX2 and compile/tester capability. This was discovery only.
Call workspace discovery again at execution-session start before each server's
operations. Discover schemas; compile through MetaEditor and test through MT5.
Use the documented native compiler fallback only when MCP cannot execute, with
the exact reason recorded. Do not add servers, edit plugin caches/global config,
start another provider or spawn agents.

### 5.3 Execution prerequisites

- Confirm branch/worktree ownership and inspect any existing Planner state.
  One agent/writer; preserve unrelated work and stop on unexpected changes.
- Preserve baseline source include hashes and matching EX5s before replacing
  an entrypoint. Do not overwrite a binary used by another operator's tester.
- Pin accepted XAUUSD/EURUSD custom-symbol specifications, clock/source
  provenance, native settings and bounded QA intervals. Use fresh run IDs.
- Copy baseline outputs/read-only evidence into the new ignored evidence area
  only when needed; preserve originals, recovered runs and correction sidecars.
- Required native gates need available MetaEditor/MT5 and existing real-tick
  history. An unavailable gate is recorded as blocked/unrun, never counted as
  passed or bypassed by fixtures.
- Human chart review remains a retained release/deployment gate. This plan
  delivers automated producer acceptance and no live rollout; it does not
  certify chart polish, multi-year scale or broker-feed equivalence.

## 6. Validation Commands And Gates

Commands below are implementation gates, not claims of tests run during planning.
Use the existing environment; keep generated reports under the ignored evidence
root. If RTK hides a failure, inspect the smallest raw log needed and retain it.

### V1: Static and documentation gate

```bash
git diff --check
git diff --name-only
git diff --cached --check
git diff --cached --name-status
git check-ignore .codex-hook-state/probe.json .codex-artifacts/probe.txt HFT_Grid_AI.ex5 Candle_Pattern_Discovery.ex5 .venv/probe
```

Resolve changed Markdown links/anchors, instruction length/bytes, requirement
ownership, version claims and ignored artifacts. Read actual include chains and
callbacks before deleting source. For Deep removal, run the targeted sweep below
against active MQL5 sources and inspect every result; older Python/docs/fixtures
are intentionally outside its removal scope.

```bash
rg -n 'Deep_Timeframe|g_deep_|DeepPivot|PIVOT_DEEP_|PivotDeep' HFT_Grid_AI.mq5 services
rg -n '#include|OnInit|OnTick|OnTimer|OnTradeTransaction|OnDeinit|OnTester' HFT_Grid_AI.mq5 Candle_Pattern_Discovery.mq5 services
rg -n 'OrderSend|TRADE_ACTION_SLTP|PositionModify|PositionClosePartial' HFT_Grid_AI.mq5 Candle_Pattern_Discovery.mq5 services
```

An empty required-absence sweep exits 1 normally; distinguish that from a command
failure. Review broker/research boundaries at every source-changing sprint.

### V2: Existing and new Python gates

```bash
rtk test .venv/bin/python -m unittest discover -s tools/model_dataset/tests -t . -p 'test_*.py'
rtk test .venv/bin/python -m unittest discover -s tools/candle_pattern_ml/tests -t . -p 'test_*.py'
rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'
.venv/bin/python -m compileall -q tools/model_dataset tools/candle_pattern_ml tools/deterministic_signal_ml
```

Run the existing Exness tests only if its tooling/fixtures change or a source
provenance concern invalidates retained evidence:

```bash
rtk test .venv/bin/python -m unittest discover -s tools/exness_tick_history/tests -p 'test_*.py'
```

Add these concrete CLI contracts with the new package:

```bash
.venv/bin/python -m tools.model_dataset.schema_contract --write-mql-header services/model_features/schema.mqh
.venv/bin/python -m tools.model_dataset.schema_contract --check-mql-header services/model_features/schema.mqh
.venv/bin/python -m tools.model_dataset.schema_contract --write-json .codex-artifacts/model-feature-framework/s6/consumer-contract.json
.venv/bin/python -m tools.model_dataset.reader "$MODEL_RUN_PATH" --report "$MODEL_REPORT_PATH"
```

`MODEL_RUN_PATH` and `MODEL_REPORT_PATH` are task-specific variables set to a
fresh run and an external report path. Never write a validation report inside
the sealed source directory. The reader exits nonzero on invalid/incompatible
data and reports engine, identities, file counts, incompleteness and exclusions.

### V3: Native compile gate

1. Discover `metaeditor.get_workspace_info({})`.
2. Call `metaeditor.compile_file` with `target="AVX2"`,
   `no_optimization=false`, and the native path to each affected entrypoint:
   `C:/MetaTrader 5-1/MQL5/Experts/HFT_Grid_AI/Candle_Pattern_Discovery.mq5`
   or `C:/MetaTrader 5-1/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5`.
3. Require zero errors and zero warnings. Record full source/include mapping,
   compiler build/target, regenerated EX5 size/mtime/SHA-256 and compiler receipt.
4. Reuse an unchanged entrypoint's passing evidence only when its full include
   tree and compiler inputs remain unchanged. An unused new include has not
   been validated merely because an old EA compiles.

### V4: Native tester protocol

Discover `metatrader5.get_workspace_info` before tester operations. Prepare
fresh owned INI/SET files under its allowed `MQL5/Profiles/Tester` folder,
following the existing no-BOM/native-value settings contract. Run
`tester_run_backtest({config_path, inputs_path, wait:false})`, retain its job
ID and wait/poll in intervals no longer than 60 seconds. A tool timeout does not
stop the job; never launch a duplicate or stop another operator's job.

Use Every tick based on real ticks. Record actual manifest periods, symbol/spec
and clock/source pins, not just intended settings. Validate each sealed export
with V2's reader. Retain ordered native order/deal reports and report format
detection; XML requests may produce XLSX containers.

For baseline-versus-new broker comparisons, normalize only verified run/job
metadata and explicitly versioned ownership magic/comment identities. If native
tickets differ, establish a one-to-one chronology/geometry mapping and retain
both originals; do not drop unmatched orders/deals. Prices, volume, SL/TP,
request/result sequence, entry/close clocks, costs and outcomes must match.
Export-on/off comparisons for one version must match without such engine-version
exceptions. Never compare only total profit.

## 7. Sprint 1: Freeze The Contract And Baseline

- **Goal:** A reviewable, versioned producer contract and recoverable baseline.
- **Dependencies:** Decisions D01-D12; later implementation authorization.
- **Tracked scope:** This plan, `docs/architecture/model-feature-dataset.md`,
`docs/README.md`, and concise navigation updates to `AGENTS.md`/existing guides.
- **Commit:** `docs(dataset): define shared engine feature contract`
- **Rollback point:** Record the actual pre-S1 HEAD; planning reference is
`5df19f1849d6208ddae64fa29951f0f81477aa6e`.

### Task 1.1: Pin preservation and native comparison inputs

- **Location:** Existing sources/receipts listed in section 4; new private
  `.codex-artifacts/model-feature-framework/s1/`.
- **Work:** Map both entrypoint include trees, source and EX5 hashes, actual
  defaults, signal/trial/broker identities and retained accepted native cases.
  Preserve binaries without overwriting active operator files. Identify which
  baseline cases are reusable and run only missing/invalidated baselines.
- **Acceptance:** Each engine has a reproducible source/binary/settings/source-
  data reference and explicit broker-versus-research preservation checklist.
  No new behavior is declared accepted.
- **Validation:** V1; inspect hashes against retained receipts. If a baseline
  compile/test is necessary, use V3/V4 and record its actual result.
- **Rollback:** Documentation revert only; retain all private baseline artifacts.

### Task 1.2: Freeze schema, feature and lifecycle mappings

- **Location:** `docs/architecture/model-feature-dataset.md`; this plan.
- **Work:** Specify exact ordered columns, scalar types, nullability, identities,
  source precision and table relationships for section 3. Map retained legacy
  facts explicitly; distinguish removed features/Deep facts from preserved broker
  evidence. Define field classifications: CAUSAL_FEATURE, EXECUTION_FACT,
  OUTCOME_ONLY and PROVENANCE. Define engine extension registration and the
  immutable manifest/seal contract.
- **Acceptance:** Both engines have complete signal/attempt/trial/outcome maps.
  Forming structure is separately named, causal and never a confirmed label.
  Warmup/cold states, pivot AT/UNTESTED/unavailable states, all clock triplets
  and censored durations have unambiguous definitions.
- **Validation:** Review against the source owners and official references in
  sections 4/5; enumerate every old fact as mapped, intentionally removed or
  historical-only. No unresolved product decision is deferred into coding.
- **Rollback:** Revert this contract with the sprint; do not reinterpret any run.

### Task 1.3: Establish current-plan ownership

- **Location:** `docs/README.md`, `AGENTS.md`, affected guide navigation.
- **Work:** Point current work to this plan. Label earlier completed execution
  records as historical and never restart them. Keep currently running EA/schema
  facts accurate until each adoption sprint lands. Schedule final archive/link
  cleanup for Sprint 6.
- **Acceptance:** One current plan; historical evidence and operational gates
  remain reachable. AGENTS remains within 160 lines / 8 KiB.
- **Validation:** V1, all changed links/anchors and exact requirement-owner review.
- **Rollback:** Restore pre-sprint navigation with the reviewed revert.

**S1 gate:** All tasks/required checks complete; record residual risks, actual
rollback parent and exactly one S1 commit before beginning S2.

## 8. Sprint 2: Implement The Local Dataset Contract

- **Goal:** Both engine profiles validate through one bounded local reader using
meaningful synthetic fixtures, before a producer changes formats.
- **Dependencies:** S1 committed.
- **Tracked scope:** `tools/model_dataset/`, its README/tests and contract
clarifications in `docs/architecture/model-feature-dataset.md`.
- **Commit:** `feat(dataset): add versioned engine dataset validation`
- **Rollback point:** S1 commit; record its actual hash before S2.

### Task 2.1: Typed schema and feature registry

- **Location:** `schema_contract.py`, `feature_contract.py`,
  `engines/{pivot,candle}.py` in the new package.
- **Work:** Implement immutable engine profiles, exact file/header/type
  definitions, field classifications, configuration compatibility signatures,
  extension allowlists and the schema/header/JSON export commands in V2.
  Generate MQL output into ignored evidence for inspection during this sprint;
  wire the active generated header only with a real EA in S3.
- **Acceptance:** A third test-only descriptor can declare a typed extension
  without changing core fields or copying base definitions. It is only a Python
  contract fixture, not a new strategy or EA. Unknown/conflicting versions,
  duplicate field names, wrong grains and unsafe file paths fail closed.
- **Validation:** `test_contract.py`, `test_extensions.py`; compare generated
  contracts deterministically and verify that every field has exactly one
  classification. V1.
- **Rollback:** Remove/revert the unused new package; legacy readers stay intact.

### Task 2.2: Streaming reader and engine semantic checks

- **Location:** `reader.py`, `semantics.py`, `clock.py`,
  `engines/{pivot,candle}.py`.
- **Work:** Use bounded streaming plus a disposable SQLite index, following the
  existing Candle reader pattern. Preserve Decimal tokens; verify unchanged
  source hashes, seals/counts, unique keys, references, ordering, snapshots,
  instrument/clock provenance, geometry, parity isolation and engine outcome
  rules. No dynamic SQL identifiers come from unvalidated input.
- **Acceptance:** Common validation is reused by both engines. Root/parent,
  category, ratio, missing feature and censored states cannot leak into an
  incorrect binary target. Actual-close versus observed-close distinction is
  validated. Incompatible engines/configurations are not silently concatenated.
- **Validation:** V2 new suite; malformed headers, partial seals, source mutation,
  Decimal precision, clock folds, duplicate IDs and orphan references fail with
  bounded useful errors. A streamed large fixture verifies bounded memory/index
  behavior without adding another test framework.
- **Rollback:** Revert only the new package; keep generated reports outside runs.

### Task 2.3: Independent feature and temporal fixtures

- **Location:** New `tests/fixtures.py`, `test_features.py`,
  `test_structure.py`, `test_clock.py`, `test_pivot.py`, `test_candle.py`.
- **Work:** Build behavior fixtures for weighted-price %B, SMA5, zero ATR,
  unclipped %B, missing data, Macro intervals and tested-level relations.
  Cover warmup, initial HIGH/LOW, equal levels, all classified swing types and
  transient live reversals. Use a small independent Python oracle and captured
  source sequences; do not merely restate expected output from the producer.
- **Acceptance:** Prefix replay equals the corresponding full-run prefix for
  frozen features. Processing batches or duplicate observations cannot change
  committed structure. A shift-0 threshold cross and reversal never commits
  confirmed state; prior signal snapshots remain unchanged.
- **Validation:** V2; independent IANA checks include exact DST transition
  milliseconds and March/October US/UK mismatch weeks. Legacy Candle and Pivot
  suites pass unchanged.
- **Rollback:** Revert new fixtures/oracles with S2; preserve old fixtures.

**S2 gate:** New and existing affected Python checks pass; no MQL compile claim
for an unused generated header. Record exactly one S2 commit and rollback parent
before S3.

## 9. Sprint 3: Shared Services And Candle Adoption

- **Goal:** Candle emits a complete new-contract run using the shared feature
services while retaining its broker and virtual behavior.
- **Dependencies:** S2 committed; S1 baseline available.
- **Tracked scope:** New `services/model_features.mqh` and directory;
`services/candle_pattern/dataset_adapter.mqh`; affected Candle entrypoint,
config/context/features/export/schema/state/broker/engine files; new package
tests, the legacy Candle header fixture/test path, and current Candle/contract
documentation.
- **Commit:** `feat(candle): adopt shared model feature capture`
- **Rollback point:** S2 commit plus the retained Candle 1.02 EX5.

### Task 3.1: Shared as-of providers

- **Location:** Shared `types.mqh`, `clock.mqh`, `indicators.mqh`,
  `pivot_context.mqh`, `stochastic_structure.mqh`.
- **Work:** Implement the exact contracts in 3.3-3.6, cached handle ownership,
  bounded warmup/catch-up, bar/tick consistency checks and independent per-family
  availability. Preserve algorithm attribution. Keep the existing standalone
  structure indicator unchanged as the comparison reference.
- **Acceptance:** Both confirmed and forming structure are captured. A live
  projection mutates only its copy. Trigger Bid zones are direction-independent;
  execution Ask/Bid facts remain separate. No rendering, per-tick creation,
  unbounded history scan or broker action exists in these modules.
- **Validation:** V1/V3 through the actual Candle include tree, V2 feature tests
  and V4 native source/indicator comparisons. Review exact source-rate and buffer
  shift alignment, partial initialization and release ownership. Compile/native
  checks complete after Task 3.2 wires the provider into the real entrypoint.
- **Rollback:** Revert the new shared service and Candle wiring together; never
  leave an EA including reverted types or an unmatched binary.

### Task 3.2: Shared writer and Candle adapter

- **Location:** Shared `export.mqh`, generated `schema.mqh`, aggregator;
  `services/candle_pattern/dataset_adapter.mqh` and affected Candle sources.
- **Dependencies:** Task 3.1 provider implementation and S2's typed contract.
- **Work:** Generate the header with V2's command. Implement safe fresh-run IDs,
  exact headers, immutable snapshots, bounded checked batch writes, explicit
  failure latch, seal/counts and external diagnostics. Map Candle facts to common
  and extension rows; share identical base snapshots only when their complete
  capture identity matches. Switch to the new identity/root and update version.
  Move the byte-identical legacy header from `services/candle_pattern/schema.mqh`
  to `tools/candle_pattern_ml/tests/fixtures/schema_v3.mqh`, update
  `test_clock.py` to compare the generator against that fixture, and correct
  the legacy README's generation command. Preserve the old generator/headers'
  semantics and verify the relocation hash before removing the active include.
- **Acceptance:** Candle uses shared clock/numeric/feature/export services with
  no old/new dual writer. Keep its execution ATR and fresh broker calculations
  independent. Export-off retains all execution behavior and no research state.
  Failed research releases only owned research resources and stops only its
  tester, retaining the first diagnostic and broker reconciliation ownership.
- **Validation:** V1/V2/V3; generated-header equality; fault fixtures for bad
  columns, nulls, missing files, failed persistence and invalid final seals.
  Check current include order for cycles and duplicate definitions.
- **Rollback:** Restore Candle 1.02 source and matching binary via the sprint
  revert; retain every old/new/failed run without conversion.

### Task 3.3: Candle behavior and new feature acceptance

- **Location:** Candle/new dataset tests; private `s3/` receipts; current docs.
- **Dependencies:** Tasks 3.1 and 3.2 integrated and compiled successfully.
- **Work:** Run bounded default H1/M3 and H2/M3 native cases, reference/fixed lot
  modes, an expiry-observable M6/M3 case, and export-on/off comparisons. Compare
  new broker results with S1's accepted Candle baseline.
- **Acceptance:** Preserve separate direction attempts, original/re-entry
  membership, fresh ATR risk, immutable stops, actual time exits, rejections,
  broker R1/virtual R2/R3 and exact parity. New feature snapshots validate under
  the strict reader, including at least observed forming structure values.
- **Validation:** V2/V3/V4; independently recompute sampled %B/SMA5 and ATR/SMA5
  from the captured native inputs at the same instant. Confirm old Pivot source
  include hashes/binary are unchanged by this adoption.
- **Rollback:** Revert S3 as a unit, restore the pinned Candle EX5 while idle;
  retain receipts and source exports.

**S3 gate:** A sealed native Candle run validates; broker parity and required
fault/feature checks pass. Record exact changed paths, one S3 commit and rollback
parent before migrating Pivot.

## 10. Sprint 4: Pivot Macro/Micro Migration And Deep Removal

- **Goal:** Pivot emits the common contract using Macro/Micro features, with Deep
absent from its active runtime and Macro trading behavior preserved.
- **Dependencies:** S3 committed; both adapters use the same frozen core contract.
- **Tracked scope:** `HFT_Grid_AI.mq5`, ordered aggregators, Pivot input/config/
indicator/state/signal/trial/export/reconciliation modules named in section 4,
new `pivot_dataset_adapter.mqh`, proved-unused Deep modules, tests and Pivot
runtime/current documentation.
- **Commit:** `refactor(pivot): simplify capture to macro and micro`
- **Rollback point:** S3 commit plus the retained Pivot 1.40 EX5.

### Task 4.1: Adapt Pivot facts and millisecond capture

- **Location:** `pivot_dataset_adapter.mqh`, `pivot_signal_struct.mqh`,
  `pivot_fractal_signal_detection.mqh`, trial/lifecycle and broker modules.
- **Work:** Map origin, virtual lane, actual broker and parity records to the
  frozen common contract. Replace origin Macro/Deep capture with shared
  Macro/Micro capture. Add actual tick/deal milliseconds to exported facts
  without changing existing native window/consumption/scheduling rules.
  Preserve raw order and geometry evidence through the new ownership namespace.
- **Acceptance:** Direction-independent first consumption, PP arm/return,
  structural stop mapping, fresh one-FOK 1R, eight Macro virtual lanes, midpoint
  admission/expiry and exact parity survive. Snapshot readiness never gates
  execution. Actual deal close time stays distinct from reconciliation time.
- **Validation:** V1/V2/V3; native origin/lane/broker comparison to S1, excluding
  only intentional versioned capture differences. Check same-second and
  same-millisecond events, delayed broker observation and censor nullability.
- **Rollback:** Restore matching old source/EX5 together; preserve new exports
  under their own identities.

### Task 4.2: Remove Deep dependencies and old active writer

- **Location:** `HFT_Grid_AI.mq5`, `ea_inputs.mqh`,
  `indicator_definitions_loader.mqh`, `pivot_fractal_engine_config.mqh`,
  `pivot_fractal_engine_state.mqh`, `services/core/enums.mqh`,
  `services/trading_signals.mqh`, Deep modules and proved-unused old capture/
  export implementations.
- **Work:** Remove Deep input/order validation, window/global state, callbacks,
  handles, fan-out reservations, counters, parent-close transfer hooks, finalizers
  and serialization. Remove dead code only after exact reference/include and
  callback/fixture discovery. Replace needed writer calls with real new adapter
  operations, not V14 compatibility aliases.
  Complete the shared primitive/include ownership review: new-engine capture
  must not require Pivot- or Candle-specific configuration/state headers.
- **Acceptance:** New Pivot exposes only Macro/Micro roles and validates
  `Micro < Macro`. No active Deep state or output remains. Generic PERIOD_M10,
  Candle re-entry parent links and required broker cleanup remain intact.
  Old V14 Python tooling and fixtures still work on old runs.
- **Validation:** V1's exact sweeps and manual include tracing; V2/V3 for both
  EAs whenever a shared include changes. Retain removal/equivalence evidence.
- **Rollback:** Revert S4 as a complete graph of dependent includes; do not
  restore only a deleted file against the new runtime.

### Task 4.3: Preserve Macro behavior through native comparison

- **Location:** New Pivot tests; `.codex-artifacts/model-feature-framework/s4/`.
- **Dependencies:** Tasks 4.1 and 4.2 integrated and compiled successfully.
- **Work:** Run H1/M3 and H2/M3 native cases with export on/off; compare broker
  behavior and retained Macro virtual facts to equivalent baseline settings
  whose old Deep input did not affect the broker lane.
- **Acceptance:** All required ordered broker facts match. Midpoint rollover,
  touch/no-touch, surviving structural lanes, all ratios and capacity/ineligibility
  states preserve their meaning. Deep row removal and feature/clock version
  changes are reported explicitly rather than presented as byte parity.
- **Validation:** V2/V3/V4; strict new runs and unchanged legacy fixtures. Verify
  Candle still compiles/validates if S4 touched shared dependencies.
- **Rollback:** S3 code plus the retained Pivot 1.40 binary; preserve S4 evidence.

**S4 gate:** Both new producers are runnable and strict-valid; Deep non-use,
Macro preservation and broker comparisons pass. Record one S4 commit and its
rollback parent before S5.

## 11. Sprint 5: Cross-Engine Native Acceptance

- **Goal:** Establish bounded, reproducible evidence for the new common contract,
live forming features, clocks, failure handling and broker independence.
- **Dependencies:** S4 committed; both engine profiles and native baselines exist.
- **Tracked scope:** Behavior-focused fixes/tests in affected sources and
`tools/model_dataset/`; validation guidance/current evidence references.
- **Commit:** `test(dataset): verify cross-engine capture and broker parity`
- **Rollback point:** S4 commit and its matching producer binaries.

### Task 5.1: Feature, clock and lifecycle matrix

- **Location:** New tests plus owned native settings/reports under private `s5/`.
- **Work:** Execute the matrix below, reusing passing evidence only for identical
  source/binary/configuration/data inputs. Use cross-engine equality only where
  the entire captured quote/bar/profile identity matches; coincident seconds
  alone are insufficient.
- **Acceptance:** Shared definitions agree with independent source calculations.
  Future bars cannot alter prior snapshots; raw timing is unaffected by seasonal
  analysis shifts. Each engine retains its own outcome policy.
- **Validation:** V2/V3/V4; retain field-level first differences, actual sample
  counts, source captures and hashes. Missing native coverage remains a gate,
  not an inferred pass.
- **Rollback:** Revert S5 fixes to S4 and restore corresponding binaries; retain
  raw evidence for both versions.

| Case | Concrete coverage |
| --- | --- |
| Default summer | Both engines, XAUUSD_Exness_2015, 2015-08-17 to 2015-08-18, H1/M3, fresh export-on/off pairs. |
| Non-default periods | Both engines H2/M3 on the same source interval; Candle M6/M3 for actual expiry closes; H1/M1 for shared M1 Stochastic handle use. |
| Winter | Both engines, XAUUSD_Exness_2015, 2016-01-14 to 2016-01-15, fixed and Exness clocks with raw/broker parity. |
| March mismatch week | XAUUSD_Exness_2015 and EURUSD_Exness_2015, 2016-03-16 to 2016-03-17; both use the US clock policy. |
| October mismatch week | XAUUSD_Exness_2015, 2016-10-31 to 2016-11-01; normalized clock compared independently. |
| Exact DST instants | Existing-style independent Python calendars at transition milliseconds, including a backward fold and date/year boundary. Do not claim Sunday native coverage from weekday runs. |
| Forming structure | Native sampled live projections plus independent prefix fixtures: candidate extension, temporary 80/20 cross/reversal, later confirmation, equal pivots, missing comparator and frozen snapshots. |
| Initialization | Bounded prehistory, fewer than 4,096 bars, incomplete indicator history and catch-up; actual source prefix is retained. |
| Pivot context | Above/at/below tested support and resistance, UNTESTED, unavailable ladder, outside S3/R3, gaps, PP departure/return, simultaneous outermost tie and Macro reset. |
| Lifecycle | Pivot midpoint/no-touch/censors/all ratios; Candle both directions/re-entry/expiry/rejections; exact broker parity and no ratio duplication of observations. |
| Prefix immutability | Matching-start short and longer natural tester intervals with the same warmup source; compare immutable feature rows before the short run's terminal boundary. |
| Precision | FX and metal raw tokens/specs, quotes near exact pivot boundaries, same-second events, actual deal milliseconds and unavailable clocks. |

S1 verifies that these retained symbols/intervals are still available. If a case
needs a substitute, predeclare an equivalent bounded interval and its reason
before scoring it; do not silently omit the case or replace custom-symbol specs.

### Task 5.2: Research failure and resource bounds

- **Location:** Shared writer/providers, new validator tests and private `s5/`.
- **Work:** In fresh disposable owned runs, retain then remove a required export
  file and corrupt a header in separate cases. Exercise missing optional feature
  data, invalid provenance, same-run identity reuse and reader refusal of an
  incomplete/failed seal. Use existing native fault workflows, not new test EAs.
- **Acceptance:** Fatal research errors latch one useful diagnostic, seal
  FAILED/CENSORED when writable, release only research resources and stop only
  their tester. Ordinary feature gaps remain explicit and do not veto orders.
  No operator run, source import or terminal-global setting is changed.
- **Validation:** V2/V4 and source boundary review. Record active caps, handle
  counts, peak buffers, rows/bytes, elapsed time and bounded process samples on
  a sustained interval. Memory follows bounded active state, not retained
  history; no repeated full-history scans or per-tick handle creation.
- **Rollback:** Restore retained fault-fixture files outside their original
  sealed directories as evidence; use new run IDs for corrected tests. Revert
  any fixes with S5, leaving earlier datasets untouched.

Report performance cost relative to the same accepted baseline and inputs.
New features do not imply an automatic speedup, and removing Deep does not prove
absence of long-run leaks. Do not publish profitability or full-history claims.

**S5 gate:** Required automated matrix and fault/resource checks pass with
reproducible receipts. Fix failures within this sprint and rerun only affected
checks. Record one S5 commit and rollback parent before S6.

## 12. Sprint 6: Documentation, Cleanup And Producer Handoff

- **Goal:** A maintainable MQL5 framework and a complete contract for later backend
planning, with historical recovery and outstanding operational gates preserved.
- **Dependencies:** S5 committed; accepted source/binary/data receipts available.
- **Tracked scope:** Canonical contract, new tool README, producer handoff,
`README.md`, `docs/README.md`, `AGENTS.md`, existing runtime/environment/tool
guides, and scoped historical plan/document navigation.
- **Commit:** `docs(dataset): publish shared producer contract and handoff`
- **Rollback point:** S5 commit; this sprint should be documentation-only unless a
documented validation issue requires a separately reviewed scoped correction.

### Task 6.1: Update owners and retire superseded active navigation

- **Location:** Project/architecture/environment/tool guides and AGENTS.
- **Work:** Describe current versions, shared core, two configurable roles,
  fixed M1 source, forming-versus-confirmed semantics, two pivot categorical
  features and new run root. Keep historical V14/Candle readers documented as
  historical. Archive the completed `candle-pattern-discovery-plan.md` under
  `docs/plans/archive/` after migrating unique facts and recording its Git
  commit/path recovery; update inbound links. Do not restart it or rewrite dated
  acceptance facts.
- **Acceptance:** One current plan and one owner for each contract/procedure.
  Old recovered-run, broker-equivalence and chart gates remain in the index.
  A guide never describes new %B as old frozen-price %B or forming structure
  as a confirmed historical label.
- **Validation:** V1; link/anchor and exact old/new identifier sweeps. Confirm
  AGENTS size and all legacy recovery routes.
- **Rollback:** Revert documentation/navigation together; preserve dated files.

### Task 6.2: Produce the backend-neutral handoff

- **Location:** `docs/research/model-feature-producer-handoff.md`,
  canonical contract, schema generator and private `s6/` artifact bundle.
- **Work:** Export the machine-readable contract, checksums, representative
  valid and intentionally invalid examples, native/source/EX5 pins, validation
  commands/results and old-to-new field/grain/version mapping. Include reference
  clock and indicator examples, classification of causal versus future facts,
  warmup/forming-state limits and a concise new-engine integration checklist.
- **Acceptance:** A later Django planner can determine what to import and how
  to interpret it without reading this chat. The handoff states that existing
  backend importers have not been changed or certified for these exports.
  Keep private native datasets/account-related metadata in ignored artifacts;
  tracked examples are synthetic and clearly identified.
- **Validation:** Regenerate/check header and contract with V2 commands; run the
  strict reader against the exact referenced accepted runs and verify hashes.
  Reuse unchanged passing evidence where appropriate.
- **Rollback:** Restore S5 documentation, retaining all immutable release evidence.

### Task 6.3: Final gate and retained limits

- **Location:** This plan, project index, private execution receipts.
- **Work:** Review include/deletion proof, final broker/research boundaries,
  old-reader preservation, exact sprint commits/parents and remaining gates.
  Record which binaries are accepted for offline tester use and which human/
  full-history/source-equivalence checks remain open.
- **Acceptance:** No hidden Django dependency or work, no active Deep path,
  no unreviewed runtime deletion and no live-deployment claim. Subsequent engine
  work has a documented minimal adapter/extension/fixture workflow.
- **Validation:** V1 and only those V2/V3/V4 gates whose inputs changed since
  their last recorded pass. Review staged paths and clean final working state.
- **Rollback:** Documentation revert; binary rollback is required only if an
  explicitly recorded source correction was included.

**S6 gate:** Final handoff and checks complete; record exactly one S6 commit,
rollback parent and residual operational gates. Automated implementation
completion does not close human chart or live deployment gates.

## 13. Testing Strategy And Risks

1. **Contract/unit:** Strict types, decimal tokens, nullability, file/header
   identity, extensions, referential integrity, defaults and feature registry.
2. **Causality:** As-of weighted %B, native main/average alignment, source clocks,
   warmup boundaries, prefix immutability and confirmed/forming separation.
3. **Engine integration:** Preserved Pivot Macro and Candle lifecycle semantics,
   all existing lot rules, broker/virtual/parity separation and explicit censors.
4. **Native acceptance:** Actual compiled EAs, real-tick cases, exact broker
   comparisons, source-informed feature checks, clocks, faults and resource bounds.
5. **Historical compatibility:** Existing local suites/readers and retained raw
   runs; no implicit schema conversion or fabricated old feature values.
6. **Operational limits:** Read-only frontend boundary, no chart work in nonvisual
   capture, one writer, isolated native jobs and retained manual release gates.

| Risk | Mitigation | Required signal |
| --- | --- | --- |
| New shared code affects orders | Keep engine execution ownership and execution ATR separate; no feature eligibility gate | Baseline/new and export-on/off ordered broker parity |
| %B silently retains old meaning | Own weighted price at every shift; new feature/schema identity | Independent native-source calculations and old/new rejection fixtures |
| Forming structure leaks future confirmation | Copy committed state for each projection; freeze at trigger | Intrabar cross/reversal and prefix tests |
| Warmup changes initial structure | Bound and fingerprint actual source prefix; explicit initial/truncated states | Same-prefix replay conformance and native initialization evidence |
| Different clocks are normalized twice | Versioned exported triplets; raw chronology authoritative | IANA transition/fold tests and cross-mode raw parity |
| Symbol names falsely imply equivalent feeds | Explicit verified mappings and source/spec hashes | Unmapped/incompatible aggregation refusal |
| Deep removal deletes broker cleanup or Macro behavior | Exact source/include/callback sweeps and legacy comparison | No active Deep references, preserved Macro ledger and orders |
| Universal rows erase engine semantics | Typed extensions and engine validators | Cross-engine wrong-policy/grain fixtures rejected |
| Feature multiplicity inflates sample support | One snapshot per capture identity; explicit attempts/trials/root IDs | Ratio/parent duplicate and parity-isolation checks |
| Export failures orphan broker state | Separate research cleanup and unconditional first diagnostic | Owned native fault runs and source ownership review |
| Big runs exhaust memory or handles | Bounded buffers/state, cached handles, streaming validation | Sustained resource evidence with explicit limits |
| Old importer consumes new semantics | New namespace/version, strict dispatch, explicit handoff | Old/new reader mismatch refusal |

## 14. Rollback And Execution Order

Rollback restores code and its matching binary independently from data. Revert
reviewed sprint commits in reverse dependency order; never reset hard, amend or
rewrite history. Preserve original/failed/new exports, warmup/source captures,
recovered data and provenance sidecars. Replace binaries only while their owned
tester is idle; this plan never authorizes touching live exposure.

| Sprint | Required rollback parent |
| --- | --- |
| S1 | Actual pre-S1 HEAD, with planning reference 5df19f1 |
| S2 | Recorded S1 commit |
| S3 | Recorded S2 commit and retained Candle 1.02 binary |
| S4 | Recorded S3 commit and retained Pivot 1.40 binary |
| S5 | Recorded S4 commit and its matching new producer binaries |
| S6 | Recorded S5 commit |

Before authorized execution, read the loaded Planner's
`/home/admin/.codex/skills/planner/references/execution-state.md`. Inspect retained
state rather than overwriting it. Initialize this plan's state before S1 and
record validation, commit, blocker, sprint advance and completion transitions.
Pending required questions block dependent work and must survive compaction.

For every sprint, in order:

1. Record its starting HEAD/rollback parent and implement only that sprint.
2. Complete all tasks and required checks; retain actual exits/results and limits.
3. Review the diff, stage only reviewed paths and create exactly one
   sprint-specific commit using its proposed message.
4. Record that commit and rollback receipt before starting the next sprint.
5. On failure or missing required input, keep the sprint incomplete and continue
   only independent authorized work. Never treat a timeout or a recommendation
   as an answer or a passing gate.

Independent read-only checks may run concurrently when their inputs are stable.
Dependent edits, native tester jobs and sprint commits are sequential. There is
no subagent delegation and no parallel writer workstream in this plan.

## 15. Completion Checklist

- [x] S1: Contract, baselines and current-plan ownership complete; commit gate recorded in the execution journal.
- [x] S2: Strict shared validator, registry and fixtures complete; commit gate recorded in the execution journal.
- [x] S3: Candle adoption, shared services and required acceptance committed.
- [x] S4: Pivot migration/Deep removal and preservation evidence committed.
- [x] S5: Cross-engine native/fault/resource acceptance committed.
- [x] S6: Maintained documentation and producer handoff committed.
- [x] Each sprint has exactly one commit and a recorded rollback parent.
- [x] New snapshots contain confirmed and live forming M1 structure separately.
- [x] Pivot zones include trigger relation to tested support/resistance.
- [x] Legacy datasets/readers and operator evidence remain intact.
- [x] No Django repository or runtime has been modified.
- [x] Human chart, broker-equivalence and full-history limits remain explicit.
- [x] No live trading, deployment or production intake has been performed.

Execution receipts are retained in
`.codex-artifacts/model-feature-framework/execution-journal.md`, with each
sprint's validation and rollback parent. Commits S1-S5 are `8a6381a`, `4bbfafe`,
`f5920fb`, `5394705` and `c0a1189`; S6 is this documentation-completion commit,
whose exact SHA is recorded in the journal after commit. The accepted runtime
source remains S5, with matching B03 binaries; S6 changes documentation only.
The [project index](docs/README.md) owns current acceptance and remaining gates;
the [producer handoff](docs/research/model-feature-producer-handoff.md) locates
the final contract, examples and exact source/binary/native-run receipts.

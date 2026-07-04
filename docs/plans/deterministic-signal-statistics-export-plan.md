# Plan: Deterministic Signal Statistics Export

**Generated**: 2026-07-04
**Estimated Complexity**: Medium
**Risk Level**: Medium for signal lifecycle instrumentation and file I/O; Low for trading behavior if export remains passive and disabled by default.

## Overview

Implement Phase 1 of the deterministic signal ML roadmap: a lightweight EA-side
statistics export layer for deterministic signals.

The feature captures compact, deterministic input features and terminal
outcomes into versioned TSV files. It must not train a model, run inference,
block trades, change broker execution, or introduce PostgreSQL/Python
dependencies.

The exported data is intended for later local Python processing into Parquet and
XGBoost training datasets.

## Locked Recommendations

- Export is disabled by default.
- `Signal_Feature_Run_Id` may be left empty; an empty value auto-generates a
  timestamp/symbol/timeframe-based run ID.
- Main ML feature rows are written for deterministic signals that reach real
  broker entry.
- Candidate-only rows are out of scope for the first implementation unless a
  later decision explicitly adds an audit-only file.
- Feature rows and outcome rows are separate files joined by `signal_id`.
- Outcome fields must not be used as training features.
- Invalid or missing numeric feature fields use `\N`; `0` is reserved for
  intentional neutral values such as equal/invalid macro direction.
- Macro MA direction uses the same deterministic SMA 21 close policy and live
  slope semantics:

```text
H1: MA[0] compared with MA[1]
H4: MA[0] compared with MA[1]
D1: MA[0] compared with MA[1]
```

- Feature set stays intentionally small:

```text
macro_h1_live_dir
macro_h4_live_dir
macro_d1_live_dir
sl_fib_raw
sl_fib_band
entry_fib_raw
entry_fib_band
low_chain_score_3
low_chain_score_5
low_chain_score_10
high_chain_score_3
high_chain_score_5
high_chain_score_10
```

- Fibonacci reference for the current Stoch Structure source:

```text
slot[0] = current source extremum / SL anchor
slot[1] = previous opposite extremum / 0 percent
slot[2] = previous same-type extremum / 100 percent
```

- No PostgreSQL work is included in this plan.

## Prerequisites

- Current deterministic strategy lifecycle remains the source of signal
  identity and entry/outcome events.
- Include pipeline remains ordered through the existing service aggregators.
- No custom MQL5 test harness is introduced.
- Implementation sprints compile at sprint end with MetaEditor portable/headless
  first when code changes are made.
- Human-in-the-loop Strategy Tester verification remains required for runtime
  data inspection.

## Sprint 1: Export Contract And Inputs

**Goal**: Define the statistics export contract, input surface, file namespace,
and schema versions without changing runtime behavior.
**Commit**: `docs: define deterministic signal statistics export contract`
**Demo/Validation**:
- Static review confirms Phase 1 scope excludes ML training, inference,
  PostgreSQL, and trade filtering.
- Static review confirms schema fields are small, stable, and joinable.

### Task 1.1: Define Export Schema Contract

- **Location**:
  - `docs/plans/deterministic-signal-statistics-export-plan.md`
- **Description**: Keep this plan as the first implementation contract for the
  Phase 1 export schema and lifecycle boundaries.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Feature and outcome file roles are explicit.
  - Feature columns are listed and intentionally compact.
  - Outcome fields are explicitly separated from training features.
  - PostgreSQL, Python, Parquet, DuckDB, XGBoost, and inference are non-goals.
- **Validation**:
  - Manual review against `docs/plans/deterministic-signal-ml-roadmap.md`.

### Task 1.2: Add Export Input Contract

- **Location**:
  - `services/trading_management/ea_inputs.mqh`
- **Description**: Add the minimal input contract for Phase 1 export.
- **Recommended Inputs**:
  - `Enable_Signal_Feature_Export = false`
  - `Signal_Feature_Run_Id = ""`
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Export remains disabled by default.
  - Empty run ID resolves to a deterministic timestamp/symbol/timeframe-based
    runtime ID.
  - Inputs do not affect signal detection, entry, SL, TP, broker execution, or
    lifecycle reconciliation.
- **Validation**:
  - Static review of input names and defaults.
  - Compile at sprint end if code is changed.

### Task 1.3: Define File Namespace And Schema Constants

- **Location**:
  - New `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals.mqh`
- **Description**: Define constants for schema version, storage root, filenames,
  and headers.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - Storage root is versioned and strategy-specific enough to avoid accidental
    cross-run mixing.
  - Headers are stable and written once per file.
  - Files use TSV delimiter semantics.
  - File paths live under `Common\Files`.
- **Validation**:
  - Static review of filename builders and headers.
  - Compile at sprint end.

## Sprint 2: Runtime Identity And Manifest

**Goal**: Create stable run/config/signal identity and write a manifest for each
export-enabled tester run.
**Commit**: `feat: add deterministic statistics run manifest`
**Demo/Validation**:
- With export enabled, a run folder and manifest are created.
- With export disabled, no files are written.

### Task 2.1: Build Run And Config IDs

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Build stable `run_id` and `config_id` values for export rows.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - `run_id` identifies one Strategy Tester or chart run.
  - `config_id` hashes relevant strategy/export configuration.
  - IDs are sanitized for file paths and TSV cells.
  - No account number, license key, or sensitive data is written.
- **Validation**:
  - Static review of included config fields.
  - Confirm license/account secrets are excluded.

### Task 2.2: Build Signal IDs

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/signal_params_struct.mqh` only if persistence
    inside `SignalParams` is needed
- **Description**: Derive a stable `signal_id` from run identity and existing
  deterministic source identity.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - `signal_id` includes or hashes `run_id`, `source_key`, and
    `source_attempt_index`.
  - The ID is stable across feature and outcome files for the same signal.
  - Existing deterministic `source_key` behavior is not changed.
- **Validation**:
  - Static trace from feature snapshot to outcome snapshot.
  - Compile at sprint end.

### Task 2.3: Write Run Manifest

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `HFT_Grid_AI.mq5` for init/deinit lifecycle calls if needed
- **Description**: Write one run manifest at export startup.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Manifest includes schema version, run ID, config ID, symbol, chart period,
    deterministic strategy toggles, TP percent, direction mode, concurrency
    mode, export start time, and relevant feature policy.
  - Manifest excludes license keys and account identifiers.
  - Missing export permission or file errors fail export closed without stopping
    the EA.
- **Validation**:
  - Human-in-the-loop tester run with export enabled.
  - Inspect manifest file manually.

## Sprint 3: Feature Snapshot Calculation

**Goal**: Capture the compact feature snapshot for deterministic signals that
successfully enter.
**Commit**: `feat: capture deterministic signal feature snapshots`
**Demo/Validation**:
- `signal_features.tsv` contains one feature row per entered deterministic
  signal.
- Rows contain valid macro, Fibonacci, and chain-score fields or explicit
  invalid tokens when required source data is unavailable.

### Task 3.1: Add Macro MA Handles

- **Location**:
  - `services/trading_management/indicator_definitions_loader.mqh`
  - `services/trading_signals/market_signal_indicators.mqh`
- **Description**: Reuse deterministic MA handle patterns to load SMA 21 close
  handles for H1, H4, and D1 when export is enabled.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Handles are created once, not per tick.
  - Handles are released during deinit cleanup.
  - Export disabled keeps overhead near zero.
  - `CopyBuffer` reads only the needed `[0]` and `[1]` values.
- **Validation**:
  - Static review for no per-tick handle creation.
  - Compile.

### Task 3.2: Calculate Macro Direction Features

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - `services/trading_signals/market_signal_indicators.mqh`
- **Description**: Calculate signed live macro direction features.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - `+1` means `MA[0] > MA[1]`.
  - `-1` means `MA[0] < MA[1]`.
  - `0` means equal, invalid, or unavailable.
  - No raw MA values are exported in Phase 1.
- **Validation**:
  - Static review of comparison semantics.
  - Human-in-the-loop log/file check on one tester run.

### Task 3.3: Calculate Fibonacci Features

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
  - Existing Fibonacci helpers in `services/indicators/fibonacci_calculator.mqh`
    and range helpers in `services/trading_management/structure_fibonacci_levels.mqh`
- **Description**: Calculate raw and banded Fibonacci levels for SL anchor and
  final entry trigger.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Uses `os_market_structures[0]`, `[1]`, and `[2]` with type validation.
  - PEAK and BOTTOM formulas are directionally correct.
  - Raw values can exceed 100 without artificial cap.
  - Bands are generated from the agreed base levels and repeat into extensions.
  - Invalid source structure writes explicit invalid tokens rather than guessed
    values.
- **Validation**:
  - Static review of PEAK/BOTTOM formulas.
  - Manual spot-check against one logged source extremum.

### Task 3.4: Calculate High/Low Chain Scores

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Calculate signed chain scores for M1 highs and lows over
  windows 3, 5, and 10 immediately before entry.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Uses one bounded `CopyRates` or equivalent bounded rates read.
  - No full-history scans.
  - Score increments `+1` for rising comparisons and `-1` for falling
    comparisons.
  - Equal or unavailable comparisons contribute `0`.
  - Outputs are bounded by each window size.
- **Validation**:
  - Static review of array bounds and rates indexing.
  - Human-in-the-loop tester file check.

### Task 3.5: Emit Feature Rows At Entry

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Emit one feature row after deterministic broker entry is
  successfully accepted and the final entry geometry is known.
- **Dependencies**: Tasks 3.1-3.4.
- **Acceptance Criteria**:
  - One row per deterministic broker-entered signal.
  - Uses final refreshed entry trigger/entry reference.
  - Does not emit candidate-only rows in Phase 1.
  - Repeated ticks cannot duplicate the same feature row.
  - Export failures do not affect trading behavior.
- **Validation**:
  - Human-in-the-loop Strategy Tester run with export enabled.
  - Inspect `signal_features.tsv`.
  - Compile.

## Sprint 4: Outcome Snapshot Export

**Goal**: Export terminal result rows separately from feature rows.
**Commit**: `feat: export deterministic signal outcome snapshots`
**Demo/Validation**:
- `signal_outcomes.tsv` contains one terminal row per exported deterministic
  feature signal after TP, SL, forced close, or other terminal lifecycle event.

### Task 4.1: Define Outcome Fields

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Define compact outcome rows for later supervised learning and
  interpretation.
- **Recommended Fields**:
  - `schema_version`
  - `run_id`
  - `config_id`
  - `signal_id`
  - `source_key`
  - `source_attempt_index`
  - `terminal_time`
  - `terminal_reason`
  - `profit_r`
  - `duration_seconds`
  - `duration_m1_bars`
  - `entry_price`
  - `close_price`
  - `net_profit`
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Outcome fields are not mixed into feature rows.
  - `profit_r` is derived from entry-to-stop risk when available.
  - Missing broker facts write explicit invalid tokens.
- **Validation**:
  - Static review against current TP/SL/close lifecycle.

### Task 4.2: Emit Outcome Rows On Terminal Events

- **Location**:
  - `services/trading_signals/execution_controller.mqh`
  - `services/trading_signals/execution_lifecycle.mqh` if terminal handling is
    centralized there
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Write outcome rows once when exported deterministic signals
  close or reach a terminal state.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - TP, SL, and forced close outcomes are distinguishable.
  - Rows are deduped by `signal_id`.
  - Outcome export does not alter close behavior.
  - Broker-confirmed facts are preferred after real execution exists.
- **Validation**:
  - Human-in-the-loop tester run with at least one close event.
  - Inspect `signal_outcomes.tsv`.
  - Compile.

## Sprint 5: Buffering, Summary, And Documentation

**Goal**: Keep file I/O efficient and document how to use the Phase 1 export.
**Commit**: `docs: document deterministic signal statistics export`
**Demo/Validation**:
- Export can run through a tester pass without noisy per-tick file writes.
- Documentation explains where files live and how to join feature/outcome rows.

### Task 5.1: Add Buffered Writes

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Buffer feature/outcome rows in memory and flush at bounded
  lifecycle points.
- **Dependencies**: Sprints 3 and 4.
- **Acceptance Criteria**:
  - No file open/write on every tick.
  - Rows flush on deinit and after a configurable or fixed small batch size.
  - Flush failures are logged but do not stop trading behavior.
  - Memory growth is bounded by flushing policy.
- **Validation**:
  - Static review of buffer sizes and flush calls.
  - Human-in-the-loop tester run with export enabled.

### Task 5.2: Write Run Summary

- **Location**:
  - `services/trading_signals/deterministic_signal_statistics_export.mqh`
- **Description**: Write a compact run summary at deinit.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Summary includes rows written, rows skipped, invalid feature counts, outcome
    counts, start/end times, and export status.
  - Summary does not duplicate the full dataset.
- **Validation**:
  - Inspect `run_summary.tsv` after a tester run.

### Task 5.3: Document Operator Workflow

- **Location**:
  - `README.md`
  - `docs/plans/deterministic-signal-statistics-export-plan.md`
- **Description**: Document the Phase 1 tester workflow and file outputs.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - Documentation states export is research-only and disabled by default.
  - Documentation states files are generated under Common Files.
  - Documentation states no Python/ML/inference is included in Phase 1.
  - Documentation explains `signal_id` joins.
- **Validation**:
  - Static documentation review.

## Testing Strategy

- Documentation-only tasks do not run MT5 compile.
- Implementation sprints compile once at sprint end.
- Preferred compile command:

```powershell
$mt5Root = "C:\Program Files\MetaTrader 5-1"
$metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
$entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$log = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile\signal-statistics-export.log"
& $metaeditor /portable /s /compile:$entrypoint /log:$log
```

- Treat warnings and errors as sprint failures.
- Human-in-the-loop Strategy Tester checks:
  - Export disabled writes no files.
  - Export enabled writes manifest, features, outcomes, and summary.
  - Feature rows appear only after deterministic broker entry.
  - Outcome rows join to feature rows by `signal_id`.
  - No duplicate feature or outcome rows for the same signal.
  - Existing deterministic entries, SL, TP, broker reconciliation, and chart
    behavior remain unchanged.

## Potential Risks And Gotchas

- **Feature leakage**: Outcome or future bars can accidentally enter feature
  rows. Mitigation: feature snapshot is captured at entry and outcome file is
  separate.
- **Ambiguous macro slope**: Live H1/H4/D1 bars can change after capture.
  Mitigation: field names include `live`, and values are interpreted as
  point-in-time state.
- **Fibonacci source mismatch**: Slot assumptions can fail if structure data is
  incomplete. Mitigation: validate slot count and types; write invalid tokens
  rather than infer.
- **Duplicate rows**: Entry refreshes or lifecycle retries can duplicate rows.
  Mitigation: dedupe by `signal_id` and row type.
- **Tester slowdown**: Per-event file I/O can hurt real-tick testing.
  Mitigation: buffer rows and flush in batches/deinit.
- **Config mixing**: Rows from different settings can be combined accidentally.
  Mitigation: include schema version, run ID, and config ID in every row.
- **Sensitive data exposure**: Manifest could leak account/license data.
  Mitigation: explicitly exclude license keys, account identifiers, and broker
  credentials.

## Resolved Product Decisions

- Empty `Signal_Feature_Run_Id` auto-generates a timestamped run ID.
- Phase 1 exports only real broker-entered deterministic signals.
- Candidate-created and expired-only signals are not exported in Phase 1.
- Invalid or missing numeric fields use `\N`.
- `0` is valid only for intentional neutral/flat direction fields.

## Rollback Plan

- Disable `Enable_Signal_Feature_Export` to stop all export behavior.
- Remove the statistics export include from `services/trading_signals.mqh` if
  compile or runtime issues appear.
- Remove generated Common Files output manually; generated TSV files are not
  source-controlled.
- Revert only the Phase 1 implementation commit if rollback is needed.

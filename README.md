# HFT Grid AI Foundation

**Platform:** MetaTrader 5 (MQL5)
**Entrypoint:** `HFT_Grid_AI.mq5`
**Current focus:** final refounded EA foundation baseline for future strategy integration

HFT Grid AI has been refounded into a smaller, broker-aware MT5 Expert Advisor foundation. Legacy strategy features, retired public domain naming, and custom test infrastructure have been removed before new strategies are integrated.

## Current Docs

- `AGENTS.md`: contributor and Codex-agent rules for the current foundation.
- `docs/plans/archive/refoundation-baseline-2026-07-03/`: completed Phase 0-8 refoundation plans.
- `docs/plans/archive/codex-skill-stack-alignment-2026-07-03/`: completed Codex skill-stack alignment plan.
- `docs/architecture/execution-foundation.md`: local/broker execution foundation.

## Validation Model

- Documentation-only phases do not run MT5 compile.
- Implementation phases compile once at phase end.
- Portable/headless MetaEditor compile is preferred.
- Normal MetaEditor compile is the fallback.
- Legacy custom MQL5 tests, test harnesses, and agentic CI are not part of the active validation model.

Preferred compile command shape for implementation phases:

```powershell
$mt5Root = "C:\Program Files\MetaTrader 5-1"
$metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
$entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$log = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile\phase-build.log"
& $metaeditor /portable /s /compile:$entrypoint /log:$log
```

Fallback:

```powershell
& $metaeditor /s /compile:$entrypoint /log:$log
```

## Refoundation Scope

Legacy strategy feature groups and their public inputs have been removed from the active foundation. Do not preserve them through deprecated shims, aliases, docs, or compatibility layers.

Preserved foundation areas:

- License and account settings.
- Protection/risk controls.
- Session time filters.
- Strategy timeframe, Stoch Structure period, direction mode, and concurrency mode unless a later phase changes them explicitly.
- Strategy range and risk settings.
- Developer debug controls.
- Stoch Structure as the structural context source.

## Execution Direction

The target lifecycle is:

```text
inputs
-> indicator/context hydration
-> strategy candidate detection
-> local broker-aware execution simulation
-> execution plan
-> optional real broker execution
-> broker position reconciliation
-> protection/risk controls
-> telemetry/frontend
```

Before a real broker position exists, local simulation owns candidate state and applies broker conditions. After a real position exists, broker state owns ticket, volume, entry price, close state, and profit.

## Deterministic Signal Statistics Export

Phase 1 adds an optional TSV export for deterministic, broker-entered signals.
It is disabled by default through `Enable_Signal_Feature_Export = false`.
`Signal_Feature_Run_Id` may be left empty; the EA then creates a sanitized run
ID from symbol, timeframe, and start time.

When enabled, files are written under MT5 `Common\Files`:

```text
DeterministicSignalML\runs\<run_id>\
```

The run folder contains:

- `run_manifest.tsv`: schema, run/config IDs, and non-sensitive strategy config.
- `signal_features.tsv`: compact feature rows captured after real broker entry.
- `signal_outcomes.tsv`: broker-confirmed terminal outcomes joined by `signal_id`.
- `run_summary.tsv`: row counts, invalid-row counts, and final export status.

The export is passive. It does not train models, call Python, query PostgreSQL,
run inference, change entries, change exits, or bypass broker/risk controls.

## Local Dataset Builder

Phase 2 adds local Python tooling under `tools/deterministic_signal_ml/` to
validate Phase 1 TSV exports and build local Parquet datasets.

Setup:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r tools\deterministic_signal_ml\requirements.txt
```

Validate a Phase 1 run without writing outputs:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\build_dataset.py `
  --runs-root "C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DeterministicSignalML\runs" `
  --run-id test_run_1 `
  --dataset-id test_dataset_1 `
  --validate-only
```

Build a local dataset:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\build_dataset.py `
  --runs-root "C:\Users\loldlm\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DeterministicSignalML\runs" `
  --run-id test_run_1 `
  --dataset-id test_dataset_1
```

Generated files are written under `artifacts/datasets/<dataset_id>/` and are
ignored by git. Phase 2 does not train models or run EA inference.

## Local XGBoost Training

Phase 3 adds local Python research training under
`tools/deterministic_signal_ml/`. It trains a classifier for `target_is_win` and
a secondary regressor for `target_profit_r` from Phase 2 Parquet datasets.

Train the current local dataset:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\train_model.py `
  --dataset-id test_dataset_1 `
  --model-id xgb_test_1 `
  --overwrite
```

Generated files are written under `artifacts/models/<model_id>/` and are ignored
by git. The trainer uses deterministic one-hot encoding, a chronological final
holdout, and walk-forward folds. Random split metrics are not used because they
can leak future market conditions into validation.

Phase 3 is research-only: no EA inputs, no Strategy Tester inference, no
PostgreSQL, no Python execution from MQL5, and no trading filter is active yet.
The XGBoost JSON files are Python booster artifacts, not MT5-readable inference
artifacts.

## Local Model Artifact Export

Phase 4 exports a Phase 3 model into MT5-readable TSV artifacts while keeping
the EA unchanged.

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\export_model_artifact.py `
  --model-id xgb_test_1 `
  --dataset-id test_dataset_1 `
  --export-id xgb_test_1_export_v1 `
  --overwrite
```

Validate the exported artifact:

```powershell
.\.venv\Scripts\python.exe tools\deterministic_signal_ml\model_artifact_validator.py `
  --export-id xgb_test_1_export_v1
```

Generated files are written under `artifacts/model_exports/<export_id>/` and are
ignored by git. Phase 4 produces `model_manifest.tsv`, `feature_map.tsv`,
flattened classifier/regressor tree TSVs, threshold metadata, and parity
reports. It does not add EA inputs, load artifacts in `OnInit`, run Strategy
Tester inference, or affect broker admission.

## Final Baseline Notes

- Phase 8 final compile passed on 2026-07-03 with `0 errors, 0 warnings`; evidence log: `logs/compile/phase-08-build.log`.
- Future strategies should plug into the strategy candidate and execution plan boundary, not bypass broker-aware execution.
- Local simulated state remains the pre-trade decision source; broker position state remains the post-trade source of truth.
- Real-tick performance boundaries from Phase 7 are part of the baseline: cached indicator handles, bounded structure reads, gated logging, and throttled chart refresh.

## Repository Layout

- `HFT_Grid_AI.mq5`: EA entrypoint.
- `services/`: ordered include pipeline and EA services.
- `indicators/`: indicator sources used by the EA.
- `docs/`: active plans when present, archived plans, architecture, and product docs.

Legacy custom tests and the old test runner were removed in Phase 2. The active validation path is MT5 compile at implementation phase end.

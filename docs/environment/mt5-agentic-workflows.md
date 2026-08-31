# MT5 Agentic Workflows

This runbook is the source of truth for V13 local paths, deterministic Python
evidence, the single final MetaEditor compile, and operator-owned Strategy
Tester artifacts. Keep full logs and raw market data out of chat and commits.

## Path Contract

### Windows

```powershell
$MT5_ROOT = "C:\Program Files\MetaTrader 5-1"
$METAEDITOR = Join-Path $MT5_ROOT "MetaEditor64.exe"
$EA_ENTRYPOINT = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$COMPILE_LOG = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\logs\compile\agentic-build.log"
$MT5_COMMON_FILES = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$PIVOT_RUNS_ROOT = Join-Path $MT5_COMMON_FILES "PivotFractalV13\runs"
```

### Ubuntu/Wine

```bash
export MT5_ROOT="/home/loldlm/mql5_projects/metatrader_5_market_data_framework"
export METAEDITOR="$MT5_ROOT/MetaEditor64.exe"
export EA_ENTRYPOINT="$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5"
export COMPILE_LOG="$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/logs/compile/agentic-build.log"
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
export PIVOT_RUNS_ROOT="$MT5_COMMON_FILES/PivotFractalV13/runs"
```

If the Wine prefix changes, locate only the Common Files directory:

```bash
find "$HOME/.wine" "$HOME/.mt5" "$HOME/.config" -maxdepth 8 \
  -type d -path '*/MetaQuotes/Terminal/Common/Files' 2>/dev/null
```

## Runtime Resources

When export is enabled, V13 owns exactly four cached built-in handles:
Macro/Micro Bands and Macro/Micro Stochastic. Bands use period `21`, shift `0`,
deviation `2.0`, SMA, and `PRICE_WEIGHTED`; Stochastic uses `K=5`, `D=3`,
slowing `3`, `MODE_SMA`, and `STO_CLOSECLOSE`. The configured Micro source is
captured once per shared M10 event (M3 by default).

Handles, deep state, and the twelve V13 files are disabled when export is off.
Handles are created during initialization and released safely after partial
initialization and normal deinitialization. There is no custom indicator or
runtime-model artifact requirement.

## Compile Policy

- Intermediate sprints use static review and Python evidence only.
- Sprint 8 owns the one final real MetaEditor compile.
- Call MetaEditor MCP `get_workspace_info` first, verify allowed roots and
  `can_compile_file`, then call `compile_file` for the absolute EA path.
- Accept only `0 errors, 0 warnings`, and verify that `HFT_Grid_AI.ex5` was
  regenerated (timestamp, size, and hash where available).
- MetaEditor `/s` syntax checks are not binary acceptance evidence.
- Use the project-native runner only when MCP cannot execute, and record the
  precise fallback reason in the handoff.

### Project-Native Fallback

Ubuntu/Wine:

```bash
python3 tools/mt5/compile_mt5.py \
  --wine \
  --mt5-root "$MT5_ROOT" \
  --entrypoint "$EA_ENTRYPOINT" \
  --log "$COMPILE_LOG" \
  --mode compile
```

Windows PowerShell:

```powershell
py -3.12 tools\mt5\compile_mt5.py `
  --mt5-root $MT5_ROOT `
  --entrypoint $EA_ENTRYPOINT `
  --log $COMPILE_LOG `
  --mode compile
```

Record parsed compiler status and `.ex5` metadata, not the full log.

## Python Validation

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/deterministic_signal_ml/requirements.txt
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
.venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
```

Generated datasets, audits, reports, and offline models remain under ignored
`artifacts/` directories.

## V13 Artifact Inventory

```bash
export PIVOT_RUN_ID="<run_id>"
export PIVOT_DATASET_ID="<dataset_id>"
export PIVOT_AUDIT_ID="<audit_id>"

find "$PIVOT_RUNS_ROOT/$PIVOT_RUN_ID" -maxdepth 1 -type f \
  -printf '%f %s bytes\n' 2>/dev/null | sort
```

Every run must contain exactly twelve files in the contract order:

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

The root is `Common\\Files\\PivotFractalV13\\runs\\<run_id>\\`; older
schema roots are not intake aliases.

## Validate, Build, And Audit

```bash
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

The builder creates native-grain H1, deep-parent, broker, and parity artifacts.
The audit reports row, event, parent, and unique-origin support separately;
capacity rejection and censoring are not binary losses.

## Offline Training Boundary

Select exactly one explicit grain:

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

H1 training reads eligible structural/midpoint rows and balances by
`origin_id`. Deep training joins one event feature vector to explicit parent
links and keeps event/parent/origin support visible. Lifecycle duration,
terminal status, censoring, broker money, and post-trigger age selections are
not model features. Every model manifest states
`approval_state=OFFLINE_RESEARCH_ONLY` and `runtime_artifact_emitted=false`.

## Human Strategy Tester Gate

Use `docs/workflows/pivot-fractal-statistics-flow.md` and test with **Every tick
based on real ticks**. The operator must verify midpoint touch and no-touch,
all H1 ratios, shared M10 event/M3 capture, parent-specific censoring,
uncapped R5 continuation, same-tick ordering, one structural broker `1R` lane,
no deep order submission, export-off parity, DST/session behavior, bounded
state, and chart behavior.

Compare export disabled/enabled on the same interval with file logs off. Record
elapsed time, peak state/capacity, twelve-file row counts, and folder growth.
Python fixtures and compilation cannot replace this human gate.

## Evidence And Privacy

Keep raw TSVs, tester journals, account identifiers, credentials, and private
terminal data operator-owned. Handoff records contain bounded status, hashes,
paths, counts, and first useful diagnostics only. A failed-integrity run gets a
new run ID after correction; its raw files are not edited in place.

The V13 handoff does not authorize live rollout or the downstream Django V12
removal. Older-engine positions must be flat, the account must support hedging,
and one EA instance per account/symbol requires separate human authorization.

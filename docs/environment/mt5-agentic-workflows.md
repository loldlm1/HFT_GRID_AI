# MT5 Agentic Workflows

This runbook is the source of truth for local paths, the final MetaEditor
compile gate, Common Files V9 artifacts, and compact evidence handling.

Do not paste full compile logs, `query_debug.txt`, TSV/Parquet contents, model
JSON, or generated datasets into chat. Report paths, sizes, counts, final
status, and the first useful failure lines.

## Path Contract

### Windows

```powershell
$MT5_ROOT = "C:\Program Files\MetaTrader 5-1"
$METAEDITOR = Join-Path $MT5_ROOT "MetaEditor64.exe"
$EA_ENTRYPOINT = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$COMPILE_LOG = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\logs\compile\agentic-build.log"
$MT5_COMMON_FILES = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$PIVOT_RUNS_ROOT = Join-Path $MT5_COMMON_FILES "PivotFractalV9\runs"
```

### Ubuntu/Wine

Observed on this workstation:

```bash
export MT5_ROOT="/home/loldlm/mql5_projects/metatrader_5_market_data_framework"
export METAEDITOR="$MT5_ROOT/MetaEditor64.exe"
export EA_ENTRYPOINT="$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5"
export COMPILE_LOG="$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/logs/compile/agentic-build.log"
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
export PIVOT_RUNS_ROOT="$MT5_COMMON_FILES/PivotFractalV9/runs"
```

If the Wine prefix changes, locate Common Files without dumping contents:

```bash
find "$HOME/.wine" "$HOME/.mt5" "$HOME/.config" -maxdepth 8 \
  -type d -path '*/MetaQuotes/Terminal/Common/Files' 2>/dev/null
```

## Runtime Indicator Placement

V9 feature export loads `Examples\Stochastic_Structure.ex5` for the six context
timeframes. The canonical source in this checkout is
`indicators/Stochastic_Structure.mq5`; the compiled runtime copy must exist at:

```text
<MT5_ROOT>\MQL5\Indicators\Examples\Stochastic_Structure.ex5
```

Raw `%B` features use cached built-in `iBands` handles. There is no separate
custom Bollinger indicator in the active runtime or tracked reference set.
Indicator handles are created at initialization only when V9 export is enabled
and are released during deinitialization.

## Compile Policy

- Documentation-only and intermediate implementation sprints do not run
  MetaEditor.
- Substantial multi-sprint MQL5 plans use static validation per intermediate
  sprint and one final real compile sprint.
- Do not add custom MQL5 tests, harnesses, test EAs/scripts, or CI.
- Final success requires `0 errors, 0 warnings` and regenerated
  `HFT_Grid_AI.ex5`.
- MetaEditor `/s` is syntax-only and is not final build evidence.

### Preferred Final Compile

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

Record the helper result, parsed final compiler status, and `.ex5` timestamp,
size, and change from the precompile value. On Wine, record a process return
code discrepancy alongside the parsed compiler result.

### Direct Fallback

Ubuntu/Wine:

```bash
entrypoint_win="$(winepath -w "$EA_ENTRYPOINT")"
log_win="$(winepath -w "$COMPILE_LOG")"
wine "$METAEDITOR" /portable "/compile:$entrypoint_win" "/log:$log_win"
iconv -f UTF-16 -t UTF-8 "$COMPILE_LOG" | tail -20
```

Windows PowerShell:

```powershell
& $METAEDITOR /portable /compile:$EA_ENTRYPOINT /log:$COMPILE_LOG
Get-Content $COMPILE_LOG -Tail 20
```

## Python Research Environment

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/deterministic_signal_ml/requirements.txt
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
.venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
```

Dependencies remain pinned. Generated datasets, audits, reports, and offline
models stay under ignored `artifacts/` directories.

## V9 Artifact Inventory

```bash
export PIVOT_V9_RUN_ID="<v9_run_id>"
export PIVOT_V9_DATASET_ID="<v9_dataset_id>"
export PIVOT_V9_AUDIT_ID="<v9_audit_id>"

find "$PIVOT_RUNS_ROOT/$PIVOT_V9_RUN_ID" -maxdepth 1 -type f \
  -printf '%f %s bytes\n' 2>/dev/null | sort

find "artifacts/datasets/$PIVOT_V9_DATASET_ID" \
  "artifacts/audits/$PIVOT_V9_AUDIT_ID" -maxdepth 1 -type f \
  -printf '%p %s bytes\n' 2>/dev/null | sort
```

Compact Parquet counts:

```bash
.venv/bin/python - <<'PY'
import os
from pathlib import Path
import duckdb

dataset = Path("artifacts/datasets") / os.environ["PIVOT_V9_DATASET_ID"]
for name in (
    "pivot_windows.parquet",
    "pivot_levels.parquet",
    "signal_attempts.parquet",
    "signal_features.parquet",
    "execution_checks.parquet",
    "trailing_events.parquet",
    "signal_outcomes.parquet",
    "training_matrix.parquet",
):
    path = dataset / name
    if path.exists():
        count = duckdb.sql(
            f"select count(*) from read_parquet('{path.as_posix()}')"
        ).fetchone()[0]
        print(name, count)
PY
```

## Validate, Build, Audit, And Train

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id "$PIVOT_V9_RUN_ID" \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id "$PIVOT_V9_RUN_ID" \
  --dataset-id "$PIVOT_V9_DATASET_ID" \
  --target-family broker_outcome \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id "$PIVOT_V9_DATASET_ID" \
  --audit-id "$PIVOT_V9_AUDIT_ID" \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id "$PIVOT_V9_DATASET_ID" \
  --model-id <v9_model_id> \
  --target-family broker_outcome \
  --overwrite
```

Use `--target-family admission` for a separate denied/unfilled-attempt study.
Do not combine admission and broker-outcome targets. Training is offline-only
and never approves or emits an MT5 runtime artifact.

Record schema/run/config/engine identity; window, level, attempt, feature,
check, trailing, and outcome counts; output sizes; and final validator status.
An accepted evidence run ends naturally with `completion_status=NATURAL`,
`export_status=OK`, six context rows per complete attempt, and zero duplicate or
integrity errors.

## Final Human Strategy Tester Gate

Use the matrix in `docs/workflows/pivot-fractal-statistics-flow.md`. It covers
broker-native timeframe transitions, Bid/Ask first-touch behavior, same-tick
confluence, all route families, trailing retries, broker denials, ticket-owned
outcomes, V9 features, winter/summer time normalization, bounded visuals, and
export performance.

Compare export disabled and V9 export enabled with file logs off over the same
1-3 market days before a longer run. Record elapsed time, row counts, and
folder growth. Human acceptance is required; compilation and fixtures cannot
substitute for it.

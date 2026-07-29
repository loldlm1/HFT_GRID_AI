# MT5 Agentic Workflows

This runbook is the source of truth for local paths, the final MetaEditor
compile gate, Common Files, schema v8 artifacts, and compact evidence handling.

Do not paste full compile logs, `query_debug.txt`, TSV/Parquet contents, model
JSON, or tree TSV files into chat. Report paths, sizes, counts, final status,
and the first useful failure lines.

## Path Contract

### Windows

```powershell
$MT5_ROOT = "C:\Program Files\MetaTrader 5-1"
$METAEDITOR = Join-Path $MT5_ROOT "MetaEditor64.exe"
$EA_ENTRYPOINT = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$COMPILE_LOG = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\logs\compile\agentic-build.log"
$MT5_COMMON_FILES = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$DETERMINISTIC_RUNS_ROOT = Join-Path $MT5_COMMON_FILES "DeterministicSignalML\runs"
```

### Ubuntu/Wine

Observed on this workstation:

```bash
export MT5_ROOT="/home/loldlm/mql5_projects/metatrader_5_market_data_framework"
export METAEDITOR="$MT5_ROOT/MetaEditor64.exe"
export EA_ENTRYPOINT="$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5"
export COMPILE_LOG="$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/logs/compile/agentic-build.log"
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
export DETERMINISTIC_RUNS_ROOT="$MT5_COMMON_FILES/DeterministicSignalML/runs"
```

If the Wine prefix changes, locate Common Files without dumping contents:

```bash
find "$HOME/.wine" "$HOME/.mt5" "$HOME/.config" -maxdepth 8 \
  -type d -path '*/MetaQuotes/Terminal/Common/Files' 2>/dev/null
```

## Runtime Indicator Placement

The EA loads `Examples\Stochastic_Structure.ex5`. The canonical source in this
checkout is `indicators/Stochastic_Structure.mq5`; the runtime copy must exist
at:

```text
<MT5_ROOT>\MQL5\Indicators\Examples\Stochastic_Structure.ex5
```

`indicators/BB_Percent_Standard.mq5` remains a maintained reference indicator,
but schema v8 B-percent features use built-in `iBands` handles. Do not restore
deleted ATR, Keltner, MACD, Body MA, or generic Bollinger indicator sources to
the EA include/runtime graph.

## Compile Policy

- Documentation-only sprints do not run MetaEditor.
- Substantial multi-sprint MQL5 plans use static validation in intermediate
  sprints and one final real compile sprint.
- Do not add custom MQL5 tests, harnesses, test EAs/scripts, or CI.
- Final success requires `0 errors, 0 warnings` and a regenerated `.ex5`.
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

Record the helper result, final compiler status, and `.ex5` timestamp. On Wine,
record the process return code when it differs from the parsed log result.

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

The dependencies are pinned. Generated datasets, audits, pattern audits,
models, exports, and reports remain under ignored `artifacts/` directories.

## Schema V8 Artifact Inventory

```bash
export SCHEMA_V8_RUN_ID="<schema_v8_run_id>"
export SCHEMA_V8_DATASET_ID="<schema_v8_dataset_id>"
export SCHEMA_V8_AUDIT_ID="<schema_v8_audit_id>"

find "$DETERMINISTIC_RUNS_ROOT/$SCHEMA_V8_RUN_ID" -maxdepth 1 -type f \
  -printf '%f %s bytes\n' 2>/dev/null | sort

find "artifacts/datasets/$SCHEMA_V8_DATASET_ID" \
  "artifacts/audits/$SCHEMA_V8_AUDIT_ID" -maxdepth 1 -type f \
  -printf '%p %s bytes\n' 2>/dev/null | sort
```

Compact Parquet counts:

```bash
.venv/bin/python - <<'PY'
import os
from pathlib import Path
import duckdb

dataset = Path("artifacts/datasets") / os.environ["SCHEMA_V8_DATASET_ID"]
for name in (
    "engine_cycles.parquet",
    "engine_revisions.parquet",
    "engine_attempts.parquet",
    "execution_checks.parquet",
    "signal_features.parquet",
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

## Dataset And Audit

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$DETERMINISTIC_RUNS_ROOT" \
  --run-id "$SCHEMA_V8_RUN_ID" \
  --dataset-id "$SCHEMA_V8_DATASET_ID" \
  --schema-version 8 \
  --feature-set-id schema_v8_extremum_engine_xgb \
  --target-family broker_1r \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$DETERMINISTIC_RUNS_ROOT" \
  --run-id "$SCHEMA_V8_RUN_ID" \
  --dataset-id "$SCHEMA_V8_DATASET_ID" \
  --schema-version 8 \
  --feature-set-id schema_v8_extremum_engine_xgb \
  --target-family broker_1r \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/extremum_engine_audit.py \
  --dataset-id "$SCHEMA_V8_DATASET_ID" \
  --audit-id "$SCHEMA_V8_AUDIT_ID" \
  --overwrite
```

Record schema/run/config/engine identity, cycle/revision/attempt/check/outcome
counts, output sizes, and final validator status. Training is optional research
validation and does not approve a runtime artifact.

## Final Human Strategy Tester Gate

Use the exact matrix in
`docs/workflows/extremum-engine-statistics-flow.md`, including winter/summer
US30 dates, US and UK DST boundaries, actual broker-session blocks, hedging
mode, stops/freeze, volume, margin, `OrderCheck`, one-position lifecycle,
schema v8 output, and bounded visual lines.

For performance, compare export disabled and schema v8 export enabled with file
logs off over the same 1-3 market days before attempting a longer run. Record
elapsed time and output growth. Human acceptance is required; compile and
fixtures cannot substitute for it.

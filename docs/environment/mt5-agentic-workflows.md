# MT5 Agentic Workflows

This runbook is the source of truth for Codex-agent MT5 compile, Common Files,
and deterministic signal artifact workflows across Windows and Ubuntu/Wine.

Use it for deterministic signal ML artifact and inference workflows. Do not load full compile logs, `query_debug.txt`,
Parquet files, XGBoost JSON, or tree TSV files into chat. Record paths, sizes,
row counts, final status lines, and selected failure lines only.

## Path Contract

### Windows

```powershell
$MT5_ROOT = "C:\Program Files\MetaTrader 5-1"
$METAEDITOR = Join-Path $MT5_ROOT "MetaEditor64.exe"
$EA_ENTRYPOINT = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$COMPILE_LOG = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\logs\compile\agentic-build.log"
$MT5_COMMON_FILES = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$DETERMINISTIC_RUNS_ROOT = Join-Path $MT5_COMMON_FILES "DeterministicSignalML\runs"
$DATASET_ROOT = "artifacts\datasets"
$AUDIT_ROOT = "artifacts\audits"
$MODEL_ROOT = "artifacts\models"
$MODEL_EXPORT_ROOT = "artifacts\model_exports"
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
export DATASET_ROOT="artifacts/datasets"
export AUDIT_ROOT="artifacts/audits"
export MODEL_ROOT="artifacts/models"
export MODEL_EXPORT_ROOT="artifacts/model_exports"
```

If the Wine prefix changes, find Common Files without dumping contents:

```bash
find "$HOME/.wine" "$HOME/.mt5" "$HOME/.config" -maxdepth 8 \
  -type d -path '*/MetaQuotes/Terminal/Common/Files' 2>/dev/null
```

`FILE_COMMON` data is outside this EA repository. For the statistics exporter,
the expected folder is:

```text
Common\Files\DeterministicSignalML\runs\<run_id>
```

## Compile Modes

MetaEditor `/s` is syntax check. It can return `0 errors, 0 warnings` without
regenerating `.ex5`. Use real compile for implementation validation.

### Preferred Agentic Compile

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

The helper parses the MetaEditor log and treats `0 errors, 0 warnings` as the
source of truth. On Ubuntu/Wine, record both the Wine process exit code and the
log result when they differ.

### Direct Real Compile

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

Validate real compile by confirming:

- final log status is `0 errors, 0 warnings`,
- `.ex5` timestamp changed,
- generated `.ex5` remains ignored by git.

### Syntax Check Only

Use syntax mode only for fast checks when `.ex5` regeneration is not required.

Ubuntu/Wine:

```bash
python3 tools/mt5/compile_mt5.py \
  --wine \
  --mt5-root "$MT5_ROOT" \
  --entrypoint "$EA_ENTRYPOINT" \
  --log "$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/logs/compile/agentic-syntax.log" \
  --mode syntax
```

Windows PowerShell:

```powershell
py -3.12 tools\mt5\compile_mt5.py `
  --mt5-root $MT5_ROOT `
  --entrypoint $EA_ENTRYPOINT `
  --log (Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\logs\compile\agentic-syntax.log") `
  --mode syntax
```

## Python ML Environment

Create a local venv. It is ignored by git.

Ubuntu:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/deterministic_signal_ml/requirements.txt
.venv/bin/python - <<'PY'
import duckdb, numpy, sklearn, xgboost
print("duckdb", duckdb.__version__)
print("numpy", numpy.__version__)
print("sklearn", sklearn.__version__)
print("xgboost", xgboost.__version__)
PY
```

Windows PowerShell:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r tools\deterministic_signal_ml\requirements.txt
.\.venv\Scripts\python.exe -c "import duckdb,numpy,sklearn,xgboost; print(duckdb.__version__, numpy.__version__, sklearn.__version__, xgboost.__version__)"
```

The ML tooling does not require pandas or pyarrow.
The versions in `tools/deterministic_signal_ml/requirements.txt` are pinned to
the accepted local stack. Do not loosen them without rechecking imports and
training on this Ubuntu CPU and on Windows.

## Schema V7 Artifact Inventory

Set the evidence IDs from the human Strategy Tester run, then inspect names,
sizes, and counts without dumping TSV or Parquet contents:

```bash
export SCHEMA_V7_RUN_ID="<schema_v7_run_id>"
export SCHEMA_V7_DATASET_ID="<schema_v7_dataset_id>"
export SCHEMA_V7_AUDIT_ID="<schema_v7_audit_id>"

find "$DETERMINISTIC_RUNS_ROOT/$SCHEMA_V7_RUN_ID" -maxdepth 1 -type f \
  -printf '%f %s bytes\n' 2>/dev/null | sort

find "artifacts/datasets/$SCHEMA_V7_DATASET_ID" \
  "artifacts/audits/$SCHEMA_V7_AUDIT_ID" -maxdepth 1 -type f \
  -printf '%p %s bytes\n' 2>/dev/null | sort
```

Use DuckDB only for compact Parquet row counts:

```bash
.venv/bin/python - <<'PY'
import os
from pathlib import Path
import duckdb

dataset = Path("artifacts/datasets") / os.environ["SCHEMA_V7_DATASET_ID"]
for name in (
    "engine_cycles.parquet",
    "engine_revisions.parquet",
    "engine_attempts.parquet",
    "signal_admissions.parquet",
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

## Schema V7 Dataset And Audit

Run these after a human Strategy Tester export exists under
`DETERMINISTIC_RUNS_ROOT`.

Ubuntu:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$DETERMINISTIC_RUNS_ROOT" \
  --run-id "$SCHEMA_V7_RUN_ID" \
  --dataset-id "$SCHEMA_V7_DATASET_ID" \
  --schema-version 7 \
  --feature-set-id schema_v7_extremum_engine_xgb \
  --target-family broker_1r \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$DETERMINISTIC_RUNS_ROOT" \
  --run-id "$SCHEMA_V7_RUN_ID" \
  --dataset-id "$SCHEMA_V7_DATASET_ID" \
  --schema-version 7 \
  --feature-set-id schema_v7_extremum_engine_xgb \
  --target-family broker_1r \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/extremum_engine_audit.py \
  --dataset-id "$SCHEMA_V7_DATASET_ID" \
  --audit-id "$SCHEMA_V7_AUDIT_ID" \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id "$SCHEMA_V7_DATASET_ID" \
  --model-id <schema_v7_research_model_id> \
  --feature-set-id schema_v7_extremum_engine_xgb \
  --overwrite
```

Windows PowerShell uses the same arguments with `.\.venv\Scripts\python.exe`
  and `$DETERMINISTIC_RUNS_ROOT`.

Record only:

- schema/run/config/engine identity;
- cycle, revision, attempt, admission, and broker outcome counts;
- output sizes and final validator/audit status;
- research model ID and the first useful training failure when support is
  insufficient.

Training is optional research validation. It does not approve or install a
runtime artifact.

## Strategy Tester Performance Evidence

The implementation closeout requires comparable human-run tests with ML
disabled. Use the same symbol, date range, tick model, deposit, broker settings,
and EA inputs:

- A: export disabled and file logs disabled;
- B: schema v7 export enabled and file logs disabled;
- C: schema v7 export enabled and file logs enabled, diagnostic-only.

Complete A and B first over 1-3 market days. Run the full month naturally only
after short-run integrity and performance are accepted. An intentionally
stopped run may be audited as partial diagnostic evidence, but it cannot replace
`run_summary.tsv` or pass dataset validation.

Record elapsed tester time, cycle/revision/attempt counts, peak active simulated
paths, total run-folder bytes, and final status. Do not claim acceptance until
the owner reviews the measured delta. A compile or synthetic fixture cannot
substitute for this comparison.

## Runtime Inference Readiness

There is no schema v7 artifact approved for MT5 runtime. Do not copy a v7
research export into Common Files or run SHADOW/FILTER acceptance as if a model
were approved. Research exports must carry
`runtime_approval=RESEARCH_ONLY_NOT_APPROVED` and fail closed.

The runtime boundary and future compatibility requirements are documented in
`docs/workflows/deterministic-signal-ml-inference-flows.md`. A later explicit
plan must select a model, produce parity evidence, set approval metadata, define
monitoring/rollback, and authorize any runtime installation.

Historical multi-strategy inference instructions and evidence remain immutable
under:

```text
docs/plans/archive/deterministic-signal-ml-2026-07-05/
docs/research/archive/deterministic-signal-ml-2026-07-05/
```

They are historical audit material, not active engine commands. MQL5 inference
must always load files locally and must never call Python, DuckDB, XGBoost, or
external services from the EA hot path.

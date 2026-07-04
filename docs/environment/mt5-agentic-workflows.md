# MT5 Agentic Workflows

This runbook is the source of truth for Codex-agent MT5 compile, Common Files,
and deterministic signal artifact workflows across Windows and Ubuntu/Wine.

Use it before Phase 5 work. Do not load full compile logs, `query_debug.txt`,
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

## Artifact Inventory

Check generated artifact presence without dumping data:

```bash
test -d "$DETERMINISTIC_RUNS_ROOT/test_run_1" && \
  find "$DETERMINISTIC_RUNS_ROOT/test_run_1" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort

find artifacts/datasets/test_dataset_1 artifacts/models/xgb_test_1 \
  artifacts/model_exports/xgb_test_1_export_v1 -maxdepth 1 -type f \
  -printf '%p %s bytes\n' 2>/dev/null | sort
```

If Parquet artifacts exist, use row counts only:

```bash
.venv/bin/python - <<'PY'
import duckdb
for path in [
    "artifacts/datasets/test_dataset_1/features.parquet",
    "artifacts/datasets/test_dataset_1/outcomes.parquet",
    "artifacts/datasets/test_dataset_1/training_matrix.parquet",
]:
    try:
        count = duckdb.sql(f"select count(*) from read_parquet('{path}')").fetchone()[0]
        print(path, count)
    except Exception as exc:
        print(path, "missing_or_invalid", exc.__class__.__name__)
PY
```

## Phase 2-4 Regeneration

Run these only when `test_run_1` exists under `DETERMINISTIC_RUNS_ROOT`.

Ubuntu:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$DETERMINISTIC_RUNS_ROOT" \
  --run-id test_run_1 \
  --dataset-id test_dataset_1 \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$DETERMINISTIC_RUNS_ROOT" \
  --run-id test_run_1 \
  --dataset-id test_dataset_1 \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id test_dataset_1 \
  --model-id xgb_test_1 \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/export_model_artifact.py \
  --model-id xgb_test_1 \
  --dataset-id test_dataset_1 \
  --export-id xgb_test_1_export_v1 \
  --overwrite

.venv/bin/python tools/deterministic_signal_ml/model_artifact_validator.py \
  --export-id xgb_test_1_export_v1
```

Windows PowerShell uses the same arguments with `.\.venv\Scripts\python.exe`
and `$DETERMINISTIC_RUNS_ROOT`.

Record only:

- row counts,
- config ID,
- model ID,
- export ID,
- threshold probability,
- parity status,
- final validator status.

## Phase 5 Readiness

Do not start MQL5 Shadow Inference unless the readiness gate in
`docs/research/deterministic-signal-phase-4-5-environment-acceptance.md` is
`PASS`, or a human explicitly accepts a partial gate.

Phase 5 must load exported artifacts from files and must not call Python,
DuckDB, XGBoost, or external services from the EA hot path.

## Phase 5 Artifact Install Boundary

The repository export under `artifacts/model_exports/<export_id>` is a generated
research artifact. MQL5 runtime code must read the copied export from
`FILE_COMMON`:

```text
Common\Files\DeterministicSignalML\model_exports\<export_id>
```

Validate before copying:

```bash
.venv/bin/python tools/deterministic_signal_ml/model_artifact_validator.py \
  --export-id xgb_test_1_export_v1
```

Ubuntu/Wine copy shape:

```bash
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
mkdir -p "$MT5_COMMON_FILES/DeterministicSignalML/model_exports"
cp -a artifacts/model_exports/xgb_test_1_export_v1 \
  "$MT5_COMMON_FILES/DeterministicSignalML/model_exports/"
find "$MT5_COMMON_FILES/DeterministicSignalML/model_exports/xgb_test_1_export_v1" \
  -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
```

Windows PowerShell copy shape:

```powershell
$MT5_COMMON_FILES = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$dest = Join-Path $MT5_COMMON_FILES "DeterministicSignalML\model_exports"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse -Force artifacts\model_exports\xgb_test_1_export_v1 $dest
Get-ChildItem (Join-Path $dest "xgb_test_1_export_v1") | Select-Object Name,Length
```

Use `ML_Inference_Mode = ML_INFERENCE_SHADOW` only after the export is present
under `Common\Files`. Shadow mode is fail-open for trading: missing or invalid
artifacts must produce compact diagnostics and must not alter broker admission,
entries, exits, lot sizing, SL/TP, license checks, session gates, spread checks,
margin checks, protection controls, or broker reconciliation.

After a human-in-the-loop Strategy Tester run creates shadow output, compare
MQL5 scores against the Python artifact scorer:

```bash
.venv/bin/python tools/deterministic_signal_ml/compare_shadow_predictions.py \
  --export-id xgb_test_1_export_v1 \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>"
```

Record only row counts, max/mean errors, decision agreement, selected failure
lines, and the shadow run path. Do not paste full shadow TSVs into chat.

## Phase 6 Filter Validation

Phase 6 `FILTER` mode is approved for Strategy Tester implementation only. It is
not live-deployment approval.

Use `ML_Inference_Mode = ML_INFERENCE_FILTER` only after the export is present
under `Common\Files`. Filter mode is fail-closed for model admission: missing
artifacts, unavailable model state, invalid features, failed encoding, failed
classifier scoring, and non-tester usage block deterministic model admission.
Existing license, session, spread, broker constraints, margin, protection,
magic-number scope, and broker reconciliation remain the source of truth.

After a human-in-the-loop Strategy Tester run creates filter output, summarize
the run and compare scored predictions:

```bash
.venv/bin/python tools/deterministic_signal_ml/summarize_filter_run.py \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>"

.venv/bin/python tools/deterministic_signal_ml/compare_shadow_predictions.py \
  --export-id xgb_test_1_export_v1 \
  --shadow-run-path "$MT5_COMMON_FILES/DeterministicSignalML/shadow_runs/<shadow_run_id>"
```

Record only compact row counts, allow/block counts, unavailable/invalid counts,
parity status, selected failure lines, and the run path. Do not paste full
shadow/filter TSVs into chat.

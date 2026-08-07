# MT5 Agentic Workflows

This runbook is the source of truth for local paths, the final MetaEditor
compile gate, Common Files V11 artifacts, and compact evidence handling.

Do not paste full compile logs, TSV/Parquet contents, model JSON, or generated
datasets into chat. Report paths, sizes, counts, final status, and the first
useful failure lines.

## Path Contract

### Windows

```powershell
$MT5_ROOT = "C:\Program Files\MetaTrader 5-1"
$METAEDITOR = Join-Path $MT5_ROOT "MetaEditor64.exe"
$EA_ENTRYPOINT = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$COMPILE_LOG = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\logs\compile\agentic-build.log"
$MT5_COMMON_FILES = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$PIVOT_RUNS_ROOT = Join-Path $MT5_COMMON_FILES "PivotFractalV11\runs"
```

### Ubuntu/Wine

Observed on this workstation:

```bash
export MT5_ROOT="/home/loldlm/mql5_projects/metatrader_5_market_data_framework"
export METAEDITOR="$MT5_ROOT/MetaEditor64.exe"
export EA_ENTRYPOINT="$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5"
export COMPILE_LOG="$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/logs/compile/agentic-build.log"
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
export PIVOT_RUNS_ROOT="$MT5_COMMON_FILES/PivotFractalV11/runs"
```

If the Wine prefix changes, locate Common Files without dumping contents:

```bash
find "$HOME/.wine" "$HOME/.mt5" "$HOME/.config" -maxdepth 8 \
  -type d -path '*/MetaQuotes/Terminal/Common/Files' 2>/dev/null
```

## Runtime Indicator Resources

V11 feature export uses only cached built-in `iBands` handles: one for the
configured Macro timeframe and one for Micro. The handles use period `21`,
deviation `2.0`, SMA, and `PRICE_WEIGHTED`; they are created during
initialization only when export is enabled and released during deinitialization.

The same export switch owns the bounded virtual matrix and parity state. No
virtual state, V11 files, or additional Bands work exists when export is off.

There is no custom Stochastic or Bollinger `.ex5` placement requirement.

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
size, and change from the precompile value. On Wine, record any process return
code discrepancy beside the parsed compiler result.

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

## V11 Artifact Inventory

```bash
export PIVOT_RUN_ID="<run_id>"
export PIVOT_DATASET_ID="<dataset_id>"
export PIVOT_AUDIT_ID="<audit_id>"

find "$PIVOT_RUNS_ROOT/$PIVOT_RUN_ID" -maxdepth 1 -type f \
  -printf '%f %s bytes\n' 2>/dev/null | sort

find "artifacts/datasets/$PIVOT_DATASET_ID" \
  "artifacts/audits/$PIVOT_AUDIT_ID" -maxdepth 1 -type f \
  -printf '%p %s bytes\n' 2>/dev/null | sort
```

Compact Parquet counts:

```bash
.venv/bin/python - <<'PY'
import os
from pathlib import Path
import duckdb

dataset = Path("artifacts/datasets") / os.environ["PIVOT_DATASET_ID"]
for name in (
    "run_manifest.parquet",
    "pivot_windows.parquet",
    "signal_origins.parquet",
    "virtual_trials.parquet",
    "virtual_outcomes.parquet",
    "execution_checks.parquet",
    "broker_outcomes.parquet",
    "run_summary.parquet",
    "origin_matrix_long.parquet",
    "initial_matrix_wide.parquet",
    "eligible_virtual_trials.parquet",
    "policy_chains.parquet",
    "broker_virtual_calibration.parquet",
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

.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id "$PIVOT_DATASET_ID" \
  --model-id <model_id>
```

Training is offline-only and never approves or emits an MT5 runtime artifact.
The builder creates long, wide, eligible-trial, policy-chain, and
broker-parity calibration artifacts in addition to typed V11 tables.

Record schema/run/config/engine identity; Macro/Micro, matrix, distance, retry,
capacity, and lot settings; window, origin, trial, parity, broker, excluded,
censored, chain-terminal, and support counts; output sizes; and final validator
status. Accepted evidence ends naturally with
`completion_status=NATURAL`, `export_status=OK`, and zero duplicate,
referential, or row-integrity errors. Natural completion may coexist with
explicit unlabelled run-end virtual censors.

## Final Human Strategy Tester Gate

Use the matrix in `docs/workflows/pivot-fractal-statistics-flow.md` with
`Every tick based on real ticks`. It covers causal Macro/Micro data, direct Bid
virtual limits, PP arming, same-tick gaps, all route families, immutable SL/TP,
broker denials, V11 matrix/retries, parity calibration, DST normalization,
bounded real-position visuals, and export performance. Verify that parity
ignores closed-session threshold candidates and explicitly excludes any
broker-terminal-before-observed-touch censor.

Record the run with
`docs/research/pivot-trial-matrix-v11-acceptance-preparation-2026-08-07.md`.
Do not edit raw TSV evidence and do not replace the human gate with a new MQL5
harness or automated tester workflow.

Compare export disabled and enabled with file logs off over the same 1-3 market
days. Record elapsed time, active-state peak/cap status, row counts, and folder
growth. Human acceptance is required; compilation and fixtures cannot
substitute for it.

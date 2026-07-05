# Plan: Deterministic Signal Phase 4.5 Agentic Environment Portability

**Generated**: 2026-07-04
**Status**: Completed and archived on 2026-07-05
**Estimated Complexity**: Medium
**Risk Level**: Low for EA trading behavior; Medium for workflow correctness if compile status, Common Files paths, or ignored artifacts are misclassified.

## Overview

Create a small bridge phase between completed Phase 4 model artifact export and future Phase 5 MQL5 Shadow Inference.

Phase 4.5 makes Windows and Ubuntu/Wine workflows explicit, reproducible, and safe for Codex agents without adding inference, changing strategy behavior, or committing generated datasets/models. The phase standardizes:

- real MetaEditor compile versus syntax-check commands,
- Ubuntu/Wine and Windows path contracts,
- MT5 `Common\Files` discovery,
- Python ML environment setup,
- deterministic artifact restoration or regeneration,
- compact validation evidence that avoids loading large logs, Parquet files, or model artifacts into chat context.

Execution must complete and validate one sprint before moving to the next.

## Documentation Basis

- MetaEditor command line: `/s` checks syntax without compilation; real compile should use `/compile` without `/s` when `.ex5` regeneration is required. Official source: https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide
- MetaTrader 5 on Linux runs through Wine, and MetaQuotes documents Wine-based Linux installation and data-directory behavior. Official source: https://www.metatrader5.com/en/terminal/help/start_advanced/install_linux
- MQL5 file APIs are sandboxed. `FILE_COMMON` maps files to the shared `\Terminal\Common\Files` folder for all client terminals. Official sources:
  - https://www.mql5.com/en/docs/files/fileopen
  - https://www.mql5.com/en/docs/files/foldercreate

## Prerequisites

- Current repository layout remains `<MT5_ROOT>/MQL5/Experts/HFT_Grid_AI`.
- Windows canonical MT5 root remains `C:\Program Files\MetaTrader 5-1` unless a human updates it.
- Ubuntu observed MT5 root is `/home/loldlm/mql5_projects/metatrader_5_market_data_framework`.
- Ubuntu has Wine available and MT5 can be opened manually by the human operator.
- Ubuntu observed Common Files path is `/home/loldlm/.wine/drive_c/users/loldlm/AppData/Roaming/MetaQuotes/Terminal/Common/Files`.
- Generated files stay ignored:
  - `*.ex5`
  - `logs/`
  - `.venv/`
  - `artifacts/datasets/`
  - `artifacts/models/`
  - `artifacts/model_exports/`
- No broker credentials, license tokens, account numbers, private tester logs, or proprietary data are committed or pasted into chat.

## Non-Goals

- No Phase 5 model loader.
- No MQL5 shadow inference.
- No filter mode.
- No trading behavior changes.
- No Strategy Tester automation or custom MQL5 test harness.
- No CI.
- No committed generated datasets, models, model exports, `.ex5`, or full logs.
- No PostgreSQL.

## Sprint 1: Environment Contract And Runbook

**Goal**: Document the exact Windows and Ubuntu/Wine environment contract so agents can find MT5, MetaEditor, Common Files, and artifact roots without guessing.
**Commit**: `docs: add phase 4.5 environment contract`
**Demo/Validation**:
- Read the runbook and identify the active OS flow in under one minute.
- Static review confirms the runbook distinguishes compile, syntax-check, Common Files, generated artifacts, and non-goals.
- No MetaEditor compile is required because Sprint 1 is documentation-only.

### Task 1.1: Add Agentic Environment Runbook

- **Location**:
  - `docs/environment/mt5-agentic-workflows.md`
- **Description**: Add a concise operator and Codex runbook for Windows and Ubuntu/Wine.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Defines `MT5_ROOT`, `METAEDITOR`, `EA_ENTRYPOINT`, `COMPILE_LOG`, `MT5_COMMON_FILES`, `DETERMINISTIC_RUNS_ROOT`, `DATASET_ROOT`, `MODEL_ROOT`, and `MODEL_EXPORT_ROOT`.
  - Includes current Ubuntu observed paths and Windows canonical paths.
  - States that `FILE_COMMON` data is outside the EA repo and must be found per OS.
  - States that generated artifacts are ignored and must be restored or regenerated.
- **Validation**:
  - `rg "MT5_ROOT|MT5_COMMON_FILES|DETERMINISTIC_RUNS_ROOT|MODEL_EXPORT_ROOT" docs/environment/mt5-agentic-workflows.md`

### Task 1.2: Document Context-Safe Agent Rules

- **Location**:
  - `docs/environment/mt5-agentic-workflows.md`
  - `AGENTS.md`
- **Description**: Add compact rules for low-context evidence capture.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Agents use `rtk` where useful.
  - Agents do not paste full compile logs, `query_debug.txt`, Parquet contents, or model JSON/TSV trees into chat.
  - Agents summarize only counts, final status lines, selected errors, and file paths.
  - Agents use `iconv` or equivalent only for the final UTF-16 MetaEditor log summary.
- **Validation**:
  - Static review of wording.
  - `rg "query_debug|Parquet|model JSON|UTF-16|rtk" docs/environment/mt5-agentic-workflows.md AGENTS.md`

### Task 1.3: Cross-Link Active Docs

- **Location**:
  - `README.md`
  - `AGENTS.md`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Point existing workflow docs to the Phase 4.5 runbook instead of duplicating OS-specific command blocks everywhere.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - README keeps brief examples but references the runbook for OS-specific paths.
  - AGENTS names the runbook as the environment source of truth.
  - ML tooling README points to the runbook for `Common\Files` path discovery.
- **Validation**:
  - `rg "mt5-agentic-workflows" README.md AGENTS.md tools/deterministic_signal_ml/README.md`

## Sprint 2: Compile Workflow Standardization

**Goal**: Make real compile and syntax-check workflows unambiguous across Windows and Ubuntu/Wine, with log parsing as the source of truth.
**Commit**: `chore: standardize mt5 compile workflow`
**Demo/Validation**:
- Ubuntu command regenerates `HFT_Grid_AI.ex5` and produces `0 errors, 0 warnings`.
- Windows command is documented with the same status interpretation.
- Wine exit code is treated as secondary when the MetaEditor log proves success.

### Task 2.1: Add Compile Command Matrix

- **Location**:
  - `docs/environment/mt5-agentic-workflows.md`
  - `README.md`
  - `AGENTS.md`
- **Description**: Replace ambiguous `/s /compile` guidance with two explicit modes: syntax check and real compile.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Real compile examples omit `/s`.
  - Syntax-check examples include `/s` and say no `.ex5` regeneration is expected.
  - Ubuntu examples use `wine`, `winepath`, and paths under the observed MT5 root.
  - Windows examples use PowerShell and the canonical MT5 root.
- **Validation**:
  - Static grep confirms real compile examples do not include `/s`.
  - Documentation cites that `/s` is syntax-check only.

### Task 2.2: Add Stdlib Compile Helper

- **Location**:
  - `tools/mt5/compile_mt5.py`
- **Description**: Add a tiny Python stdlib helper that runs MetaEditor compile on Windows or Ubuntu/Wine and parses the MetaEditor log for final status. This helper is the preferred agentic compile entrypoint for Phase 4.5 and later Codex work unless a human explicitly asks for direct MetaEditor commands.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Supports `--mt5-root`, `--entrypoint`, `--log`, `--mode compile|syntax`, and `--wine`.
  - Uses `/compile:<entrypoint>` without `/s` for `--mode compile`.
  - Uses `/compile:<entrypoint> /s` for `--mode syntax`.
  - Reads UTF-16 and UTF-8 logs safely.
  - Exits success only when the log contains `0 errors, 0 warnings`.
  - Reports the final useful status line and the log path only.
  - Does not run Strategy Tester.
- **Validation**:
  - `python3 -m py_compile tools/mt5/compile_mt5.py`
  - Ubuntu real compile command with `--wine`.
  - Confirm `.ex5` timestamp changes for real compile.

### Task 2.3: Record Compile Acceptance Evidence

- **Location**:
  - `docs/research/deterministic-signal-phase-4-5-environment-acceptance.md`
- **Description**: Capture compact evidence for the first accepted Ubuntu and later Windows compile runs.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Records OS, MT5 root, command shape, log path, final compile status, `.ex5` timestamp, and whether the process exit code differed from the log result.
  - Does not paste full logs.
  - Marks Windows evidence as pending until a human or agent validates on Windows.
- **Validation**:
  - Static review.
  - `rg "0 errors, 0 warnings|ex5|Ubuntu|Windows" docs/research/deterministic-signal-phase-4-5-environment-acceptance.md`

## Sprint 3: Common Files And Artifact Restoration Workflow

**Goal**: Make Phase 1-4 artifact restoration or regeneration deterministic without committing generated data.
**Commit**: `docs: define deterministic artifact restoration workflow`
**Demo/Validation**:
- An agent can determine whether `test_run_1`, `test_dataset_1`, `xgb_test_1`, and `xgb_test_1_export_v1` exist locally without reading large files.
- If absent, the documented workflow says exactly whether to restore from backup or regenerate from Strategy Tester exports.

### Task 3.1: Add Common Files Discovery Procedure

- **Location**:
  - `docs/environment/mt5-agentic-workflows.md`
  - `tools/deterministic_signal_ml/README.md`
- **Description**: Document how to locate `Common\Files` on Windows and Ubuntu/Wine.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Windows procedure starts from `%APPDATA%\MetaQuotes\Terminal\Common\Files`.
  - Ubuntu procedure checks the observed Wine path and falls back to searching `$HOME/.wine`, `$HOME/.mt5`, and any documented custom Wine prefix.
  - Procedure verifies `DeterministicSignalML\runs` exists before running dataset build commands.
  - Missing run folders are treated as a clear data blocker, not a code failure.
- **Validation**:
  - `rg "APPDATA|.wine|.mt5|DeterministicSignalML" docs/environment/mt5-agentic-workflows.md tools/deterministic_signal_ml/README.md`

### Task 3.2: Define Artifact Inventory Checks

- **Location**:
  - `docs/environment/mt5-agentic-workflows.md`
  - `docs/research/deterministic-signal-phase-4-5-environment-acceptance.md`
- **Description**: Add small commands for checking generated artifact presence, row counts, and validation status.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Checks cover:
    - `Common\Files\DeterministicSignalML\runs\test_run_1`
    - `artifacts/datasets/test_dataset_1`
    - `artifacts/models/xgb_test_1`
    - `artifacts/model_exports/xgb_test_1_export_v1`
  - Checks summarize file presence and sizes without dumping contents.
  - Parquet checks use DuckDB count queries only.
  - Model export checks use `model_artifact_validator.py`.
- **Validation**:
  - Static review.
  - If artifacts are present, run inventory commands and record compact results.
  - If artifacts are absent, record `missing` and the next regeneration command.

### Task 3.3: Standardize Python Environment Setup

- **Location**:
  - `tools/deterministic_signal_ml/README.md`
  - `docs/environment/mt5-agentic-workflows.md`
- **Description**: Add Ubuntu and Windows venv setup commands for Phase 2-4 tooling.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Ubuntu uses `python3.12 -m venv .venv` or `python3 -m venv .venv` when Python 3.12 is the active interpreter.
  - Windows uses `py -3.12 -m venv .venv`.
  - Both install `tools/deterministic_signal_ml/requirements.txt`.
  - Commands verify `duckdb`, `xgboost`, `sklearn`, and `numpy` versions without requiring pandas or pyarrow.
- **Validation**:
  - `python3 -m py_compile tools/deterministic_signal_ml/*.py`
  - Dependency import check in the active venv.

### Task 3.4: Regenerate Phase 2-4 Artifacts When Needed

- **Location**:
  - `docs/environment/mt5-agentic-workflows.md`
  - `docs/research/deterministic-signal-phase-4-5-environment-acceptance.md`
- **Description**: Document the exact command sequence for rebuilding dataset, training model, exporting artifact, and validating artifact from an available Phase 1 run.
- **Dependencies**: Tasks 3.1-3.3.
- **Acceptance Criteria**:
  - Commands cover:
    - `build_dataset.py --validate-only`
    - `build_dataset.py --overwrite`
    - `train_model.py --overwrite`
    - `export_model_artifact.py --overwrite`
    - `model_artifact_validator.py`
  - Commands are shown for Ubuntu and Windows path styles.
  - Acceptance evidence records row counts, model ID, export ID, threshold metadata, and parity status only.
  - If `test_run_1` is unavailable, the evidence doc states Phase 1 Strategy Tester export must be rerun manually.
- **Validation**:
  - Run the command sequence only if Phase 1 TSV inputs exist.
  - If inputs are missing, validate that the documented blocker is clear and actionable.

## Sprint 4: Phase 5 Readiness Gate

**Goal**: Produce a compact PASS/FAIL gate that determines whether MQL5 Shadow Inference planning can begin.
**Commit**: `docs: add phase 5 readiness gate`
**Demo/Validation**:
- A human or agent can answer whether Phase 5 is unblocked using one short evidence file.
- The gate protects trading safety and does not imply the model is production-ready.

### Task 4.1: Add Readiness Checklist

- **Location**:
  - `docs/research/deterministic-signal-phase-4-5-environment-acceptance.md`
  - `docs/plans/deterministic-signal-ml-roadmap.md`
- **Description**: Add a checklist for Phase 5 prerequisites.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - Checklist includes:
    - Ubuntu real compile clean.
    - Windows real compile clean or explicitly pending.
    - Common Files path confirmed.
    - Phase 1 run available or regeneration blocker documented.
    - Dataset build validated.
    - XGBoost training completed or restored.
    - Model export validated.
    - No generated artifacts committed.
    - No EA runtime inference added.
  - Roadmap links Phase 4.5 as a prerequisite for Phase 5.
- **Validation**:
  - Static review.
  - `git status --short --ignored` confirms generated outputs remain ignored.

### Task 4.2: Update Agent Handoff Notes

- **Location**:
  - `AGENTS.md`
  - `README.md`
  - `docs/environment/mt5-agentic-workflows.md`
- **Description**: Add final handoff rules for the next Codex session.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Next agents start from the runbook and acceptance doc, not full logs.
  - Next agents do not implement Phase 5 until the readiness gate is PASS or explicitly accepted as partial by a human.
  - The handoff names the exact export ID to load in Phase 5 when available.
- **Validation**:
  - Static review.
  - `rg "Phase 5|readiness|export ID|acceptance" AGENTS.md README.md docs/environment/mt5-agentic-workflows.md`

## Testing Strategy

- Documentation-only tasks use static review and focused `rg` checks.
- Compile tasks use MetaEditor compile and parse the MetaEditor log for `0 errors, 0 warnings`.
- Ubuntu/Wine compile success is determined by the log, not only by process exit code.
- Real compile must update `.ex5`; syntax check must not be treated as a build artifact.
- Python tooling validation uses `py_compile`, dependency import checks, dataset validator, trainer, exporter, and model artifact validator.
- Parquet validation uses row counts and schema summaries only.
- Large files are summarized by path, size, row count, final status, and selected error lines.
- No Strategy Tester automation is introduced. Phase 1 run regeneration remains human-in-the-loop unless a future plan explicitly changes that policy.

## Potential Risks And Gotchas

- **Wine exit code mismatch**: MetaEditor can return a nonzero process code even when the compile log says `0 errors, 0 warnings`. Mitigation: parse the log and record both process code and log result.
- **Syntax check mistaken for compile**: `/s /compile` can pass without regenerating `.ex5`. Mitigation: split syntax and real compile commands and verify `.ex5` timestamp for real compile.
- **Common Files path drift**: Windows, Wine, `.wine`, `.mt5`, and custom Wine prefixes can differ. Mitigation: document path discovery and require path confirmation before dataset commands.
- **Ignored artifacts disappear across machines**: datasets, models, exports, logs, and `.ex5` are intentionally ignored. Mitigation: record inventory and regeneration commands, not generated content.
- **Context blowup**: compile logs, `query_debug.txt`, Parquet data, model JSON, and tree TSVs can be large. Mitigation: record summaries only and keep raw artifacts on disk.
- **Data leakage into git/chat**: Phase 1 exports may contain sensitive run context. Mitigation: commit only docs and scripts; never paste private logs or full data rows.
- **Accidental Phase 5 creep**: It is tempting to load the model after export validation. Mitigation: Phase 4.5 explicitly stops at readiness gate and does not add MQL5 inference code.
- **Compile helper confused with a test harness**: A compile wrapper must not become CI or a custom MQL5 test system. Mitigation: helper only invokes MetaEditor compile/syntax and parses logs.

## Rollback Plan

- Revert Phase 4.5 commits in reverse sprint order.
- Remove `tools/mt5/compile_mt5.py` if the helper causes workflow confusion; keep documented direct commands if useful.
- Revert docs links to the previous README/AGENTS guidance if needed.
- Delete only generated local outputs under ignored paths when cleanup is required:
  - `logs/compile/*`
  - `.venv/`
  - `artifacts/datasets/*`
  - `artifacts/models/*`
  - `artifacts/model_exports/*`
- Do not delete MT5 `Common\Files` data unless a human explicitly requests cleanup of a specific run folder.
- Do not change EA trading logic, license behavior, broker guards, or Strategy Tester policy as part of rollback.

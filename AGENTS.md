# AGENTS Brief · HFT Grid AI EA

Short, current notes for contributors. Keep this file brief; deep details live in code.

---

## 1) Purpose + Entrypoint
- **Purpose**: MT5 grid EA that runs bullish/bearish sequences gated by multi-timeframe context filters and strict risk controls.
- **Entrypoint**: `HFT_Grid_AI.mq5`.

## 2) Functional Include Pipeline (single ordered chain)
The EA follows a functional, sequential include chain. Keep this order and avoid sibling includes.

```
services/Bcrypt.mqh
services/SecurityLicense.mqh
services/trading_tools.mqh
services/trading_management.mqh
services/trading_management_strategies.mqh
services/trading_signals.mqh
services/frontend.mqh
```

Rules:
- Only include lower layers (or core/utils/indicators); never include siblings.
- Aggregators are the single source of truth for include order.

## 3) One Source of Truth: merge `microservices/` into `services/`
Goal: one ordered services tree with clear ownership and include order.

Proposed mapping:
- `microservices/core/*` -> `services/core/*`
- `microservices/utils/*` -> `services/utils/*`
- `microservices/indicators/*` -> `services/indicators/*`
- `microservices/trading_signals/*` -> `services/trading_signals/*` (merge into existing)
- `microservices/frontend/*` -> `services/frontend/*` (merge into existing)

Minimal migration steps:
1. Move files into the mapped `services/*` folders (keep filenames).
2. Update `services/*.mqh` aggregators and any direct includes to the new paths.
3. Remove `microservices/` after the move (no shims).

## 4) Struct & Style Conventions
- Prefer explicit constructors with initializer lists; add a copy constructor when structs are passed/assigned.
- If a struct has a constructor, do not use aggregate initialization; add a default constructor when arrays are required.
- Style: 2-space indentation, snake_case variables, CamelCase functions, ALL_CAPS enums/constants. Avoid C++11 features (`auto`, lambdas, range-for).
- Keep the code functional and sequential: inputs -> indicators -> filters -> signal detection -> grid plan -> order lifecycle -> protection -> frontend.

## 5) Skill (Quant/Math + MQL5)
- **Skill path**: `/home/loldlm/.agents/skills/mql5-functional/SKILL.md`
- Scope: grid spacing math (ATR/points/channel midline), lot sizing modes, trailing/break-even logic, structure filters, and risk controls.
- Output style: concise, test-ready, and aligned to the include pipeline above.
- Uses Context7 MCP for MQL5 documentation.

## 6) Codex Config (source of truth)
Keep this in sync with `~/.codex/config.toml` (do not copy here).

## 7) Test Automation (`*_test.mq5`)
- Runner script: `scripts/run_mql5_tests.sh`.
- Scope: only `tests/*_test.mq5` (compiled individually with strict gate), then executed via one harness script (`tests/hft_grid_ai_tests_harness.mq5`).
- Compile gate is strict: warnings/errors fail the pipeline.
- Runtime gate is strict: harness must load/unload cleanly and emit per-test markers (`TEST_PASS` / `TEST_FAIL`); missing markers fail the affected test.
- Multi-symbol runtime is supported with `--symbols`, `--matrix-smoke`, and `--optional-symbol`.
- `--fast` skips per-test wrapper compile (harness compile remains strict) for quicker runtime smoke runs.
- `--compile-only` runs compile gates only and skips terminal runtime.
- Tests should be mock-data driven; chart context (`--symbol`/`--period`) is provisioned only to satisfy runtime startup.
- Runner keeps only `logs/test-runner/latest` (single latest report tree).
- MT5 terminal must be closed before runtime-enabled runs; MT5 cannot queue startup-script runs into an already-open instance for the same install root.
- Keep test logic in `tests/harness/cases/*_test_case.mqh`; keep `tests/*_test.mq5` as thin wrappers for per-test compile visibility.
- Recommended workflow (two runs):
  1. Compile gate only: `./scripts/run_mql5_tests.sh --compile-only`
  2. Fast symbol smoke: `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`
- Review only:
  - `logs/test-runner/latest/summary.log`
  - `logs/test-runner/latest/compile/*.metaeditor.log`
  - `logs/test-runner/latest/runtime/*.terminal.log`
  - `logs/test-runner/latest/runtime/*.mql.log`

## 8) Canonical Repo Placement
- Preferred layout: `<MT5_ROOT>/MQL5/Experts/HFT_Grid_AI` (and other projects in `<MT5_ROOT>/MQL5/Experts/*`).
- Keep `terminal64.exe` and `MetaEditor64.exe` in `<MT5_ROOT>`, not inside individual EA repos.
- `scripts/run_mql5_tests.sh` auto-detects `<MT5_ROOT>` from this layout; otherwise pass `--mt5-root` (or `MT5_ROOT` env).

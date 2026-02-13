# HFT Grid AI EA

**Version:** 1.10
**Platform:** MetaTrader 5 (MQL5)
**Contact:** @loldlm · https://t.me/TradingAlgoritmicoFx

HFT Grid AI is a MetaTrader 5 Expert Advisor that runs bullish/bearish grid sequences gated by multi-timeframe context filters and strict risk controls.

**Entrypoint:** `HFT_Grid_AI.mq5`

## Quick Start
1. Open `HFT_Grid_AI.mq5` in MetaEditor and compile.
2. Attach the EA to a chart or run it in Strategy Tester (Every tick based on real ticks).
3. Adjust inputs in MT5 as needed.

## Candle Structure Filter
- Input group: `Candle Structure Filter`.
- Inputs: `Candle_Timeframe` (default `PERIOD_M15`), `Candle_Strategy_Type` (default `OFF_CANDLE_STRUCTURE`), `Candle_Strategy_Shift` (default `0`), `Candle_Strategy_Depth` (default `1`, runtime clamp to `1` when `<=0`).
- Strategy modes:
  - `SHRINKED`: `high_current <= high_past` and `low_current >= low_past`
  - `EXPANDED`: `high_current > high_past` and `low_current < low_past`
  - `BULLISH`: `high_current > high_past` and `low_current > low_past`
  - `BEARISH`: `high_current < high_past` and `low_current < low_past`
- Behavior: enabled modes are evaluated as a hard pre-entry gate; filter failure blocks signal creation (fail-closed).

## Automated `*_test.mq5` Runner
Use the project runner to compile and execute script-based tests in `tests/*_test.mq5`:

```bash
./scripts/run_mql5_tests.sh
```

What it enforces:
- Compile gate is strict: any compiler `error` or `warning` fails the test.
- Runtime runs once through `tests/hft_grid_ai_tests_harness.mq5` after compile passes.
- Runtime gate is strict: harness must load/unload and emit per-test `TEST_PASS`/`TEST_FAIL` markers; missing markers fail the test.
- Tests are expected to be mock-data driven (no broker/chart history dependency).

Test file structure:
- `tests/*_test.mq5`: thin wrappers (compile visibility per test).
- `tests/harness/cases/*_test_case.mqh`: test case logic.
- `tests/hft_grid_ai_tests_harness.mq5`: single runtime orchestrator.

Cross-platform usage:
- Windows (Git Bash/MSYS/Cygwin, native MT5 binaries): `./scripts/run_mql5_tests.sh --mt5-root "C:/path/to/mt5"`
- Ubuntu 22.04+ (Wine): `./scripts/run_mql5_tests.sh --mt5-root "/path/to/mt5/root"`

Preferred layout:
- Place this repo at `<MT5_ROOT>/MQL5/Experts/HFT_Grid_AI`.
- Keep `terminal64.exe` and `MetaEditor64.exe` at `<MT5_ROOT>` (shared binaries for all `Experts/*` projects).

Options:
- `--symbol` and `--period` set runtime chart context for startup (defaults `EURUSD`/`M1`).
- `--symbols CSV` runs harness on multiple symbols (for example: `EURUSD,XAUUSD,US30`).
- `--matrix-smoke` expands to `EURUSD,XAUUSD,US30`.
- `--optional-symbol` appends one extra symbol (for example: `USDJPY` or `BTCUSD`).
- `--fast` skips per-test wrapper compile and keeps harness compile strict.
- `--compile-only` runs only compile gates and skips terminal runtime.
- `--report-dir` changes report root (default `logs/test-runner`).

Recommended workflow (two runs):
1. Compile gate only:
   `./scripts/run_mql5_tests.sh --compile-only`
2. Fast multi-symbol runtime smoke:
   `./scripts/run_mql5_tests.sh --matrix-smoke --optional-symbol USDJPY --fast`

Outputs:
- `logs/test-runner/latest/summary.log`
- `logs/test-runner/latest/compile/*.metaeditor.log`
- `logs/test-runner/latest/compile/*.metaeditor.raw.log`
- `logs/test-runner/latest/runtime/*.log`

Note:
- The runner intentionally has no timeout.
- MT5 terminal must be closed before runtime-enabled runs. MT5 is single-instance per installation directory, and command-line startup cannot queue script runs into an already-open terminal.
- `--compile-only` does not launch the terminal and can be used with an already-open MT5 session.

## Project Map (brief)
- `services/` holds the ordered include pipeline (tools -> management -> strategies -> signals -> frontend).
- `AGENTS.md` is the short architectural brief and source of truth for contributor rules.

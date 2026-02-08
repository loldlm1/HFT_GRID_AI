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

## Automated `*_test.mq5` Runner
Use the project runner to compile and execute script-based tests in `tests/*_test.mq5`:

```bash
./scripts/run_mql5_tests.sh
```

What it enforces:
- Compile gate is strict: any compiler `error` or `warning` fails the test.
- Runtime gate is strict: script must load, unload, emit `PASS`, and must not emit `FAIL`.
- Tests are expected to be mock-data driven (no broker/chart history dependency).

Cross-platform usage:
- Windows (Git Bash/MSYS/Cygwin, native MT5 binaries): `./scripts/run_mql5_tests.sh --mt5-root "C:/path/to/mt5"`
- Ubuntu 22.04+ (Wine): `./scripts/run_mql5_tests.sh --mt5-root "/path/to/mt5/root"`

Preferred layout:
- Place this repo at `<MT5_ROOT>/MQL5/Experts/HFT_Grid_AI`.
- Keep `terminal64.exe` and `MetaEditor64.exe` at `<MT5_ROOT>` (shared binaries for all `Experts/*` projects).

Options:
- `--symbol` and `--period` set runtime chart context for startup (defaults `EURUSD`/`M1`).
- `--report-dir` changes report root (default `logs/test-runner`).

Outputs:
- `logs/test-runner/latest/report.md`
- `logs/test-runner/latest/report.json`
- `logs/test-runner/latest/compile/*.utf8.log`
- `logs/test-runner/latest/runtime/*.segment.log`
- old timestamped run folders are pruned by the runner

Note:
- The runner intentionally has no timeout.
- MT5 terminal must be closed before running tests. MT5 is single-instance per installation directory, and command-line startup cannot queue script runs into an already-open terminal.
- If interrupted (`Ctrl+C`), it writes a partial report for completed tests.

## Project Map (brief)
- `services/` holds the ordered include pipeline (tools -> management -> strategies -> signals -> frontend).
- `AGENTS.md` is the short architectural brief and source of truth for contributor rules.

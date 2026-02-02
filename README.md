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

## Project Map (brief)
- `services/` holds the ordered include pipeline (tools -> management -> strategies -> signals -> frontend).
- `AGENTS.md` is the short architectural brief and source of truth for contributor rules.

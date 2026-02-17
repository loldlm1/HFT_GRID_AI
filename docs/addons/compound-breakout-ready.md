# Addon Guide: Structure Compound Context - Breakout Ready

## SKU
- `addon_compound_breakout_ready`

## Included modes
- `COMPOUND_MODE_BREAKOUT_READY_BUY`
- `COMPOUND_MODE_BREAKOUT_READY_SELL`

One purchase includes both sides (BUY and SELL).

## Inputs related to this addon
- `Base_Structure_Compound_Filter`
- `Base_Fresh_Structure_Time`

## Entitlement trigger rule
Addon is required when `Base_Structure_Compound_Filter` is one of the Breakout Ready modes.

## How this pattern builds structure
1. It detects a compressed range where price repeatedly reacts between clear boundaries.
2. It measures pressure buildup as price retests one side of the range.
3. It validates breakout by acceptance outside the range, not just a single spike.
4. It follows the breakout side while structure remains aligned and fresh.

## Canonical structure sequence (oldest -> newest)
Internal matcher order is `first -> fourth` (newest -> oldest).

- Buy mode (`COMPOUND_MODE_BREAKOUT_READY_BUY`):
  `[4] Higher Low -> [3] Lower High -> [2] Higher Low -> [1] Lower High`
- Sell mode (`COMPOUND_MODE_BREAKOUT_READY_SELL`):
  `[4] Lower High -> [3] Higher Low -> [2] Lower High -> [1] Higher Low`

## Recommended setups
### Setup A: Confirmed breakout entries (recommended)
- `Base_Structure_Compound_Filter = COMPOUND_MODE_BREAKOUT_READY_BUY` for bullish breakouts
- `Base_Structure_Compound_Filter = COMPOUND_MODE_BREAKOUT_READY_SELL` for bearish breakouts
- `Base_Fresh_Structure_Time = true`

### Setup B: Opportunistic breakout mode
- Keep Breakout Ready mode selected
- `Base_Fresh_Structure_Time = false`

## If addon is missing
- EA startup is blocked when Breakout Ready mode is selected.

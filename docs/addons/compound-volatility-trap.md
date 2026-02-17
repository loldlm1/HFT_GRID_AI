# Addon Guide: Structure Compound Context - Volatility Trap

## SKU
- `addon_compound_volatility_trap`

## Included modes
- `COMPOUND_MODE_VOLATILITY_TRAP_BUY`
- `COMPOUND_MODE_VOLATILITY_TRAP_SELL`

One purchase includes both sides (BUY and SELL).

## Inputs related to this addon
- `Base_Structure_Compound_Filter`
- `Base_Fresh_Structure_Time`

## Entitlement trigger rule
Addon is required when `Base_Structure_Compound_Filter` is one of the Volatility Trap modes.

## How this pattern builds structure
1. It detects unstable volatility and possible false breakout behavior.
2. It checks if price quickly returns inside the previous structure range.
3. It confirms the trap by failure to continue in the false-break direction.
4. It triggers in the opposite direction once structure stabilizes again.

## Canonical structure sequence (oldest -> newest)
Internal matcher order is `first -> fourth` (newest -> oldest).

- Buy mode (`COMPOUND_MODE_VOLATILITY_TRAP_BUY`):
  `[4] Higher High -> [3] Lower Low -> [2] Higher High -> [1] Lower Low`
- Sell mode (`COMPOUND_MODE_VOLATILITY_TRAP_SELL`):
  `[4] Lower Low -> [3] Higher High -> [2] Lower Low -> [1] Higher High`

## Recommended setups
### Setup A: Defensive volatility filter (recommended)
- `Base_Structure_Compound_Filter = COMPOUND_MODE_VOLATILITY_TRAP_BUY` for defensive long mode
- `Base_Structure_Compound_Filter = COMPOUND_MODE_VOLATILITY_TRAP_SELL` for defensive short mode
- `Base_Fresh_Structure_Time = true`

### Setup B: Flexible trap mode
- Keep Volatility Trap mode selected
- `Base_Fresh_Structure_Time = false`

## If addon is missing
- EA startup is blocked when Volatility Trap mode is selected.

# Addon Guide: Structure Compound Context - Pullback Continue

## SKU
- `addon_compound_pullback_continue`

## Included modes
- `COMPOUND_MODE_PULLBACK_CONTINUE_BUY`
- `COMPOUND_MODE_PULLBACK_CONTINUE_SELL`

One purchase includes both sides (BUY and SELL).

## Inputs related to this addon
- `Base_Structure_Compound_Filter`
- `Base_Fresh_Structure_Time`

## Entitlement trigger rule
Addon is required when `Base_Structure_Compound_Filter` is one of the Pullback Continue modes.

## How this pattern builds structure
1. It identifies a strong impulse move in one direction.
2. It maps a pullback area where price can retrace without invalidating continuation.
3. It checks that the pullback holds structure (no real trend break).
4. It enters when momentum rotates back to the original direction.

## Canonical structure sequence (oldest -> newest)
Internal matcher order is `first -> fourth` (newest -> oldest).

- Buy mode (`COMPOUND_MODE_PULLBACK_CONTINUE_BUY`):
  `[4] Lower High -> [3] Lower Low -> [2] Higher High -> [1] Higher Low`
- Sell mode (`COMPOUND_MODE_PULLBACK_CONTINUE_SELL`):
  `[4] Higher Low -> [3] Higher High -> [2] Lower Low -> [1] Lower High`

## Recommended setups
### Setup A: Continuation after pullback (recommended)
- `Base_Structure_Compound_Filter = COMPOUND_MODE_PULLBACK_CONTINUE_BUY` for long continuation
- `Base_Structure_Compound_Filter = COMPOUND_MODE_PULLBACK_CONTINUE_SELL` for short continuation
- `Base_Fresh_Structure_Time = true`

### Setup B: Higher frequency continuation
- Keep Pullback Continue mode selected
- `Base_Fresh_Structure_Time = false`

## If addon is missing
- EA startup is blocked when Pullback Continue mode is selected.

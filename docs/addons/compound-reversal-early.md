# Addon Guide: Structure Compound Context - Reversal Early

## SKU
- `addon_compound_reversal_early`

## Included modes
- `COMPOUND_MODE_REVERSAL_EARLY_BUY`
- `COMPOUND_MODE_REVERSAL_EARLY_SELL`

One purchase includes both sides (BUY and SELL).

## Inputs related to this addon
- `Base_Structure_Compound_Filter`
- `Base_Fresh_Structure_Time`

## Entitlement trigger rule
Addon is required when `Base_Structure_Compound_Filter` is one of the Reversal Early modes.

## How this pattern builds structure
1. It starts from a trend that shows exhaustion (weaker pushes or repeated failed extensions).
2. It detects the first meaningful structure break against the previous direction.
3. It looks for the first opposite swing sequence to confirm transition.
4. It triggers earlier than classic reversal models, so risk control should stay tighter.

## Canonical structure sequence (oldest -> newest)
Internal matcher order is `first -> fourth` (newest -> oldest).

- Buy mode (`COMPOUND_MODE_REVERSAL_EARLY_BUY`):
  `[4] Lower High -> [3] Lower Low -> [2] Lower High -> [1] Higher Low`
- Sell mode (`COMPOUND_MODE_REVERSAL_EARLY_SELL`):
  `[4] Higher Low -> [3] Higher High -> [2] Higher Low -> [1] Lower High`

## Recommended setups
### Setup A: Early reversal with freshness gate (recommended)
- `Base_Structure_Compound_Filter = COMPOUND_MODE_REVERSAL_EARLY_BUY` for bullish reversals
- `Base_Structure_Compound_Filter = COMPOUND_MODE_REVERSAL_EARLY_SELL` for bearish reversals
- `Base_Fresh_Structure_Time = true`

### Setup B: Reversal expansion mode
- Keep Reversal Early mode selected
- `Base_Fresh_Structure_Time = false`

## If addon is missing
- EA startup is blocked when Reversal Early mode is selected.

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

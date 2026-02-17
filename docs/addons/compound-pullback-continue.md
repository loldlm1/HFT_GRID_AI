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

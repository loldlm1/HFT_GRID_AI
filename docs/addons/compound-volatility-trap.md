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

# Addon Guide: Structure Compound Context - Trend Ride

## SKU
- `addon_compound_trend_ride`

## Included modes
- `COMPOUND_MODE_TREND_RIDE_BUY`
- `COMPOUND_MODE_TREND_RIDE_SELL`

One purchase includes both sides (BUY and SELL).

## Inputs related to this addon
- `Base_Structure_Compound_Filter`
- `Base_Fresh_Structure_Time`

## Entitlement trigger rule
Addon is required when `Base_Structure_Compound_Filter` is one of the Trend Ride modes.

## Recommended setups
### Setup A: Trend continuation (recommended)
- `Base_Structure_Compound_Filter = COMPOUND_MODE_TREND_RIDE_BUY` for long trend systems
- `Base_Structure_Compound_Filter = COMPOUND_MODE_TREND_RIDE_SELL` for short trend systems
- `Base_Fresh_Structure_Time = true`

### Setup B: More entries, less strict
- Keep Trend Ride mode selected
- `Base_Fresh_Structure_Time = false`

## If addon is missing
- EA startup is blocked when Trend Ride mode is selected.

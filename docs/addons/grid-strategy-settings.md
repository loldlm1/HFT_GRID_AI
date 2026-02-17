# Addon: Grid Strategy Settings

## SKU
- `addon_grid_strategy_config`

## Unlocks
- Advanced grid shape and depth controls.

## Related inputs (addon-locked)
- `Grid_Exponential_Multiplier`
- `Grid_Level_Position_Start`
- `Grid_Level_Stop_Limit`

## Base-allowed inputs (no addon needed)
- `Base_Strategy_Type`
- `Points_Range_Setup`

## Addon required when
- Any addon-locked input deviates from base defaults:
  - `Grid_Exponential_Multiplier != 1.0`
  - `Grid_Level_Position_Start != 0`
  - `Grid_Level_Stop_Limit != 1`

## Missing entitlement behavior
- EA startup is blocked if locked values are requested without entitlement.
- Runtime safety lock enforces `Grid_Level_Stop_Limit = 1` when Grid addon is not entitled.

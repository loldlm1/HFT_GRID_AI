# Addon Guide: Grid Strategy Settings

## SKU
- `addon_grid_strategy_config`

## What this addon unlocks
- Advanced grid shape and depth controls.

## Addon-locked inputs
- `Grid_Exponential_Multiplier`
- `Grid_Level_Position_Start`
- `Grid_Level_Stop_Limit`

## Base-allowed inputs (no addon required)
- `Base_Strategy_Type`
- `Points_Range_Setup`

## Entitlement trigger rule
Addon is required when any locked input deviates from defaults.

Locked defaults:
- `Grid_Exponential_Multiplier = 1.0`
- `Grid_Level_Position_Start = 0`
- `Grid_Level_Stop_Limit = 1`

## Recommended setups
### Setup A: Controlled expansion (recommended)
- `Grid_Exponential_Multiplier = 1.20`
- `Grid_Level_Position_Start = 0`
- `Grid_Level_Stop_Limit = 3`

### Setup B: Moderate pullback grid
- `Grid_Exponential_Multiplier = 1.35`
- `Grid_Level_Position_Start = 0`
- `Grid_Level_Stop_Limit = 4`

### Setup C: Deep grid (higher risk)
- `Grid_Exponential_Multiplier = 1.50`
- `Grid_Level_Position_Start = 1`
- `Grid_Level_Stop_Limit = 6`

## If addon is missing
- Requesting non-default locked values blocks startup.
- Runtime safety lock enforces `Grid_Level_Stop_Limit = 1`.

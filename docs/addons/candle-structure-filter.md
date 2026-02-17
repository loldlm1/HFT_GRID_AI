# Addon Guide: Candle Structure Filter

## SKU
- `addon_candle_structure`

## What this addon unlocks
- Pre-entry candle-structure filtering to tighten signal quality.

## Inputs in this group
- `Candle_Timeframe`
- `Candle_Strategy_Type`
- `Candle_Strategy_Shift`
- `Candle_Strategy_Depth`

## Entitlement trigger rule
Addon is required when `Candle_Strategy_Type != OFF_CANDLE_STRUCTURE`.

## Recommended setups
### Setup A: Conservative filter (recommended)
- `Candle_Timeframe = PERIOD_M15`
- `Candle_Strategy_Type = SHRINKED_CANDLE_STRUCTURE`
- `Candle_Strategy_Shift = 1`
- `Candle_Strategy_Depth = 1`

### Setup B: Momentum acceptance
- `Candle_Timeframe = PERIOD_M5`
- `Candle_Strategy_Type = EXPANDED_CANDLE_STRUCTURE`
- `Candle_Strategy_Shift = 0`
- `Candle_Strategy_Depth = 1`

### Setup C: Directional bias filter
- For long-only bias: `Candle_Strategy_Type = BULLISH_CANDLE_STRUCTURE`
- For short-only bias: `Candle_Strategy_Type = BEARISH_CANDLE_STRUCTURE`
- Keep `Candle_Timeframe = PERIOD_M15`, `Candle_Strategy_Shift = 0`, `Candle_Strategy_Depth = 1`

## If addon is missing
- EA startup is blocked when a non-OFF candle mode is selected.

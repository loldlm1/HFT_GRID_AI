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

## How this pattern builds structure
1. It first confirms direction from swing sequence:
   - bullish: higher highs + higher lows
   - bearish: lower lows + lower highs
2. It waits for a controlled pullback that does not break the active trend structure.
3. It triggers only when price resumes in the same direction, signaling continuation.
4. If `Base_Fresh_Structure_Time = true`, only recent structures are accepted.

## Canonical structure sequence (oldest -> newest)
Internal matcher order is `first -> fourth` (newest -> oldest).

- Buy mode (`COMPOUND_MODE_TREND_RIDE_BUY`):
  `[4] Higher High -> [3] Higher Low -> [2] Higher High -> [1] Higher Low`
- Sell mode (`COMPOUND_MODE_TREND_RIDE_SELL`):
  `[4] Lower Low -> [3] Lower High -> [2] Lower Low -> [1] Lower High`

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

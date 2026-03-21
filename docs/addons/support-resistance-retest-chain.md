# Addon Guide: Support Resistance Retest Chain

## SKU
- `addon_support_resistance_retest_chain`

## What this addon unlocks
- A hard pre-entry structure gate that validates the resolved entry candidate against recursive support/resistance retest confluence.

## Inputs in this group
- `Support_Resistance_Retest_Chain_Enabled`
- `Support_Resistance_Retest_Chain_Count`
- `Support_Resistance_Retest_Chain_Range_Percent`

## How it works
- The EA resolves the real structure entry candidate first.
- `LEVELS_AS_LIMITS`: the pending limit entry price is checked.
- `LEVEL_AS_ZONE`: the confirmed market-entry price is checked.
- That price must sit inside the most recent historical support/resistance zone.
- The chain then walks backward through older alternating extrema and rebuilds a local zone at each hop.
- If the chain breaks before the requested count is satisfied, the signal is rejected.

## Entitlement trigger rule
Addon is required when `Support_Resistance_Retest_Chain_Enabled = true`.

## Recommended setups
### Setup A: Current-touch confirmation (recommended)
- `Support_Resistance_Retest_Chain_Enabled = true`
- `Support_Resistance_Retest_Chain_Count = 1`
- `Support_Resistance_Retest_Chain_Range_Percent = 10.0`

### Setup B: Moderate confluence filter
- `Support_Resistance_Retest_Chain_Enabled = true`
- `Support_Resistance_Retest_Chain_Count = 3`
- `Support_Resistance_Retest_Chain_Range_Percent = 10.0`

### Setup C: Tighter historical confluence
- `Support_Resistance_Retest_Chain_Enabled = true`
- `Support_Resistance_Retest_Chain_Count = 3`
- `Support_Resistance_Retest_Chain_Range_Percent = 6.0`

## Role-reversal note
- Older peaks can validate current bullish support if price retests the old resistance area as support.
- Older bottoms can validate current bearish resistance if price retests the old support area as resistance.

## If addon is missing
- EA startup is blocked when `Support_Resistance_Retest_Chain_Enabled = true`.

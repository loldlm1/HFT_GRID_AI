# Addon Guide: Structure Trailing

## SKU
- `addon_structure_trailing`

## What this addon unlocks
- Per-signal trailing management driven by closed stochastic structure extrema.
- Local trailing stop and trailing TP handling without broker-side server SL/TP placement.
- Optional TP-side partial closes on each new qualifying trailing TP event.

## Inputs in this group
- `Trailing_Structure_Mode`
- `Trailing_TP_Close_Percent`

## Trailing modes
- `TRAILING_OFF`: addon disabled.
- `TRAILING_BY_STRUCTURE`: trail by closed structure extrema only.
- `TRAILING_BY_STRUCTURE_TP_BE`: same trailing path, but stop and TP candidates must preserve the TP/BE guard rules.

## How it works
- The addon only starts after the signal has executed its first broker position.
- It never uses `os_market_structures[0]`; only closed extrema are valid.
- Bullish:
  - new closed bottoms can advance the trailing SL upward
  - new closed peaks can create the next trailing TP upward
- Bearish:
  - new closed peaks can advance the trailing SL downward
  - new closed bottoms can create the next trailing TP downward
- Each consumed TP/SL extremum timestamp is tracked, so the same structure cannot trigger the same action twice.

## TP partial-close rule
- `0`: do not take TP partials. The full signal stays open until the local trailing SL closes it.
- `100`: close the whole remaining signal when the trailing TP is hit.
- Intermediate values:
  - close that percent of the original signal exposure on each new TP event
  - example: `25` means up to four TP hits, with the last hit closing the remaining signal volume

## TP/BE protection rule
- In `TRAILING_BY_STRUCTURE_TP_BE` mode:
  - new SL candidates are accepted only if total signal outcome would still be at least break-even after including already-realized partial profits
  - new TP candidates are accepted only if they stay at or beyond the protected TP anchor

## Entitlement trigger rule
- Addon is required when `Trailing_Structure_Mode != TRAILING_OFF`.

## If addon is missing
- EA startup is blocked when a trailing mode is selected outside Strategy Tester.

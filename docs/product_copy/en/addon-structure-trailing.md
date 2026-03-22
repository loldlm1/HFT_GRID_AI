# Addon Product Copy - Structure Trailing

## Product
- Name: `Structure Trailing`
- Type: `Addon`
- SKU: `addon_structure_trailing`

## Short Copy Block
`Unlocks structure-driven trailing so each signal can protect gains and scale out with local TP partials as the market confirms new highs or lows.`

## Medium Copy Block
`This addon adds an adaptive trailing layer powered by closed stochastic market structure. Instead of using fixed server-side SL/TP orders, the EA follows confirmed peaks and bottoms locally and updates the active signal protection as structure evolves.`

`For non-traders: this means the strategy can "move protection with the market" and optionally take profits in slices instead of exiting the whole signal at once.`

## Inputs Explained (Plain Language)
- `Trailing_Structure_Mode`: enables structure trailing and selects the TP/BE protected variant when needed.
- `Trailing_TP_Close_Percent`: percent of the original signal size to close on each new qualifying TP event.

## Recommended Starter Setup
- `Trailing_Structure_Mode = TRAILING_BY_STRUCTURE`
- `Trailing_TP_Close_Percent = 25.0`

## Access Rule
- Entitlement is required when `Trailing_Structure_Mode != TRAILING_OFF`.

## If Addon Is Missing
- Startup is blocked when a trailing mode is selected.
- The EA does not fall back to server-side SL/TP placement.

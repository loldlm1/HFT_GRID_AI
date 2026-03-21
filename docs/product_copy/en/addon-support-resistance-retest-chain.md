# Addon Product Copy - Support Resistance Retest Chain

## Product
- Name: `Support Resistance Retest Chain`
- Type: `Addon`
- SKU: `addon_support_resistance_retest_chain`

## Short Copy Block
`Add a recursive support/resistance confirmation layer so entries only trigger when the active structure retests meaningful historical zones.` 

## Medium Copy Block
`This addon adds a hard pre-entry validation layer based on support/resistance retest chains. The EA first resolves the real structure entry candidate, then checks whether that price sits inside the latest valid historical zone and whether older extrema confirm the same area recursively.` 

`For non-traders: this is a confluence gate. The EA asks, "is this entry retesting an area the market has respected before?" If the answer is no, the trade is skipped.` 

## Inputs Explained (Plain Language)
- `Support_Resistance_Retest_Chain_Enabled`: turns the addon on or off.
- `Support_Resistance_Retest_Chain_Count`: required chain depth for confirmation.
- `Support_Resistance_Retest_Chain_Range_Percent`: width of the support/resistance zone around each historical extremum.

## Recommended Starter Setup
- `Support_Resistance_Retest_Chain_Enabled = true`
- `Support_Resistance_Retest_Chain_Count = 3`
- `Support_Resistance_Retest_Chain_Range_Percent = 10.0`

## Access Rule
- Entitlement required when `Support_Resistance_Retest_Chain_Enabled = true`.

## If Addon Is Missing
- EA blocks startup when the addon is enabled.

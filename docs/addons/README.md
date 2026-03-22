# HFT Grid AI Addons Guide

This folder contains product-ready guides for the base EA and each paid addon.

## Files
- `base.md`
- `session-time-filter.md`
- `grid-strategy-settings.md`
- `candle-structure-filter.md`
- `support-resistance-retest-chain.md`
- `structure-trailing.md`
- `compound-trend-ride.md`
- `compound-pullback-continue.md`
- `compound-reversal-early.md`
- `compound-breakout-ready.md`
- `compound-volatility-trap.md`
- `backend-entitlements-contract.md`
- `input-migration-2026-02-17.md`

## Addon matrix
- Time Filter Session Manager: `addon_session_time_filter`
- Grid Strategy Settings: `addon_grid_strategy_config`
- Candle Structure Filter: `addon_candle_structure`
- Support Resistance Retest Chain: `addon_support_resistance_retest_chain`
- Structure Trailing: `addon_structure_trailing`
- Structure Compound Context (Trend Ride): `addon_compound_trend_ride`
- Structure Compound Context (Pullback Continue): `addon_compound_pullback_continue`
- Structure Compound Context (Reversal Early): `addon_compound_reversal_early`
- Structure Compound Context (Breakout Ready): `addon_compound_breakout_ready`
- Structure Compound Context (Volatility Trap): `addon_compound_volatility_trap`

## Runtime policy summary
- Inputs are always visible in MT5 because input groups are compile-time declarations.
- Addon usage is validated at runtime against online license entitlements.
- Missing required addon entitlement blocks EA startup with a chart message.
- Live and Demo refresh license state every 24h (`86400` seconds) and remove EA on refresh failure.
- Strategy Tester still requires a valid decryptable key and future expiry timestamp, but addon entitlement checks are bypassed.

## Important compound rule
- Any compound family purchase includes both BUY and SELL modes from that family.
- If `Base_Fresh_Structure_Time = true` while `Base_Structure_Compound_Filter = COMPOUND_MODE_OFF`, the EA requires at least one compound family entitlement.

# HFT Grid AI Addons Guide

This folder contains product-ready input guides for the base EA and each paid addon.

## Files
- `base.md`
- `session-time-filter.md`
- `grid-strategy-settings.md`
- `candle-structure-filter.md`
- `compound-trend-ride.md`
- `compound-pullback-continue.md`
- `compound-reversal-early.md`
- `compound-breakout-ready.md`
- `compound-volatility-trap.md`
- `input-migration-2026-02-17.md`

## Runtime policy summary
- Inputs are always visible in MT5 because input groups are compile-time declarations.
- Addon usage is validated at runtime against the license entitlements.
- Missing required addon entitlement blocks EA startup with a chart message.
- Live/Demo performs daily license re-validation (24h interval) and removes the EA if validation fails.
- Strategy Tester still requires a valid decryptable key and unexpired timestamp, but addon checks are bypassed.

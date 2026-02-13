# Structure Compound Modes Implementation Plan

Date: 2026-02-13  
Status: Draft plan for future coding task

## 1) Goal

Implement a single, robust structure filter input using `TrendStructureCompoundModes`, with marketing-friendly mode names mapped to explicit Pattern Catalog templates.

Required behavior:
1. One input only for compound filtering.
2. Full Pattern Catalog coverage.
3. Deterministic matching (no extra profile/EQ/parity inputs).
4. Fail-closed on missing/invalid structure data.
5. Preserve current `Structure_Trigger_Entry` runtime behavior.

## 2) Scope

In scope:
1. Add `TrendStructureCompoundModes` enum in runtime code.
2. Add `Base_Structure_Compound_Filter` input.
3. Add compound template resolver + matcher.
4. Integrate matcher into signal filter flow.
5. Add tests and docs for mode coverage and entry behavior compatibility.

Out of scope:
1. Replacing `Structure_Trigger_Entry` mechanics.
2. Adding new risk modules.
3. Deleting legacy 4-slot inputs immediately.

## 3) Phase Plan

### Phase 1: Enum + Input Foundation

Files:
1. `services/core/enums.mqh`
2. `services/trading_management/ea_inputs.mqh`

Tasks:
1. Add `TrendStructureCompoundModes` enum with marketing names mapped to Pattern Catalog IDs.
2. Add input:
   `input TrendStructureCompoundModes Base_Structure_Compound_Filter = COMPOUND_MODE_OFF;`
3. Keep legacy 4-slot inputs unchanged for compatibility.

Acceptance:
1. Headless compile passes with strict gate.
2. No runtime behavior change when compound mode is `OFF`.

### Phase 2: Pattern Spec Layer

Files:
1. `services/trading_signals/market_signal_filters.mqh`
2. New helper file (recommended): `services/trading_signals/structure_compound_modes.mqh`
3. `services/trading_signals.mqh` (include chain registration)

Tasks:
1. Define per-mode expected templates (`S1..S4`) from catalog.
2. Encode both parity variants internally (no user toggle).
3. Define fixed `EQ` semantics:
   - required where template has `EQ`
   - rejected where template expects non-`EQ`
4. Build matcher helpers that read from existing structure snapshot fields.

Acceptance:
1. Every mode resolves to a valid template set.
2. Missing/invalid snapshot fails closed.

### Phase 3: Filter Integration

Files:
1. `services/trading_signals/market_signal_filters.mqh`

Tasks:
1. In structure filter evaluation path:
   - if `Base_Structure_Compound_Filter != COMPOUND_MODE_OFF`, evaluate compound matcher
   - bypass legacy `Base_First...Base_Fourth` slot checks in this branch
2. If compound mode is `OFF`, keep existing legacy behavior.

Acceptance:
1. Compound-on path uses only compound matcher result.
2. Compound-off path remains backward compatible.

### Phase 4: Test Matrix

Files:
1. `tests/harness/cases/` new compound matcher test cases
2. `tests/*_test.mq5` thin wrapper(s)
3. `tests/hft_grid_ai_tests_harness.mq5` (registration)

Required tests:
1. Exact match pass for each compound mode with both parity variants.
2. One-slot mismatch fail for each mode.
3. `EQ` slot enforcement tests.
4. Insufficient depth (`<4`) fails closed.
5. Compatibility test: compound `OFF` behaves exactly as current legacy path.

Acceptance:
1. Compile gate strict pass.
2. Harness emits `TEST_PASS`/`TEST_FAIL` markers for all added tests.

### Phase 5: Entry Behavior Compatibility Checks

Files:
1. `services/trading_signals/market_signal_filters.mqh`
2. Existing structure-fibonacci test files (extend as needed)
3. `docs/research/2026-02-13-base-context-4-structure-pattern-catalog.md`

Tasks:
1. Re-validate current behavior for:
   - `LEVELS_AS_LIMITS` (`bar_index=1`, strict band, boundary entry logic)
   - `LEVEL_AS_ZONE` (`bar_index=0`, strict band, close-reference behavior)
2. Verify deep-level trigger constraints (`100..161.8`, `>=161.8`) against configured levels.
3. Keep documentation aligned with actual backend logic.

Acceptance:
1. No regression in trigger behavior.
2. Documented behavior matches tested runtime.

## 4) Implementation Notes

1. Current pattern catalog is 4-slot based, but matcher internals should be written template-length ready.
2. For now, require minimum 4 available structure slots to evaluate catalog modes.
3. Avoid new user-facing toggles in this task to keep UX simple.

## 5) Rollout Strategy

1. Ship with default `COMPOUND_MODE_OFF`.
2. Activate one mode at a time in quant tests (continuations first, then reversals, then breakouts).
3. Include uncommon modes in the public enum from day one so they are available for live/sandbox selection.
4. Keep uncommon modes under stricter quant thresholds (higher sample and tighter drawdown limits) before production weighting.

## 6) Decision Locked (Feb 13, 2026)

Uncommon defensive modes are included in the visible input enum from day one:
1. `COMPOUND_MODE_CHOP_GUARD`
2. `COMPOUND_MODE_VOLATILITY_TRAP`
3. `COMPOUND_MODE_COMPRESSION_WAIT`

Reason:
1. These regimes can appear abruptly in live markets and must be selectable without code changes.

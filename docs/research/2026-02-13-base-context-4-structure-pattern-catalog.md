# Base Context 4-Structure Explicit Pattern Catalog (Research)

Date: 2026-02-13  
Status: Research document for future feature design (no runtime behavior changes)

## 1) Scope and Objective

This document maps directly to:
- `Base_First_Structure_Filter` (`S1`, most recent, equivalent to slot `[0]`)
- `Base_Second_Structure_Filter` (`S2`, equivalent to slot `[1]`)
- `Base_Third_Structure_Filter` (`S3`, equivalent to slot `[2]`)
- `Base_Fourth_Structure_Filter` (`S4`, oldest in the 4-slot window, equivalent to slot `[3]`)

Primary goal:
- Define future pattern logic with explicit structure types per slot (`HL`, `HH`, `LL`, `LH`, `EQ`) and no ambiguity.

Secondary goal:
- Keep `C/R/E` only as classification tags, not as the primary trigger model.

## 2) How the 4-Slot Structure Is Built (No-Bias Reference)

From the current structure classifier, the sequence alternates by extremum side.

If anchor is `initial_is_bottom`:
- `S1`: low-family (`HL` or `LL`)
- `S2`: high-family (`HH` or `LH`)
- `S3`: low-family (`HL` or `LL`)
- `S4`: high-family (`HH` or `LH`)

If anchor is `initial_is_peak`:
- `S1`: high-family (`HH` or `LH`)
- `S2`: low-family (`HL` or `LL`)
- `S3`: high-family (`HH` or `LH`)
- `S4`: low-family (`HL` or `LL`)

This is why explicit templates should always account for anchor parity.

## 3) Explicit Pattern Catalog (Primary Research Set)

### 3.1 Continuation Patterns

| ID | Anchor | Exact sequence (`S1,S2,S3,S4`) | Type | Notes |
|---|---|---|---|---|
| `CONT_BULL_01` | bottom | `HL,HH,HL,HH` | continuation | Strong bullish persistence. |
| `CONT_BULL_01` | peak | `HH,HL,HH,HL` | continuation | Same regime with opposite anchor parity. |
| `CONT_BEAR_01` | bottom | `LL,LH,LL,LH` | continuation | Strong bearish persistence. |
| `CONT_BEAR_01` | peak | `LH,LL,LH,LL` | continuation | Same regime with opposite anchor parity. |
| `CONT_BULL_02` | bottom | `HL,HH,LL,LH` | continuation-after-pullback | Recent pair bullish, older pair bearish. |
| `CONT_BULL_02` | peak | `HH,HL,LH,LL` | continuation-after-pullback | Same logic, parity-adjusted. |
| `CONT_BEAR_02` | bottom | `LL,LH,HL,HH` | continuation-after-pullback | Recent pair bearish, older pair bullish. |
| `CONT_BEAR_02` | peak | `LH,LL,HH,HL` | continuation-after-pullback | Same logic, parity-adjusted. |

### 3.2 Reversion Patterns

| ID | Anchor | Exact sequence (`S1,S2,S3,S4`) | Type | Notes |
|---|---|---|---|---|
| `REV_BULL_01` | bottom | `HL,HH,LL,LH` | reversion | Confirmed bullish reversal from older bearish pair. |
| `REV_BULL_01` | peak | `HH,HL,LH,LL` | reversion | Same regime flip, parity-adjusted. |
| `REV_BEAR_01` | bottom | `LL,LH,HL,HH` | reversion | Confirmed bearish reversal from older bullish pair. |
| `REV_BEAR_01` | peak | `LH,LL,HH,HL` | reversion | Same regime flip, parity-adjusted. |
| `REV_BULL_02` | bottom | `HL,LH,LL,LH` | early reversion | Low side turns first; high side still weak. |
| `REV_BEAR_02` | peak | `LH,HL,HH,HL` | early reversion | High side turns first; low side still weak. |

### 3.3 Breakout and Compression Patterns

| ID | Anchor | Exact sequence (`S1,S2,S3,S4`) | Type | Notes |
|---|---|---|---|---|
| `BRK_BULL_01` | bottom | `HL,HH,EQ,EQ` | breakout | Bullish pressure after compressed history. |
| `BRK_BULL_01` | peak | `HH,HL,EQ,EQ` | breakout | Same behavior with parity adjustment. |
| `BRK_BEAR_01` | bottom | `LL,LH,EQ,EQ` | breakout | Bearish pressure after compressed history. |
| `BRK_BEAR_01` | peak | `LH,LL,EQ,EQ` | breakout | Same behavior with parity adjustment. |
| `BRK_BULL_02` | bottom | `EQ,EQ,HL,HH` | post-breakout continuation | Compression first, then directional confirmation. |
| `BRK_BEAR_02` | peak | `EQ,EQ,LH,LL` | post-breakout continuation | Compression first, then bearish confirmation. |

### 3.4 Uncommon / Defensive Patterns

| ID | Anchor | Exact sequence (`S1,S2,S3,S4`) | Type | Suggested treatment |
|---|---|---|---|---|
| `UNC_01` | bottom | `HL,LH,HL,LH` | converging/whipsaw | Usually block unless strong confluence. |
| `UNC_02` | bottom | `LL,HH,LL,HH` | expansion whipsaw | Avoid in baseline strategy stack. |
| `UNC_03` | any | `EQ,EQ,EQ,EQ` | flat compression | Enable only with dedicated breakout stack. |

## 4) `C/R/E` Tags (Secondary Metadata Only)

Use `C/R/E` to label patterns, not to drive slot matching.

Directional tags:
- Bullish context: `C=HL`, `R=LL`, `E=EQ`
- Bearish context: `C=LH`, `R=HH`, `E=EQ`

Example:
- `HL,HH,HL,HH` can be tagged as bullish continuation, but slot matching must stay explicit.

## 5) Backend Note: Why Current Logic Is Not Yet the Intended Compound Engine

Current filters are per-slot, but with a global direction-side gate:
- Bullish only allows bottom-family filters (`HL` or `LL`) in `TrendStructureFilterMatches(...)`.
- Bearish only allows peak-family filters (`LH` or `HH`).

Consequence:
- Mixed low/high explicit templates (for example `HL,HH,HL,HH`) cannot be represented in current inputs for a bullish signal.
- The second `HH` slot is rejected before slot-type comparison, because `HH` is peak-family and bullish path only accepts bottom-family.

Concrete examples:
1. Desired future template:
   `S1=HL, S2=HH, S3=HL, S4=HH`, bullish signal.
   Current backend result: blocked at `S2`.
2. Desired future template:
   `S1=LH, S2=LL, S3=LH, S4=LL`, bearish signal.
   Current backend result: blocked at `S2`.
3. Current-style compatible template:
   `S1=HL, S2=HL, S3=HL, S4=HL`, bullish signal.
   This can pass, but it does not represent full alternating structure logic.

Additional limitation:
- `EQ` is tolerated by family in the current matcher.
- There is no explicit `EQ` mode in `TrendStructureFilterModes`.

## 6) Quantitative Rollout Guidance

Recommended order:
1. Start with strong continuation templates: `CONT_BULL_01`, `CONT_BEAR_01`.
2. Add confirmed reversions: `REV_BULL_01`, `REV_BEAR_01`.
3. Add breakout templates only after explicit `EQ` handling exists.
4. Keep uncommon templates disabled by default.

Validation checklist:
1. Evaluate each template per symbol and timeframe.
2. Use realistic spread, commission, and slippage assumptions.
3. Track `N`, expectancy, profit factor, max drawdown, MAE, and MFE.
4. Require walk-forward stability before production activation.
5. Penalize templates that collapse out-of-sample or are regime-fragile.

## 7) Future Feature Recommendation

To match this research exactly in backend logic:
1. Add a dedicated compound matcher mode (for example `TrendStructureCompoundModes`).
2. Compare each slot against explicit allowed types, without global side-family rejection.
3. Add explicit `EQ` control (`required`, `allowed`, `forbidden`) per template.
4. Keep fail-closed behavior when structure data is unavailable.

## 8) Draft Spec for Future Implementation Plan

This section is a direct draft for a future coding plan.

### 8.1 Proposed enum draft (non-trader friendly names)

Use one compound selector instead of four independent slot filters.
The enum names below are intentionally product-like for non-trader users.

```cpp
enum TrendStructureCompoundModes
{
  COMPOUND_MODE_OFF = 0,                  // No pattern filter

  // Continuation
  COMPOUND_MODE_TREND_RIDE_BUY,           // CONT_BULL_01
  COMPOUND_MODE_TREND_RIDE_SELL,          // CONT_BEAR_01

  // Reversion
  COMPOUND_MODE_REVERSAL_CONFIRM_BUY,     // REV_BULL_01
  COMPOUND_MODE_REVERSAL_CONFIRM_SELL,    // REV_BEAR_01

  // Breakout
  COMPOUND_MODE_BREAKOUT_READY_BUY,       // BRK_BULL_01
  COMPOUND_MODE_BREAKOUT_READY_SELL       // BRK_BEAR_01
};
```

Recommended mapping table for documentation/tests:

| Friendly enum | Research ID | Core sequence |
|---|---|---|
| `COMPOUND_MODE_TREND_RIDE_BUY` | `CONT_BULL_01` | `HL,HH,HL,HH` (+ parity twin) |
| `COMPOUND_MODE_TREND_RIDE_SELL` | `CONT_BEAR_01` | `LL,LH,LL,LH` (+ parity twin) |
| `COMPOUND_MODE_REVERSAL_CONFIRM_BUY` | `REV_BULL_01` | `HL,HH,LL,LH` (+ parity twin) |
| `COMPOUND_MODE_REVERSAL_CONFIRM_SELL` | `REV_BEAR_01` | `LL,LH,HL,HH` (+ parity twin) |
| `COMPOUND_MODE_BREAKOUT_READY_BUY` | `BRK_BULL_01` | `HL,HH,EQ,EQ` (+ parity twin) |
| `COMPOUND_MODE_BREAKOUT_READY_SELL` | `BRK_BEAR_01` | `LL,LH,EQ,EQ` (+ parity twin) |

Optional strictness toggle:

```cpp
enum StructureEqPolicyModes
{
  STRUCT_EQ_FORBIDDEN = 0,
  STRUCT_EQ_ALLOWED   = 1,
  STRUCT_EQ_REQUIRED  = 2
};
```

### 8.2 Proposed inputs draft

```cpp
input TrendStructureCompoundModes Base_Structure_Compound_Filter = COMPOUND_MODE_OFF;
input StructureEqPolicyModes      Base_Structure_EQ_Policy       = STRUCT_EQ_ALLOWED;
input bool                        Base_Structure_Allow_Parity_Twin = true;
```

Notes:
- `Base_Structure_Allow_Parity_Twin = true` means the same pattern can match either anchor parity (`initial_is_bottom` or `initial_is_peak`).
- When `false`, pattern matching is strict to a single declared anchor variant.

### 8.3 Evaluation algorithm draft

1. Read current structure snapshot (`S1..S4` as explicit types).
2. Resolve candidate template set from selected compound mode:
   - main template
   - optional parity twin template (if enabled)
3. For each slot `S1..S4`, compare actual vs expected:
   - if expected is not `EQ`, enforce equality.
   - if expected is `EQ`, enforce by `Base_Structure_EQ_Policy`.
4. Return `true` if any candidate template matches fully.
5. Fail-closed if structure data is missing or inconsistent.

### 8.4 Backward compatibility draft

Suggested staged migration:
1. Keep current 4-slot inputs active as default.
2. If `Base_Structure_Compound_Filter != COMPOUND_MODE_OFF`, use compound matcher and ignore legacy 4-slot filters.
3. Deprecate legacy 4-slot filters after quantitative validation period.

### 8.5 Minimal test matrix draft

Required unit tests before production:
1. Exact-match pass for each compound mode (both parity variants when enabled).
2. One-slot mismatch fail for each compound mode.
3. `EQ` policy behavior:
   - `FORBIDDEN`: any `EQ` in required non-`EQ` slot fails.
   - `ALLOWED`: `EQ` accepted only where policy permits.
   - `REQUIRED`: non-`EQ` value in `EQ` slot fails.
4. Missing/invalid structure data fails closed.
5. Compatibility tests proving legacy behavior unchanged when compound mode is `OFF`.

### 8.6 Quant guardrails draft

Before enabling any compound in live deployment:
1. Minimum sample threshold (`N`) per symbol/timeframe.
2. Positive expectancy after costs in out-of-sample windows.
3. Drawdown bounds under risk policy.
4. Stability across at least two market regimes.

### 8.7 Plug-and-play Fibonacci presets by compound mode

These presets are designed to match current backend behavior where entry is triggered by the active Fibonacci band and `LEVELS_AS_LIMITS` places entry at the selected boundary.

| Compound mode | Recommended `Structure_Fibonacci_Levels` | Why this set |
|---|---|---|
| `COMPOUND_MODE_TREND_RIDE_BUY` / `COMPOUND_MODE_TREND_RIDE_SELL` | `23.6,38.2,50.0,61.8,78.6,100.0` | Balanced continuation retracements with multiple decision bands. |
| `COMPOUND_MODE_REVERSAL_CONFIRM_BUY` / `COMPOUND_MODE_REVERSAL_CONFIRM_SELL` | `38.2,50.0,61.8,78.6,100.0` | Focuses on deeper retracement zones for reversal confirmation. |
| `COMPOUND_MODE_BREAKOUT_READY_BUY` / `COMPOUND_MODE_BREAKOUT_READY_SELL` | `0.0,61.8,100.0` | Simple compression-to-breakout structure with broad trigger zones. |

Recommended default for non-trader onboarding:
1. Start with `23.6,38.2,50.0,61.8,78.6,100.0`.
2. Switch to `0.0,61.8,100.0` only for breakout-focused modes.

### 8.8 Break-even (BE) behavior recommendation (future risk module)

Assuming BE means break-even logic:
1. Arm BE after price reaches the next Fibonacci step from entry in trade direction.
2. Move stop to `entry_price + costs_buffer` (spread + commission + small safety offset).
3. Keep BE policy identical across buy/sell modes for user simplicity.

Implementation note:
- Current repository state does not include an active dedicated BE manager in runtime path.
- Treat this BE block as future-plan guidance to keep plug-and-play behavior coherent.

---

This version is intentionally explicit: each pattern is defined as a concrete 4-slot structure build, aligned with extremum alternation, and ready for quant testing without directional ambiguity.

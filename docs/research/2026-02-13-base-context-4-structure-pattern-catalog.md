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

### 8.1 Coverage status (current vs target)

Current repository runtime:
- There is no active compiled `TrendStructureCompoundModes` enum in `services/core/enums.mqh`.
- Runtime still uses the legacy 4-slot filters (`Base_First...Base_Fourth`).

Current document status:
- The previous 6 `COMPOUND_MODE_*` names were a compact starter subset.
- Full Pattern Catalog coverage is still needed for future implementation.

Target for future tasks:
- Add one canonical enum value per Pattern Catalog ID.
- Keep optional friendly (marketing) profile names mapped to those canonical IDs.

### 8.2 Canonical enum draft (full Pattern Catalog IDs)

```cpp
enum TrendStructureCompoundModes
{
  COMPOUND_MODE_OFF = 0,

  COMPOUND_MODE_CONT_BULL_01,
  COMPOUND_MODE_CONT_BEAR_01,
  COMPOUND_MODE_CONT_BULL_02,
  COMPOUND_MODE_CONT_BEAR_02,

  COMPOUND_MODE_REV_BULL_01,
  COMPOUND_MODE_REV_BEAR_01,
  COMPOUND_MODE_REV_BULL_02,
  COMPOUND_MODE_REV_BEAR_02,

  COMPOUND_MODE_BRK_BULL_01,
  COMPOUND_MODE_BRK_BEAR_01,
  COMPOUND_MODE_BRK_BULL_02,
  COMPOUND_MODE_BRK_BEAR_02,

  COMPOUND_MODE_UNC_01,
  COMPOUND_MODE_UNC_02,
  COMPOUND_MODE_UNC_03
};
```

### 8.3 Friendly profile aliases (optional UX layer)

Use friendly names as aliases to canonical IDs, not as the only logic layer.

```cpp
enum TrendStructureProfileModes
{
  COMPOUND_PROFILE_OFF = 0,
  COMPOUND_PROFILE_TREND_RIDE_BUY,       // CONT_BULL_01
  COMPOUND_PROFILE_TREND_RIDE_SELL,      // CONT_BEAR_01
  COMPOUND_PROFILE_REVERSAL_CONFIRM_BUY, // REV_BULL_01
  COMPOUND_PROFILE_REVERSAL_CONFIRM_SELL,// REV_BEAR_01
  COMPOUND_PROFILE_BREAKOUT_READY_BUY,   // BRK_BULL_01
  COMPOUND_PROFILE_BREAKOUT_READY_SELL   // BRK_BEAR_01
};
```

### 8.4 Proposed inputs draft

```cpp
input TrendStructureCompoundModes Base_Structure_Compound_Filter = COMPOUND_MODE_OFF;
input TrendStructureProfileModes  Base_Structure_Profile_Filter  = COMPOUND_PROFILE_OFF;
input StructureEqPolicyModes      Base_Structure_EQ_Policy       = STRUCT_EQ_ALLOWED;
input bool                        Base_Structure_Allow_Parity_Twin = true;
```

Optional strictness toggle:

```cpp
enum StructureEqPolicyModes
{
  STRUCT_EQ_FORBIDDEN = 0,
  STRUCT_EQ_ALLOWED   = 1,
  STRUCT_EQ_REQUIRED  = 2
};
```

Resolution rule draft:
1. If `Base_Structure_Compound_Filter != COMPOUND_MODE_OFF`, use canonical mode directly.
2. Else if `Base_Structure_Profile_Filter != COMPOUND_PROFILE_OFF`, map profile to canonical ID.
3. Else keep legacy 4-slot filter path.

### 8.5 Evaluation algorithm draft

1. Read current structure snapshot (`S1..S4` as explicit types).
2. Resolve candidate template set from selected canonical mode:
   - main template
   - optional parity twin template (if enabled)
3. For each slot `S1..S4`, compare actual vs expected:
   - if expected is not `EQ`, enforce equality.
   - if expected is `EQ`, enforce by `Base_Structure_EQ_Policy`.
4. Return `true` if any candidate template matches fully.
5. Fail-closed if structure data is missing or inconsistent.

### 8.6 Backward compatibility draft

Suggested staged migration:
1. Keep current 4-slot inputs active as default.
2. If compound filter/profile is selected, use compound matcher and ignore legacy 4-slot filters.
3. Deprecate legacy 4-slot filters after quantitative validation period.

### 8.7 Minimal test matrix draft

Required unit tests before production:
1. Exact-match pass for each canonical compound mode (both parity variants when enabled).
2. One-slot mismatch fail for each canonical mode.
3. `EQ` policy behavior:
   - `FORBIDDEN`: any `EQ` in required non-`EQ` slot fails.
   - `ALLOWED`: `EQ` accepted only where policy permits.
   - `REQUIRED`: non-`EQ` value in `EQ` slot fails.
4. Missing/invalid structure data fails closed.
5. Compatibility tests proving legacy behavior unchanged when compound mode/profile is `OFF`.

### 8.8 Quant guardrails draft

Before enabling any compound in live deployment:
1. Minimum sample threshold (`N`) per symbol/timeframe.
2. Positive expectancy after costs in out-of-sample windows.
3. Drawdown bounds under risk policy.
4. Stability across at least two market regimes.

### 8.9 Backend-verified `Structure_Trigger_Entry` behavior

Validated in:
- `services/trading_signals/market_signal_filters.mqh`
- `services/trading_signals/grid_planner.mqh`
- `services/trading_signals/grid_order_lifecycle.mqh`
- `services/trading_management/structure_fibonacci_levels.mqh`

| Mode | Candle source used for entry test | Trigger gate | Entry price resolved | Execution consequence |
|---|---|---|---|---|
| `LEVELS_AS_LIMITS` | `bar_index=1` (closed candle on strategy context TF) | `close_percent` or direction extreme percent must fall in one strict configured Fibonacci band | Boundary price of active band, direction-safe: bullish uses lower absolute boundary, bearish uses upper absolute boundary | `entry_is_limit=true`; level-0 activation uses passive limit logic |
| `LEVEL_AS_ZONE` | `bar_index=0` (forming candle on strategy context TF) | same strict band gate as above | `entry_price = current close` | `entry_is_limit=false`; level-0 activation uses stop-style condition against reference close (typically immediate/near-immediate when condition holds) |

Important behavior notes:
1. Trigger band selection uses `ResolveFibonacciRangeForPercentStrict(...)`. Entry trigger is bounded by configured min/max levels.
2. Out-of-band returns `true` with `in_zone=false` (filter blocks entry, not a hard runtime error).
3. Evaluation cadence is once per new `Strategy_Timeframe` bar (`last_bar_time` gate), not every tick.
4. With `LEVELS_AS_LIMITS`, entry is not always at `61.8`; it is whichever boundary belongs to the active band and satisfies passive-order direction checks.
5. `100.0` is not automatically a broker SL. Orders are sent with broker `SL=0` in current runtime path; risk exits are managed by grid lifecycle logic.

Examples:
1. Config `0.0,61.8,100.0`, bullish, `LEVELS_AS_LIMITS`, active band is `[0.0,61.8]`.
   Result: entry limit is placed on the passive boundary of that band for bullish direction (not hardcoded to `61.8`).
2. Same config, bearish, `LEVEL_AS_ZONE`, close/high enters `[61.8,100.0]`.
   Result: signal is in-zone; entry reference is current close and level-0 can activate as soon as bearish stop condition is met.

### 8.10 Fibonacci recommendations by Pattern Catalog ID

These are plug-and-play research presets for future compound mode implementation.

| Pattern ID(s) | Suggested use | `LEVELS_AS_LIMITS` levels | `LEVEL_AS_ZONE` levels | Quant note |
|---|---|---|---|---|
| `CONT_BULL_01`, `CONT_BEAR_01` | strong continuation | `23.6,38.2,50.0,61.8,78.6,100.0,127.2` | `38.2,50.0,61.8,78.6,100.0` | Balanced retracement entries with optional shallow continuation extension. |
| `CONT_BULL_02`, `CONT_BEAR_02` | continuation after pullback | `38.2,50.0,61.8,78.6,100.0,127.2,161.8` | `50.0,61.8,78.6,100.0,127.2` | Bias to deeper pullback confirmation. |
| `REV_BULL_01`, `REV_BEAR_01` | confirmed reversal | `50.0,61.8,78.6,100.0,127.2,161.8` | `61.8,78.6,100.0,127.2` | Avoid shallow reversal entries; demand stronger rejection context. |
| `REV_BULL_02`, `REV_BEAR_02` | early reversal | `61.8,78.6,100.0,127.2,161.8,200.0` | `78.6,100.0,127.2,161.8` | Higher false-positive risk; require deeper levels and strict risk controls. |
| `BRK_BULL_01`, `BRK_BEAR_01` | compression breakout | `0.0,61.8,100.0,127.2,161.8` | `61.8,100.0,127.2` | Keeps classic breakout map while supporting continuation extension. |
| `BRK_BULL_02`, `BRK_BEAR_02` | post-breakout continuation | `23.6,38.2,50.0,61.8,100.0,127.2,161.8` | `38.2,61.8,100.0,127.2` | Use when structure confirms trend after compression release. |
| `UNC_01` | converging / whipsaw | `38.2,61.8,100.0` | `61.8,100.0` | Keep disabled by default; enable only with additional confluence filters. |
| `UNC_02` | expansion whipsaw | `OFF (recommended)` | `OFF (recommended)` | Baseline stack should block this regime. |
| `UNC_03` | full compression | `0.0,61.8,100.0,127.2,161.8` | `61.8,100.0,127.2` | Enable only in dedicated breakout stack with spread/slippage controls. |

### 8.11 Deep-level acceptance rules (`100..161.8` and `>=161.8`)

1. Entry trigger stage is strict-range bounded. To trigger in `[100.0,161.8]`, both levels must exist in `Structure_Fibonacci_Levels`.
2. To trigger at or above `161.8`, include at least one level above `161.8` (for example `200.0`), otherwise strict trigger rejects > max configured level.
3. After a signal exists, grid-level progression can still cycle beyond base levels through cycled-level helpers, but that does not bypass initial strict entry gating.

### 8.12 Break-even (BE) behavior recommendation (future risk module)

Assuming BE means break-even logic:
1. Arm BE after price reaches the next Fibonacci step from entry in trade direction.
2. Move stop to `entry_price + costs_buffer` (spread + commission + small safety offset).
3. Keep BE policy identical across buy/sell modes for user simplicity.

Implementation note:
- Current repository state does not include an active dedicated BE manager in runtime path.
- Treat this BE block as future-plan guidance.

---

This version is intentionally explicit: each pattern is defined as a concrete 4-slot structure build, aligned with extremum alternation, and ready for quant testing without directional ambiguity.

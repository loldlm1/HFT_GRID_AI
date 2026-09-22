# Proposal: Candle Pattern Discovery

Prepared 2026-09-22 from the discussion and MT5 baseline
`2bc95d39d9e6ef2954bc3ffebef145dbc9d81d53`.

**Stage:** Accepted design brief. Subsequent answers and execution authorization
are recorded in the [execution record](candle-pattern-discovery-plan.md).
The [project index](docs/README.md) owns current V14 delivery and validation status.

## Problem And Outcome

Create a candle-pattern dataset alongside the existing Pivot V14 dataset.
Researchers should discover Harami and Engulfing behavior independently, compare
pattern-aligned and opposite trades, inspect one SL-triggered re-entry, and
evaluate taking only the first N qualifying entries during a broker Macro candle.

The reference [experimental EA](</home/admin/.wine/drive_c/MetaTrader 5-1/MQL5/Experts/Free Robots/Candle_Pattern_ATR_Experimental.mq5>)
already detects completed-candle patterns and uses ATR(13), multiplier 1.0,
shift 1. Its single-direction selection, exposure blocking, and post-fill TP
realignment differ from the proposed discovery lifecycle.

## Scope

- Two independently owned EAs: the existing Pivot producer and a new Candle
  Patterns producer. One Candle EA may collect both pattern families, but their
  research populations, node paths, allowances, statistics, and model evaluation
  remain separate. Re-entries always inherit their original pattern family.
- Preserve V14 exports, schema meanings, broker ownership, saved research, and
  acceptance evidence. Give Candle data a separate schema/engine identity and
  export namespace; do not migrate it into V14 or purge existing datasets.
- Candle signals originate only on Micro. Macro supplies feature/pivot context
  and the position-lifetime duration. There is no Deep timeframe, Macro trade
  parent requirement, or Macro entry signal in this engine.
- Include the producer contract and downstream research behavior in the design.
  Live rollout, consumer deployment, and runtime model decisions are excluded.
  Existing Pivot-specific execution rules
  remain governed by the [V14 runtime contract](docs/architecture/market-data-broker-executor.md).

## Recommended Approach

### 1. Preserve Events And Feature Meaning

Detect each original pattern from the two completed Micro candles, with entry
on the first eligible tick of the next Micro candle. Preserve the experimental
body-based rules: opposite candle directions, no dojis or identical bodies,
and one shared body boundary allowed. Retain pattern type and bullish/bearish
pattern direction independently from BUY/SELL execution direction. Existing
positions do not suppress discovery of later original patterns.

Capture Macro and Micro features at each entry decision, including re-entry.
Reuse V14's indicator calculations and historical-shift semantics: Bands
21/0/2.0 with `PRICE_WEIGHTED`, Stochastic 5/3/3 with `MODE_SMA` and `STO_CLOSECLOSE`,
and the existing derived smoothing, slopes, states, and width measurements.
Freeze shift-0 observations immediately; never replace them with the completed
candle's later values. Fill prices and future outcomes are execution/label facts,
not pre-entry predictors.

V14 percent-B is pivot-relative. Candle data should distinguish signal-price
percent-B, using the decision Bid, from tested-pivot-relative percent-B. Keep
the anchors explicitly named and versioned. An absent tested pivot leaves that
context unavailable without suppressing the candle event. Missing optional
research features mark incompleteness; missing ATR prevents valid stop geometry.

### 2. Separate Pivot Location From Tested Context

Calculate the Macro ladder from the previous completed broker Macro candle.
Track Bid interactions with PP, S1-S3, and R1-R3 before the entry decision.
Keep entry interval, tested level, support/resistance role, touch time, reclaim
status, elapsed time, signed distance, and pivot-window identity as distinct facts.

| Entry situation | Price interval | Tested context |
| --- | --- | --- |
| Below S1, above S2, after an S1 interaction | S2_TO_S1 | S1, below level |
| Above S1, below PP, after touching and reclaiming S1 | S1_TO_PP | S1, reclaimed support |
| Above S1, below PP, without an observed S1 interaction | S1_TO_PP | No S1 test recorded |

An observed support reclaim requires approach from above, a touch/cross, and
return above the level before the decision; resistance is symmetrical. Keep
per-level evidence when several levels qualify, distinguish gap crossings from
observed tests, and never assign a new ladder retroactively to an older touch.
Actual BUY entry uses Ask, so its executable interval may differ from Bid context.
Pivot criteria are research filters, not broker-entry vetoes.

### 3. Execute Both Directions And One Re-entry

Each original pattern has ALIGNED and OPPOSED branches. A bullish pattern maps
to BUY aligned and SELL opposed; a bearish pattern reverses that relationship.
Each direction has 1R broker execution and 2R/3R virtual trials. There is no 5R
lane. A 1R parity shadow may support broker calibration without becoming an
additional independent signal. Opposite broker positions require hedging;
their requests and fills are separate and cannot be assumed atomic.

Use ATR(13) times 1.0 for stop distance and derive targets from the normalized
risk distance. The recommended baseline is the latest completed Micro ATR
(shift 1) for both original and re-entry decisions. Also freeze ATR shift 0 for
research. Record the ATR used, source bar/shift, price and point values,
multiplier, and submitted/filled risk geometry. Changing the execution ATR policy
requires new outcome trials or replay, not simply filtering stored ATR values.

Allow at most one same-direction market re-entry after an original broker 1R
position is confirmed closed by SL within its permitted lifecycle. Preserve
its original pattern identity and capture fresh quotes, ATR, and Macro/Micro
features. Recheck broker eligibility before sending. No additional pattern,
resting limit order, or recursive re-entry chain is involved.

A 2R/3R virtual SL cannot authorize a broker re-entry; for example, 1R may already
have reached TP before 3R later stops out. Confirmed close reason/time and the
later observation/request clocks remain separate. Rejected or ambiguous requests
must not silently create duplicate attempts or successful-entry labels.

### 4. Keep Position Lifetime And Allowance Windows Separate

| Concept | Clock and behavior |
| --- | --- |
| Position deadline | Its actual entry time + PeriodSeconds(Macro_Timeframe) |
| Research allowance | The currently running broker Macro candle |
| Re-entry deadline | Its own actual entry time + the full Macro duration |
| Re-entry allowance membership | The Macro candle containing that re-entry |

With H2, a 10:35 entry belongs to the broker candle running 10:00-12:00 and
expires at 12:35. A re-entry at 12:05 belongs to the next Macro allowance window
and expires at 14:05. Changing the allowance window does not close positions.
Broker Macro candle openings supersede the earlier first-entry-window suggestion.
Analysis-time/DST display fields do not determine either causal clock.

At the position deadline, request closure of any remaining broker position and
apply the corresponding virtual time-exit policy. Record scheduled expiry and
actual execution separately: unavailable quotes cannot establish an invented
deadline fill. TIME_EXIT has its own realized return when observable; it is
censored for a TP-before-SL binary target, not relabeled SL. Run-end censoring,
rejection, and invalid geometry remain separate. Report expiry frequency and
time-exit returns rather than silently excluding them from strategy performance.

### 5. Apply Simple Research Selection Within Each Family

| Research control | Meaning |
| --- | --- |
| Entry type | All, original patterns only, or re-entries only |
| Maximum entries per Macro candle | 0 = unlimited; N > 0 = first N qualifying entries |

Within one pattern family, node path, symbol, and broker Macro candle, apply
causal node conditions and the entry-type selector before chronological ranking.
Retain broker timestamps and a stable sequence for deterministic ordering.
Count individual selected entries, including re-entries. BUY and SELL each count
when selected; virtual reward-ratio rows do not. Earlier exits do not replenish
the allowance. A new Macro candle resets it even while older positions survive.
Harami never consumes Engulfing's allowance, or vice versa. Keep raw capture
uncapped by these research controls, with explicit bounded storage/capacity rules.

For Harami with H2 and N=2, a qualifying 10:35 original and 11:00 re-entry use
that candle's two entries; a later qualifying Harami is skipped by that selected
policy. Engulfing is evaluated independently. Choose the earliest qualifying
entries without consulting their eventual wins, losses, or completed durations.

Re-entry-only analysis may inspect recorded children with their parent links.
A simulation under the confirmed-broker-SL rule cannot execute a child if its
original trade was skipped by the selected strategy. A strategy that trades
only re-entries using virtual originals is a separate, currently excluded
execution policy. Per-node selection also does not establish a portfolio-wide
budget across several nodes or reproduce counterfactual margin/fill behavior.

### 6. Version The Producer And Consumer Together

Suggested names are `Candle_Pattern_Discovery.mq5` and `CandlePatternV1`; these are
provisional. Keep `HFT_Grid_AI.mq5` initially; a later
`Pivot_Discovery.mq5` rename is optional and requires preserving run/ownership
identity and operator references. Reuse stable calculation helpers without
sharing strategy state or importing the experimental EA's complete order path.

Keep event, direction branch, entry attempt, feature snapshot, ratio trial,
broker evidence, and outcome identities explicit. Preserve the root event and
pattern family through every relationship. The current
[offline tools](tools/deterministic_signal_ml/README.md) accept V14 only;
Candle needs a distinct intake/feature contract, with family separation enforced
in downstream research. This proposal defines no new TSV count or migration.

## Decisions

The user's initial request establishes the event/feature and reward-ratio scope.
Their first clarification confirms actual time-based closure, market re-entry,
entry-type research filters, and pivot/percent-B separation. Their final
clarification fixes allowances to the running Macro candle and requires independent
Harami/Engulfing discovery. Those decisions govern this proposal.

Subsequent explicit user answers resolve the detailed choices:

1. Use ATR shift 1 for both originals and re-entries; capture shift 0 as research.
2. Reset active context each Macro candle; retain every level's evidence and use
   the latest tested level, outermost on simultaneous ties, with V14 normalized
   touches and PP departure/return rules.
3. Keep submitted SL/TP immutable and record actual fill deviation.
4. Separate ALIGNED and OPPOSED research categories and their allowances. Each
   research path chooses its direction category, so there is no shared last-slot
   priority between them. Rejected requests do not count as entered positions.
5. Complete this delivery through automated MetaEditor/MT5 MCP and data checks;
   defer human chart review and visual MT5 object adjustment to later work.

## Success And Risks

- Existing V14 behavior and retained data remain intact. The Candle contract
  demonstrates separate pattern populations, causal features, correct direction
  and attempt links, independent deadlines, and deterministic per-family quotas.
- Validate the new behavior with focused existing test workflows and bounded MT5
  tester cases, including overlap, both directions, SL re-entry, Macro rollover,
  time exits, rejected requests, missing data, and family isolation. Future source
  changes require compilation with 0 errors/0 warnings and automated MCP tester
  acceptance. Human visual review is deferred; this brief supplies no new runtime
  validation evidence.
- Keep all related directions, ratios, and re-entries together across temporal
  validation splits, and purge overlapping outcome periods. Evaluate quotas on
  unseen periods using support, costs, expectancy, drawdown, and expiry rates.
- Principal risks are correlated observations, broker-versus-virtual divergence,
  spread/latency near short ATR stops, delayed expiry execution, and loss of
  research independence through shared account margin. Record these effects;
  two pattern populations do not imply financially isolated broker accounts.
- Existing broker-equivalence and rollout gates remain in the project index.
  Preserve original data and version the new producer/consumer independently
  so a future rollback does not require rewriting either dataset family.

## Next Requested Stage

The user accepted the chat implementation plan and authorized its complete
execution. Follow the execution record and current index, preserving the resolved
answers. Production deployment, data purges and live rollout remain excluded.

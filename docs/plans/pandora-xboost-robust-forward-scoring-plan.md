# Plan: Pandora XBoost Robust Forward Scoring v4

**Generated**: 2026-06-24
**Estimated Complexity**: Critical / Trading-Sensitive
**Status**: Implemented and compiled on 2026-06-24

## Overview

Upgrade Pandora XBoost from Bayesian v3 scoring to a v4 robust forward-scoring
methodology. The goal is to increase the number of real broker trades without
losing robustness, while reducing fragile TOP selections caused by branches
that have a positive average R only because a few trailing winners offset many
small losses.

The strategy remains adaptive. In `PANDORA_XBOOST_INFERENCE`, XBoost continues
to train local branch statistics and can open real broker trades when a
candidate is robust enough. This plan does not add a frozen inference mode.

The v4 model should still respect the current business shape:

- Local XBoost branches remain the broad discovery source.
- Real broker trades remain sparse, high-quality audit evidence.
- Trailing winners are valid and should not be rejected simply because win rate
  is low.
- Fragile branches should be demoted in ranking before they are blocked.
- Broker ledger evidence should reduce confidence by node/path, not create a
  noisy global strategy kill switch.
- Keep new knobs as internal constants first. Avoid new user inputs unless
  manual QA proves they are necessary.
- Panel output should remain compact and show only the final TOP 3.

## Recommended v4 Methodology

Use a layered score:

```text
candidate_score_v4 =
  bayesian_conservative_score
  + trailing_payoff_credit
  - distribution_fragility_penalty
  - forward_instability_penalty
  - node_broker_degradation
```

Important interpretation:

- `bayesian_conservative_score` remains the base score from v3.
- `trailing_payoff_credit` allows low-win-rate branches to survive when their
  payoff is genuinely strong and repeatable.
- `distribution_fragility_penalty` punishes branches that only look good because
  of very few outliers.
- `forward_instability_penalty` checks whether the branch performs across later
  sample segments, not only in total history.
- `node_broker_degradation` uses real broker results only for the same node or
  path family. It should not globally block unrelated candidates.

## Confirmed Decisions

- Primary objective: more real broker trades without losing robustness.
- Keep adaptive inference semantics. Inference means local training plus real
  broker execution when candidates qualify.
- Do not add many new inputs. Prefer internal constants for v4.
- Do not add frozen inference in this plan.
- Keep panel compact: show only the final TOP 3.
- Do not block a branch solely because it has low win rate. Trailing systems can
  be valid with low win rate if payoff is strong.
- Demote fragile positive-average branches before blocking them.
- Replace noisy global broker calibration with node/path-level degradation.

## Non-Goals

- No SQLite or external database.
- No MQL5 CI/test harness.
- No Strategy Tester automation matrix.
- No new regime filter by trend, volatility, month, weekday, or session.
- No curve-fit optimizer that picks best historical windows after the fact.
- No live-trading risk-control bypasses.

## Files Likely To Change

- `services/trading_signals/pandora_xboost_state.mqh`
- `services/trading_signals/pandora_xboost_storage.mqh`
- `services/frontend/pandora_box_panel.mqh` only if panel integration requires
  explicit frontend changes.
- `docs/guides/pandora_box_guide_en.md`
- `docs/guides/pandora_box_guide_es.md`
- `docs/plans/pandora-xboost-robust-forward-scoring-plan.md`

## Data Model Direction

Prefer schema `v4` for model files so v3 CSV results are not mixed with v4
scoring:

```text
pandora_xboost_v4_<strategy_id>_<symbol>_<period>_stats.csv
pandora_xboost_v4_<strategy_id>_<symbol>_<period>_samples.csv
pandora_xboost_v4_<strategy_id>_<symbol>_<period>_broker_trades.csv
```

The existing v3 row formats can remain readable as migration/reference data only
if needed, but v4 should write its own files.

## Sprint Execution Policy

- Execute Sprints in order.
- Validate and commit each Sprint independently.
- Do not compile after every Sprint unless a Sprint specifically needs it.
- Compile once in the final Sprint, then remove `BUILD.log`.
- Do not add MQL5 test/CI scaffolding.
- Use manual Strategy Tester QA after implementation for behavior validation.

## Sprint 1: v4 Contracts And Compatibility Boundary

**Goal**: Introduce the v4 schema boundary and inert robust metric fields
without changing broker decisions yet.

**Commit**: `Sprint 1: add XBoost v4 scoring contracts`

**Demo/Validation**:
- Inspect constants, structs, and reset paths.
- Confirm v3 files are not overwritten by v4.
- Confirm no broker decision path changes yet.

### Task 1.1: Add v4 Schema Version

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Move the XBoost schema constant from `3` to `4` and add v4
  internal constants for robust scoring.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - New files use `pandora_xboost_v4_*`.
  - No v3 CSV file is modified by v4 runs.
- **Validation**:
  - Static inspection of filename builders.

### Task 1.2: Extend Candidate Metrics

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Add inert fields to `PandoraXBoostCandidate` for robust
  metrics:
  - `win_rate`
  - `loss_rate`
  - `be_rate`
  - `median_r`
  - `profit_factor_r`
  - `payoff_ratio_r`
  - `outlier_dependency_r`
  - `fragility_penalty_r`
  - `forward_stability_r`
  - `forward_penalty_r`
  - `broker_node_degradation_r`
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Constructors and copy constructors initialize/copy all fields.
  - Reset paths clear all fields.
- **Validation**:
  - Static constructor/copy-constructor audit.

### Task 1.3: Add Internal Constant Block

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Add internal constants for v4 thresholds without exposing
  them as inputs.
- **Recommended Initial Values**:
  - minimum robust score: `0.02R`
  - minimum edge: keep `0.05R`
  - median penalty weight: conservative
  - outlier dependency cap: conservative
  - broker node degradation weight: soft
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - No new user inputs are added.
  - Constants are documented with short comments.
- **Validation**:
  - `rg "input .*XBoost"` confirms no new inputs.

## Sprint 2: Distribution Metrics For Local Branches

**Goal**: Compute branch distribution quality so XBoost can distinguish robust
payoff from fragile average R.

**Commit**: `Sprint 2: add XBoost distribution metrics`

**Demo/Validation**:
- Logs/panel can show robust metrics in debug output.
- Candidate scoring is still behavior-preserving until Sprint 3 applies it.

### Task 2.1: Aggregate Sample Distribution

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Extend local sample aggregation to compute counts, win/loss/BE
  ratios, total win R, total loss R, median R, and basic payoff ratios.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Handles zero samples and all-win/all-loss cases safely.
  - Does not allocate unbounded memory per tick beyond candidate evaluation.
- **Validation**:
  - Static review for array bounds and divide-by-zero guards.

### Task 2.2: Add Median R Calculation

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Implement a simple local median calculation over node sample
  values.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Median is deterministic.
  - Empty sample set returns `0.0`.
  - Sorting is scoped to candidate evaluation only.
- **Validation**:
  - Static review for array copy/sort bounds.

### Task 2.3: Compute Outlier Dependency

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Estimate whether positive average R depends on a small number
  of large trailing winners.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - Branches with healthy payoff but repeated winners are not automatically
    blocked.
  - Branches with positive avgR and very negative median receive a penalty.
- **Validation**:
  - Review known nodes from `us_30_v1_depth_3_inf`, especially
    `L-ROOTL>S-SLL1` and `L-ROOTL>L-SLL1>S-SLL1`.

## Sprint 3: Robust Candidate Score

**Goal**: Apply distribution metrics to ranking so fragile branches are demoted
before they are blocked.

**Commit**: `Sprint 3: apply XBoost robust candidate scoring`

**Demo/Validation**:
- `READY` candidates use `score_v4`.
- Low-win/high-payoff branches can remain eligible when payoff quality is
  stable.
- Positive-average/high-fragility branches drop in ranking.

### Task 3.1: Add Fragility Penalty

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Penalize candidates when median R is materially below zero,
  loss rate is excessive, or the average relies too heavily on rare outliers.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Penalty reduces score but does not block by itself unless score falls below
    minimum robust score.
  - Trailing payoff can offset penalty only when payoff ratio and sample count
    justify it.
- **Validation**:
  - Static trace through `PandoraXBoostBuildCandidate()` and
    `PandoraXBoostApplyCandidateEdge()`.

### Task 3.2: Add Trailing Payoff Credit

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Add limited score credit for branches where losses are
  controlled and trailing winners are large enough to justify lower win rate.
- **Dependencies**: Task 3.1.
- **Acceptance Criteria**:
  - Credit is capped.
  - Credit cannot revive a branch with insufficient samples.
  - Credit cannot promote a branch with severe recent/forward degradation.
- **Validation**:
  - Static review of cap and order of operations.

### Task 3.3: Preserve TOP 3 Behavior

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Keep the TOP 3 candidate list but rank by v4 robust score.
- **Dependencies**: Task 3.2.
- **Acceptance Criteria**:
  - Panel remains TOP 3 only.
  - `READY`, `WATCH`, `BLOCK` semantics remain simple.
- **Validation**:
  - Static trace through sorting and broker selection.

## Sprint 4: Sample-Based Forward Stability

**Goal**: Add an internal walk-forward-style metric that depends on available
sample counts, not fixed user-selected calendar windows.

**Commit**: `Sprint 4: add XBoost forward stability scoring`

**Demo/Validation**:
- Candidate debug logs show forward stability.
- Branches that are only good in the oldest segment are demoted.

### Task 4.1: Segment Node Samples Chronologically

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Split node samples into chronological segments when enough
  samples exist. Use sample counts first, calendar time second.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - If samples are too sparse, forward stability is neutral.
  - No fixed annual limitation is imposed.
  - Works with short and long tester windows.
- **Validation**:
  - Static review of segment boundaries and sparse-sample fallback.

### Task 4.2: Compute Stability Penalty

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Penalize candidates when later segments perform materially
  worse than earlier segments.
- **Dependencies**: Task 4.1.
- **Acceptance Criteria**:
  - Demotion is stronger when recent segments are negative.
  - One weak sparse segment does not fully block a candidate.
- **Validation**:
  - Static review using observed cases where 2024/2025 were positive but 2026
    turned negative.

### Task 4.3: Integrate Forward Stability Into READY Gate

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Apply forward penalty before edge comparison.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Candidate score reflects stability before TOP sorting.
  - Branches with degraded forward profile are demoted.
- **Validation**:
  - Static trace through candidate build and top sorting.

## Sprint 5: Broker Ledger As Node-Level Degradation

**Goal**: Remove noisy global broker blocking and use broker evidence as
node/path-level degradation.

**Commit**: `Sprint 5: soften XBoost broker calibration`

**Demo/Validation**:
- `BROKER_30` no longer blocks unrelated candidates globally.
- Poor real results degrade the same node/path family.
- Broker evidence remains conservative and cannot promote candidates.

### Task 5.1: Remove Global Recent Broker Block

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Stop using recent broker average across the whole strategy as
  a hard `BLOCK`.
- **Dependencies**: Sprint 4.
- **Acceptance Criteria**:
  - No global `BROKER_30` hard block remains.
  - A debug metric may still report recent broker performance.
- **Validation**:
  - `rg "BROKER_30"` confirms it is no longer a hard candidate block.

### Task 5.2: Add Node/Path Family Broker Degradation

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Degrade only candidates whose exact node or parent path has
  poor real broker evidence.
- **Dependencies**: Task 5.1.
- **Acceptance Criteria**:
  - Exact node evidence has stronger weight than parent path evidence.
  - Sparse broker evidence is soft and capped.
  - Broker evidence never promotes a candidate.
- **Validation**:
  - Static review using broker rows from `us_30_v1_depth_3_inf`.

### Task 5.3: Keep Broker Audit Fields

- **Location**:
  - `services/trading_signals/pandora_xboost_state.mqh`
  - `services/trading_signals/pandora_xboost_storage.mqh`
- **Description**: Preserve broker ledger recording and model snapshot fields
  for future audits.
- **Dependencies**: Task 5.2.
- **Acceptance Criteria**:
  - `*_broker_trades.csv` still records selected real trades.
  - Audit fields include v4 score and model samples.
- **Validation**:
  - Static storage header/row count review.

## Sprint 6: TOP 3 Panel And Query Debug v4

**Goal**: Make v4 decisions auditable without cluttering the panel.

**Commit**: `Sprint 6: show XBoost v4 TOP audit metrics`

**Demo/Validation**:
- Panel shows final TOP 3 only.
- `query_debug.txt` has enough fields to explain selection or demotion.

### Task 6.1: Extend Dryrun Logs

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Add compact v4 fields to `PANDORA_XBOOST_DRYRUN`:
  - `score_v4`
  - `median`
  - `wr`
  - `pf`
  - `frag`
  - `fwd`
  - `brnode`
  - `reason`
- **Dependencies**: Sprint 5.
- **Acceptance Criteria**:
  - Logs remain behind existing log inputs.
  - No per-tick excessive logging beyond existing candidate events.
- **Validation**:
  - Static review of log emission paths.

### Task 6.2: Keep Panel TOP 3 Compact

- **Location**: `services/trading_signals/pandora_xboost_state.mqh`
- **Description**: Update `PandoraXBoostAppendSummaryLines()` to show final
  TOP 3 only with compact v4 score information.
- **Dependencies**: Task 6.1.
- **Acceptance Criteria**:
  - Panel does not list every rejected candidate.
  - Top lines remain readable in Strategy Tester.
- **Validation**:
  - Static review of summary text length.

### Task 6.3: Update Guides

- **Location**:
  - `docs/guides/pandora_box_guide_en.md`
  - `docs/guides/pandora_box_guide_es.md`
- **Description**: Document v4 methodology and clarify adaptive inference.
- **Dependencies**: Task 6.2.
- **Acceptance Criteria**:
  - Guides state that inference means training plus broker inference.
  - Guides explain robust score and node-level broker degradation.
- **Validation**:
  - Documentation review.

## Sprint 7: Final Compile Gate

**Goal**: Compile the EA once after all v4 scoring work is complete.

**Commit**: `Sprint 7: compile XBoost robust forward scoring`

**Demo/Validation**:
- MetaEditor compile returns `0 errors, 0 warnings`.
- `BUILD.log` is removed after reading.

### Task 7.1: Compile With MetaEditor

- **Location**: `HFT_Grid_AI.mq5`
- **Description**: Run the project compile command from `AGENTS.md`.
- **Dependencies**: Sprints 1-6 complete and committed.
- **Acceptance Criteria**:
  - Compile has `0 errors, 0 warnings`.
  - `BUILD.log` is deleted after inspection.
- **Validation**:
  - MetaEditor compile log.

### Task 7.2: Final Review

- **Location**: full repo diff.
- **Description**: Review changed files, hot-path cost, broker safety, and
  runtime cleanup.
- **Dependencies**: Task 7.1.
- **Acceptance Criteria**:
  - No unrelated refactors.
  - No new risk-control bypasses.
  - No stale generated logs.
- **Validation**:
  - `git status --short`
  - `git diff --check`

## Manual QA Workflow After Implementation

Run manual Strategy Tester checks in this order:

1. Short inference run with clean v4 files and logs enabled.
2. Confirm v4 files are created in Common storage.
3. Confirm local `samples` and `stats` grow every day with a Pandora root.
4. Confirm broker trades are recorded only when XBoost selects real execution.
5. Confirm panel shows TOP 3 only.
6. Confirm rejected/demoted candidates can be explained from
   `PANDORA_XBOOST_DRYRUN`.
7. Run a long adaptive inference test.
8. Compare:
   - number of real trades
   - average R
   - max drawdown
   - year-by-year real broker R
   - nodes selected repeatedly
   - whether 2026-style degradation demotes fragile nodes earlier

## Potential Risks And Gotchas

- More trades can mean lower selectivity. The plan addresses this by demoting
  fragile branches instead of blindly lowering thresholds.
- Low-win trailing systems are valid. The plan preserves them through capped
  payoff credit instead of hard win-rate blocks.
- Median R can be negative for valid trailing systems. It should penalize, not
  automatically block.
- Broker ledger samples are sparse and selection-biased. They should degrade
  same-node candidates, not globally kill the strategy.
- Forward stability can become overfit if windows are hand-picked. This plan
  uses sample-count segmentation and neutral fallback when samples are sparse.
- Schema v4 means previous v3 files will not be reused directly. That is safer
  for validation but requires fresh tester runs.

## Rollback Plan

- Set `Pandora_XBoost_Mode = PANDORA_XBOOST_DISABLED` to bypass XBoost.
- Revert to the last v3 commit if v4 scoring behaves worse in manual QA.
- Because v4 uses schema-separated CSV files, v3 data remains intact.

## Execution Notes

- Implemented in Sprint commits 1-7.
- Final compile gate passed with `0 errors, 0 warnings`.
- Manual Strategy Tester QA remains the required runtime validation step.

# Plan: Pivot First-Touch Retest Confluence Offline Research

**Generated**: 2026-07-29
**Status**: Planning only; implementation not started
**Planning Review**: Complete; no blocking clarification remains
**Estimated Complexity**: Medium-High
**Risk Class**: Medium - offline research contracts, feature engineering, validation splits, and model evidence change; MQL5 runtime and broker execution do not
**Execution Baseline**: Branch `bot/pivot_points_fractal`, commit `67c43983b1ddb8175c04ab5ddbbec6ecac77aaad`, clean worktree

## Overview

Extend the strict schema V9 research pipeline with a causal, first-touch retest
context and an unordered confluence layer without changing the EA, the V9 TSV
headers, broker execution, or the identity
`(symbol, pivot timeframe, active bar open, level)`.

The offline layer will make two related facts explicit:

1. For every first-touch attempt, classify the previous completed close of
   `M1`, `M15`, `M30`, `H1`, `H4`, and `D1` relative to the attempt's tested
   pivot price. A close above the tested price is `BUY_RETEST`, a close below
   is `SELL_RETEST`, equality is neutral, and unavailable causal context is
   explicit. This is a signal-time side snapshot, not a new trigger or a claim
   that an independent macro first touch occurred.
2. Build causal confluence from actual V9 first-touch attempts. Each member
   keeps its own timeframe, active window, level, direction, and trigger time.
   A member becomes available at its first touch and remains active only until
   its own pivot window expires. Mixed BUY/SELL members and arbitrary
   timeframe combinations are valid; no macro-to-micro ordering is required.

DuckDB remains the source of typed joins, Parquet tables, filtering, and
aggregates. A bounded chronological event sweep will materialize active
confluence membership without a quadratic interval join. XGBoost remains an
optional offline research consumer and receives only compact trigger-time
features after a baseline-versus-confluence ablation. No pattern, score, or
model will authorize or deny an MT5 order in this plan.

Planning discovery against the accepted natural Sprint 9 run established the
feasibility baseline:

- `49,716` first-touch attempts produce exactly `298,296` six-timeframe retest
  context rows.
- All five macro contexts matched a valid causal pivot window; no V9 exporter
  column was missing.
- A DuckDB `ASOF LEFT JOIN` derived all macro contexts in approximately
  `0.8-1.6` seconds on the current workstation.
- The exact half-open confluence policy produced `384,086` anchor/member rows,
  a mean of `7.73` active members, and a maximum of `29` against the theoretical
  five-timeframe/seven-level bound of `35`.
- A direct inequality join took approximately `55` seconds, while a bounded
  chronological event sweep produced the same membership count in about
  `1.6` seconds. The implementation must preserve the bounded approach.

Target research flow:

```text
strict V9 run validation
-> typed DuckDB source tables
-> six causal prior-close retest contexts per first-touch attempt
-> bounded active first-touch confluence membership
-> immutable confluence snapshot and overlap interval
-> DuckDB audits and exact unordered pattern queries
-> optional compact confluence feature set
-> D1-grouped chronological/walk-forward evaluation
-> offline-only reports and XGBoost candidates
```

## Scope

- **In scope**:
  - Derive immutable `M1`, `M15`, `M30`, `H1`, `H4`, and `D1` retest context
    from existing strict V9 facts.
  - Preserve one first touch per
    `(symbol, timeframe, active_bar_open, level)` and keep direction as the
    first-touch result.
  - Materialize causal active confluence members and one compact snapshot per
    anchor attempt.
  - Preserve mixed directions and unordered timeframe/level combinations such
    as `SELL:D1:R1 + BUY:M15:PP` or `SELL:D1:R1 + SELL:M30:PP`.
  - Expose exact pattern presence intervals from member trigger times and pivot
    window expiration times.
  - Add deterministic DuckDB/Parquet audits and an exact-pattern query path
    without enumerating the full pattern power set.
  - Add an opt-in compact confluence research feature set while preserving the
    current base dataset behavior.
  - Keep broker-outcome and admission target families separate.
  - Strengthen chronological grouping so overlapping D1 context and duplicate
    historical periods across runs cannot cross evaluation boundaries.
  - Compare the current base XGBoost lane with the new confluence lane using
    the same rows, fixed hyperparameters, grouped folds, and holdout.
  - Document support thresholds, leakage controls, performance, artifacts,
    residual risks, and offline-only approval boundaries.
- **Out of scope**:
  - Any `.mq5` or `.mqh` change, V9 TSV header change, new runtime event, V10
    schema, or new EA input.
  - `retest_sequence`, second/third retests, retrying consumed identities, or a
    later opposite-side attempt in the same pivot window/level.
  - Tick-by-tick path export, synthetic intrabar reconstruction, or inference
    of an earlier macro touch that is not present as a V9 first-touch attempt.
  - Mandatory `D1 -> H4 -> H1 -> M30 -> M15` ordering, adjacency rules, or
    direction agreement filters.
  - Exhaustive high-order itemset mining, automatic pattern promotion, or
    profit-ranked recipe generation.
  - Hyperparameter search, online learning, MT5 model loading, runtime scoring,
    trade filtering, pattern playback, deployment, or live rollout.
  - Treating denied/unfilled attempts as broker losses or manufacturing
    simulated TP-before-SL outcomes.
  - Migrating or relabeling schema V8 or the rejected `us30_test_run_1` export.
  - New Python test infrastructure or additional test-module count; extend the
    existing three modules and V9 fixture in place.
- **Fixed decisions**:
  - The canonical first-touch identity remains
    `(symbol, pivot_timeframe, active_bar_open_broker_time, level_id)`.
  - Direction and retest labels are observations, not identity components.
  - No `retest_sequence` column or semantic is introduced anywhere.
  - The anchor tested price is the immutable V9 `pivot_levels.trade_price` for
    the anchor attempt's own window/level.
  - `M1` context uses `signal_attempts.previous_m1_bid_close` and its captured
    previous-bar boundaries.
  - Macro contexts use the latest causal valid `pivot_windows` row for the
    context timeframe at the anchor trigger. The join requires
    `context_active_open <= trigger < context_terminal` and
    `context_source_close_boundary <= trigger`.
  - `BUY_RETEST` means the previous completed context close is above the anchor
    tested price; `SELL_RETEST` means it is below. `EQUAL_NEUTRAL` uses the
    fixed offline tolerance `1e-8`. Missing context is `UNAVAILABLE` and is
    never imputed.
  - The retest label is frozen at the anchor trigger and is never rewritten by
    later candles or prices.
  - For `M1`, the retest label must agree with the V9 first-touch direction.
    Macro labels may align with or oppose the anchor direction; both are valid
    research facts.
  - A macro retest context compares a macro previous close with the anchor's
    tested price. It is distinct from a macro first-touch member, which is an
    actual V9 attempt at that member's own timeframe and own level.
  - A confluence member is active on the half-open interval
    `[member_trigger_broker_time, member_window_terminal_broker_time)`.
  - Same-trigger candidate batches are simultaneous research facts. Every
    candidate sees all members in that frozen batch, before broker admission or
    send results.
  - Later first touches are not visible to earlier anchors. Expired member
    windows are not visible at or after their terminal boundary.
  - Confluence combinations are set-based and canonicalized only for stable
    storage/presentation. Canonical sort order is not a strategy sequence.
  - Admission status, broker checks, sends, fills, trailing, closes, duration,
    and profit remain labels/audit facts and cannot enter trigger-time feature
    columns.
  - Raw atomic tables retain all valid rows. Minimum support affects summaries
    and interpretation only; it never deletes source observations.
  - DuckDB prepares and audits data. XGBoost remains optional and
    `OFFLINE_RESEARCH_ONLY`.
  - Existing V9 exporter and broker execution behavior are presumed sufficient.
    If Sprint 1 disproves this, execution stops for a separate schema/runtime
    decision instead of silently expanding this plan.
- **Assumptions**:
  - The accepted natural Sprint 9 run is representative enough to validate
    derivation shape and performance, but not to approve profitability.
  - Every strict V9 attempt continues to have six existing Stoch Structure/%B
    feature rows; the new retest table is derived alongside, not substituted.
  - Broker time remains the only causal ordering clock. Analysis time remains
    calendar/export context and is not used for membership ordering.
  - The theoretical active-member bound is `5 pivot timeframes * 7 levels =
    35`; strict V9 identity validation makes any larger snapshot an error.
  - Generated dataset/audit/model artifacts can be rebuilt. Raw accepted V9
    run folders and tracked research notes remain immutable evidence.
  - Existing generated V9 datasets may require rebuilding to receive the new
    derived tables and manifest fields; raw V9 TSV compatibility is preserved.

## Research Contract

### Atomic Retest Context

`signal_retest_context` has one row per
`(run_id, config_id, signal_id, context_timeframe)` and exactly six rows for
every strict first-touch attempt.

| Context | Previous completed close | Causal identity |
| --- | --- | --- |
| `M1` | `previous_m1_bid_close` | Captured previous M1 bar open and close boundary from `signal_attempts` |
| `M15` | Matched `pivot_windows.source_close` | Latest valid M15 active window at trigger |
| `M30` | Matched `pivot_windows.source_close` | Latest valid M30 active window at trigger |
| `H1` | Matched `pivot_windows.source_close` | Latest valid H1 active window at trigger |
| `H4` | Matched `pivot_windows.source_close` | Latest valid H4 active window at trigger |
| `D1` | Matched `pivot_windows.source_close` | Latest valid D1 active window at trigger |

Required persisted columns include:

- anchor identity, symbol, anchor timeframe/level/direction, tested level price,
  trigger broker/analysis times, and offset;
- context timeframe, context window ID when applicable, context active open,
  source open/close boundary, terminal time, previous close, and source range;
- signed close delta to the tested level, retest type, alignment relation to the
  anchor (`ALIGNED`, `OPPOSED`, `NEUTRAL`, `UNAVAILABLE`), availability, and
  explicit invalid reason.

### Active Confluence Membership

`confluence_members` has one row per anchor/member relationship. It includes
the anchor itself for complete auditability and marks it with `is_anchor`; model
aggregates use peers separately so the anchor's existing base identity is not
double-counted.

Required persisted columns include:

- anchor signal/window identity and anchor trigger broker time;
- member signal/window identity, member timeframe, level, direction, trigger
  time, active open, and terminal time;
- deterministic member token `DIRECTION:TIMEFRAME:LEVEL`;
- `is_anchor`, `same_trigger_batch`, relation to anchor direction, member age
  in seconds, and the D1-based `research_group_id`;
- no admission, execution, fill, trailing, outcome, or profit facts.

`confluence_snapshots` has one row per anchor signal and includes:

- total member and peer counts;
- distinct active timeframe count;
- BUY/SELL peer counts;
- aligned/opposed/neutral peer counts;
- same-trigger peer count;
- bounded per-timeframe peer counts;
- canonical member-token set for audit display only;
- snapshot active-from and earliest active-until times;
- `research_group_id` and all anchor identity fields needed for joins.

### Exact Pattern Queries

Patterns are selected from atomic member rows, not stored as precomputed
permutations. For a requested token set:

```text
pattern_active_from  = max(member_trigger_broker_time)
pattern_active_until = min(member_window_terminal_broker_time)
```

The pattern is present only when
`pattern_active_from < pattern_active_until`. A query for `A + B` is identical
to `B + A`; trigger order may be reported as an audit fact but never required
for membership. Reports always expose both anchor support and distinct
`research_group_id` support to avoid treating correlated intraday anchors as
independent evidence.

### Compact Model Features

The opt-in confluence feature set may add only low-cardinality trigger-time
facts:

| Kind | Exact proposed columns |
| --- | --- |
| Categorical | `m15_retest_type`, `m30_retest_type`, `h1_retest_type`, `h4_retest_type`, `d1_retest_type` |
| Context counts | `macro_buy_retest_count`, `macro_sell_retest_count`, `macro_neutral_count` |
| Peer counts | `active_peer_count`, `active_timeframe_count`, `active_buy_peer_count`, `active_sell_peer_count`, `aligned_peer_count`, `opposed_peer_count`, `neutral_peer_count`, `same_trigger_peer_count` |
| Optional bounded counts | `active_m15_peer_count`, `active_m30_peer_count`, `active_h1_peer_count`, `active_h4_peer_count`, `active_d1_peer_count` |

The optional per-timeframe columns require an ablation justification; they are
not automatically enabled merely because they are available. No new Python
dependency is expected: the implementation uses the pinned standard library,
DuckDB, and existing NumPy/scikit-learn/XGBoost packages.

`M1` retest type remains persisted and audited but is excluded from the model
because it is an exact restatement of the existing first-touch direction.
Canonical pattern strings, signal IDs, window IDs, timestamps as raw IDs, and
any target/future fields are not model features.

## Named Resources

- **Project and skill instructions**:
  - `AGENTS.md`
  - `/home/loldlm/.codex/skills/planner/SKILL.md`
  - `/home/loldlm/.codex/skills/planner/references/execution-state.md`
  - `/home/loldlm/.codex/skills/token-saver-orchestrator/SKILL.md`
  - `/home/loldlm/.codex/skills/mql5-production-engineering/SKILL.md`
- **Hook safety resources**:
  - `/home/loldlm/.codex/skills/codex-hooks/README.md`
  - `/home/loldlm/.codex/skills/codex-hooks/hook-policy.md`
  - `/home/loldlm/.codex/skills/codex-hooks/scripts/active_plan_state.py`
  - `/home/loldlm/.codex/skills/codex-hooks/scripts/check_activation.py`
  - `/home/loldlm/.codex/skills/codex-hooks/tests/run_hook_tests.py`
  - `.codex-hook-state/active-plan-state.json` as ignored runtime state; never
    edit it manually or commit it
- **Offline implementation files**:
  - `tools/deterministic_signal_ml/retest_confluence.py` (new)
  - `tools/deterministic_signal_ml/query_confluence.py` (new, exact pattern
    query only)
  - `tools/deterministic_signal_ml/build_dataset.py`
  - `tools/deterministic_signal_ml/pivot_fractal_audit.py`
  - `tools/deterministic_signal_ml/schema_contract.py`
  - `tools/deterministic_signal_ml/report_writer.py`
  - `tools/deterministic_signal_ml/feature_encoder.py`
  - `tools/deterministic_signal_ml/model_config.py`
  - `tools/deterministic_signal_ml/validation_splits.py`
  - `tools/deterministic_signal_ml/train_model.py`
- **Tests and fixtures**:
  - `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`
  - `tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`
  - `tools/deterministic_signal_ml/tests/test_pivot_fractal_audit.py`
  - `tools/deterministic_signal_ml/tests/fixtures/schema_v9_pivot_fractal/`
  - Do not add a fourth test module or a second fixture schema tree.
- **Active documentation**:
  - `tools/deterministic_signal_ml/README.md`
  - `docs/workflows/pivot-fractal-statistics-flow.md`
  - `docs/workflows/pivot-fractal-offline-research-boundaries.md`
  - `docs/research/pivot-retest-confluence-offline-acceptance.md` (new during
    final acceptance)
  - `docs/plans/README.md`
- **Read-only runtime/schema references**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_signals/pivot_fractal_statistics_export.mqh`
  - `services/trading_signals/pivot_fractal_signal_detection.mqh`
  - `services/trading_signals/pivot_fractal_engine_state.mqh`
  - `services/trading_signals/pivot_context_features.mqh`
  - These files are not tracked scope. Any required edit is a blocker and a
    separate plan decision.
- **Accepted integration evidence**:
  - `/tmp/hft-grid-ai-sprint9-evidence/PivotFractalV9/runs/sprint9_natural_us30_final_20260112_20260725/`
  - `/tmp/hft-grid-ai-sprint9-evidence/datasets/sprint9_natural_us30_final/`
  - `docs/research/pivot-fractal-v9-vps-run-audit-2026-07-29.md`
  - If the temporary path is unavailable at execution time, restore or supply
    an equivalent natural strict V9 run before the final integration sprint.
- **Rejected evidence that must stay excluded**:
  - VPS run `us30_test_run_1`; it is censored and contains the documented
    pre-Sprint-9 causal defects.
- **Generated artifacts**:
  - `artifacts/datasets/<dataset_id>/signal_retest_context.parquet`
  - `artifacts/datasets/<dataset_id>/confluence_members.parquet`
  - `artifacts/datasets/<dataset_id>/confluence_snapshots.parquet`
  - Existing normalized V9 Parquet tables and `training_matrix.parquet`
  - `artifacts/audits/<audit_id>/retest_context_matrix.tsv`
  - `artifacts/audits/<audit_id>/confluence_snapshot_summary.tsv`
  - `artifacts/audits/<audit_id>/confluence_pair_support.tsv`
  - `artifacts/audits/<audit_id>/confluence_pair_outcomes.tsv`
  - Existing audit files, including the original same-tick `confluence.tsv`
  - `artifacts/models/<model_id>/` with `OFFLINE_RESEARCH_ONLY` manifests
- **Official external documentation reviewed**:
  - DuckDB ASOF joins:
    https://duckdb.org/docs/current/guides/sql_features/asof_join.html
  - DuckDB `FROM` and ASOF syntax constraints:
    https://duckdb.org/docs/current/sql/query_syntax/from.html
  - DuckDB Python relational/Parquet API:
    https://duckdb.org/docs/current/clients/python/relational_api.html
  - XGBoost Python introduction and `hist` training:
    https://xgboost.readthedocs.io/en/latest/python/python_intro.html
  - XGBoost scikit-learn API:
    https://xgboost.readthedocs.io/en/latest/python/python_api.html
  - scikit-learn `TimeSeriesSplit`:
    https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.TimeSeriesSplit.html

## Prerequisites And Hook-Safe Handoff

1. Start implementation only after explicit user authorization. This planning
   turn does not initialize or replace active-plan state.
2. Confirm the worktree is clean or intentionally rebased and record the exact
   baseline:

   ```bash
   rtk git status --short --branch
   rtk git log -1 --oneline
   ```

3. Re-run the hook readiness checks. Planning inspection found
   `features.hooks=true`, all configured hook commands pointing at the current
   `codex-hooks` scripts, and the bundled hook suite returning PASS:

   ```bash
   python /home/loldlm/.codex/skills/codex-hooks/tests/run_hook_tests.py all
   python /home/loldlm/.codex/skills/codex-hooks/scripts/check_activation.py
   ```

4. Inspect the current state before replacement:

   ```bash
   python /home/loldlm/.codex/skills/codex-hooks/scripts/active_plan_state.py \
     --workspace "$PWD" inspect
   ```

   The current ignored state is stale and references the former active path
   `docs/plans/pivot-fractal-engine-schema-v9-plan.md`, while the completed plan
   now exists at
   `docs/plans/archive/pivot-fractal-engine-schema-v9-2026-07-29/pivot-fractal-engine-schema-v9-plan.md`.
   Do not edit or delete the JSON manually.

5. After implementation is authorized, deliberately replace the stale state
   with Sprint 1 of this plan:

   ```bash
   python /home/loldlm/.codex/skills/codex-hooks/scripts/active_plan_state.py \
     --workspace "$PWD" init --replace \
     --plan-path docs/plans/pivot-retest-confluence-offline-research-plan.md \
     --sprint-number 1 \
     --sprint-title "Derive Causal Retest Context" \
     --next-action "implement Sprint 1" \
     --continuation-owner hook

   python /home/loldlm/.codex/skills/codex-hooks/scripts/active_plan_state.py \
     --workspace "$PWD" inspect
   ```

   Use `--continuation-owner goal` only if a native Goal is actually active at
   implementation start. Never infer Goal ownership from a compact reminder.

6. After each sprint implementation, validation, commit, blocker, and advance,
   update state through the script. Never let hooks create commits or deploys.
7. Confirm `.venv` resolves the pinned DuckDB, NumPy, scikit-learn, and XGBoost
   dependencies from `tools/deterministic_signal_ml/requirements.txt`.
8. Confirm a natural strict V9 run is available for Sprint 5. The accepted
   Sprint 9 run is preferred; do not substitute the rejected diagnostic run.
9. No MetaEditor compile or Strategy Tester rerun is scheduled because this
   plan has no MQL5/runtime scope. If tracked `.mq5`/`.mqh` files change, stop
   and re-plan with a final `0 errors, 0 warnings` compile and human tester gate.

## Dependencies And Parallel Work

- Sprint order is strict: context semantics precede membership, membership
  precedes audits, audits precede model features, and all contracts precede
  natural-run acceptance.
- Existing V9 validation must remain fail-closed before any derived table is
  built. Derived logic may not compensate for a malformed source run.
- Within Sprint 3, report rendering and exact-query CLI work may proceed after
  the membership schema is frozen, but both must use the same canonical token
  and support definitions.
- Within Sprint 4, feature encoding and grouped-split changes may be developed
  independently after the research feature columns and D1 group identity are
  frozen, then reconciled before the single sprint commit.
- No parallel work may introduce another commit inside a sprint. Every sprint
  integrates all tracked changes, validates once, and creates exactly one
  sprint-specific commit.
- If Sprint 1 finds missing causal facts in strict V9, mark the hook state
  blocked, record the exact missing fact, and request a separate schema/runtime
  decision. Do not continue with synthetic reconstruction.

## Sprint 1: Derive Causal Retest Context

**Goal**: Produce a deterministic six-row retest-context table for every strict
V9 first-touch attempt using existing source facts only.

**Dependencies**: Prerequisites complete; active-plan state safely replaced and
initialized for Sprint 1.

**Tracked scope**:

- `tools/deterministic_signal_ml/retest_confluence.py` (new)
- `tools/deterministic_signal_ml/build_dataset.py`
- `tools/deterministic_signal_ml/report_writer.py`
- `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`
- `tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`
- `tools/deterministic_signal_ml/tests/fixtures/schema_v9_pivot_fractal/` only if
  the existing fixture must gain causal macro windows
- `docs/plans/README.md` to identify this plan as the active implementation plan

**Proposed commit**: `feat: derive causal pivot retest context offline`

**Demo/Validation**:

```bash
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
rtk test .venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root /tmp/hft-grid-ai-sprint9-evidence/PivotFractalV9/runs \
  --run-id sprint9_natural_us30_final_20260112_20260725 \
  --validate-only
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root /tmp/hft-grid-ai-sprint9-evidence/PivotFractalV9/runs \
  --run-id sprint9_natural_us30_final_20260112_20260725 \
  --dataset-id sprint1_retest_context_acceptance \
  --output-root artifacts/datasets \
  --target-family broker_outcome \
  --overwrite
rtk git diff --check
```

Expected integration result: `298,296` retest rows for `49,716` attempts, six
unique contexts per signal, zero unavailable macro contexts, zero future or
expired matches, and exact M1 retest/direction parity.

**Rollback point**: Baseline `67c4398` or the recorded rebased baseline. Revert
the single Sprint 1 commit to remove the derived context layer; raw V9 exports
remain untouched.

### Task 1.1: Freeze The Retest Vocabulary And Grain

- **Location**: `tools/deterministic_signal_ml/retest_confluence.py`
- **Description**: Define context order, timeframe ranks, equality tolerance,
  retest/alignment tokens, derived table columns, and one pure classifier for a
  prior close versus an anchor tested price. Keep source-schema constants in
  `schema_contract.py`; do not redefine or loosen V9 headers/keys.
- **Dependencies**: Current V9 schema constants and first-touch semantics.
- **Acceptance criteria**:
  - The only retest types are `BUY_RETEST`, `SELL_RETEST`,
    `EQUAL_NEUTRAL`, and `UNAVAILABLE`.
  - The derived primary key is
    `(run_id, config_id, signal_id, context_timeframe)`.
  - No sequence, outcome, execution, trailing, or profit field appears in the
    derived context contract.
- **Validation**:
  - Focused unit tests for above, below, equality within `1e-8`, and missing
    context.
  - Exact identifier sweep for `retest_sequence` must return no active code
    additions.
- **Rollback**: Revert Sprint 1.

### Task 1.2: Build M1 And Macro Contexts Causally

- **Location**: `tools/deterministic_signal_ml/retest_confluence.py`,
  `tools/deterministic_signal_ml/build_dataset.py`
- **Description**: Union direct M1 attempt context with five macro contexts
  matched by DuckDB `ASOF LEFT JOIN`. Match on run/config/symbol/timeframe and
  latest active-open not after the trigger, then reject a match unless the
  trigger is strictly before terminal and the source close boundary is causal.
  Preserve context window/source identities for audit.
- **Dependencies**: Task 1.1 and strict source validation.
- **Acceptance criteria**:
  - Every strict fixture attempt has exactly six ordered context rows.
  - M1 context uses only captured M1 fields; no `pivot_windows` approximation.
  - Macro context never uses a future active window, expired window, or
    non-valid source row.
  - Macro context may oppose anchor direction without becoming invalid.
  - Missing context remains `UNAVAILABLE` with an explicit reason.
- **Validation**:
  - Positive mixed-direction fixture.
  - Negative future-active-open, expired-terminal, missing-window, and
    equal-close cases.
  - DuckDB query confirms the accepted natural run has five valid macro matches
    per attempt.
- **Rollback**: Revert Sprint 1.

### Task 1.3: Persist Context And Quality Metadata

- **Location**: `tools/deterministic_signal_ml/build_dataset.py`,
  `tools/deterministic_signal_ml/report_writer.py`
- **Description**: Materialize `signal_retest_context`, include it in Parquet
  output/counts, and add manifest/quality fields for policy version, row count,
  context completeness, retest distribution, causal failures, and source V9
  feature-set identity. Preserve current normalized source tables and base
  `training_matrix` behavior.
- **Dependencies**: Task 1.2.
- **Acceptance criteria**:
  - Existing build commands still produce the current base training matrix.
  - Dataset manifests distinguish source V9 facts from derived retest context.
  - A missing or duplicate context blocks a strict derived dataset rather than
    silently dropping the signal.
  - Repeated builds from identical source rows produce identical derived row
    ordering and values, excluding generated timestamps in metadata.
- **Validation**:
  - Existing fixture builds both `broker_outcome` and `admission` lanes.
  - Parquet key/row-count and deterministic ordering assertions.
  - Dataset quality reports zero context errors for the accepted run.
- **Rollback**: Revert Sprint 1 and rebuild any ignored dataset artifacts with
  the prior code revision.

### Task 1.4: Mark The Plan Active Without Expanding Runtime Scope

- **Location**: `docs/plans/README.md`
- **Description**: Link this plan as the active implementation plan and state
  that it is offline-only. Keep the completed V9 engine plan archived and do
  not rewrite archived evidence.
- **Dependencies**: Tasks 1.1-1.3 ready for the Sprint 1 commit.
- **Acceptance criteria**:
  - The active plan link resolves.
  - No documentation suggests a runtime model, V10 exporter, or live rollout.
- **Validation**:
  - `rg -n "pivot-retest-confluence|active|offline" docs/plans/README.md`
- **Rollback**: Revert Sprint 1.

### Sprint 1 Gate

- [ ] All Sprint 1 tasks complete.
- [ ] Strict V9 source validation still fails closed before derivation.
- [ ] Six-context, causality, key, and determinism validation passes.
- [ ] Accepted natural-run context counts and distributions are recorded.
- [ ] `git diff --check` passes and residual risks are documented.
- [ ] Hook state records `sprint_status=implemented`, then
  `validation_status=passed`.
- [ ] Exactly one Sprint 1 commit is created with the proposed message.
- [ ] Hook state records `commit_status=committed` and the commit hash is the
  Sprint 1 rollback point.
- [ ] Sprint 2 has not started before this gate completes.

## Sprint 2: Materialize Bounded First-Touch Confluence

**Goal**: Build causal anchor/member and compact snapshot tables with exact
window lifecycles, frozen same-trigger batches, and bounded linear behavior.

**Dependencies**: Sprint 1 gate complete.

**Tracked scope**:

- `tools/deterministic_signal_ml/retest_confluence.py`
- `tools/deterministic_signal_ml/build_dataset.py`
- `tools/deterministic_signal_ml/report_writer.py`
- `tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`
- `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`

**Proposed commit**: `feat: materialize causal pivot confluence snapshots`

**Demo/Validation**:

```bash
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
rtk test .venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
/usr/bin/time -f 'elapsed=%e max_rss_kb=%M' \
  .venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root /tmp/hft-grid-ai-sprint9-evidence/PivotFractalV9/runs \
  --run-id sprint9_natural_us30_final_20260112_20260725 \
  --dataset-id sprint2_confluence_acceptance \
  --output-root artifacts/datasets \
  --target-family broker_outcome \
  --overwrite
rtk git diff --check
```

Expected integration result on the accepted run: `384,086` member rows,
`49,716` snapshots, maximum `29` active members and never more than `35`, zero
future/expired members, and exact parity with a simple reference interval join
on the compact fixture.

**Rollback point**: Sprint 1 commit. Revert Sprint 2 to retain retest context
while removing confluence membership/snapshots.

### Task 2.1: Implement A Frozen Same-Time Event Sweep

- **Location**: `tools/deterministic_signal_ml/retest_confluence.py`
- **Description**: Read only validated attempt/window columns, group by
  `(run_id, config_id, symbol)`, sort by broker trigger and stable signal ID,
  advance at most one active window per pivot timeframe, and process all
  identical-trigger attempts as one frozen batch. Add the batch to its active
  window member lists before emitting every anchor snapshot so same-time peers
  see identical membership.
- **Dependencies**: Sprint 1 context contract and strict unique identities.
- **Acceptance criteria**:
  - The algorithm is bounded by attempts times at most `35` active members and
    does not execute a full attempt-by-attempt interval join.
  - Members satisfy `member_trigger <= anchor_trigger < member_terminal`.
  - All and only same-trigger peers are visible simultaneously.
  - Later attempts and terminal-boundary-expired attempts are absent.
  - Denied and send-failed attempts remain valid first-touch members; their
    later admission/execution facts are not copied into membership.
- **Validation**:
  - Fixture parity against a simple reference interval join.
  - Negative earlier-anchor/later-member and exact-terminal cases.
  - Same-trigger batch with mixed directions/timeframes.
- **Rollback**: Revert Sprint 2.

### Task 2.2: Materialize Member And Snapshot Tables

- **Location**: `tools/deterministic_signal_ml/retest_confluence.py`,
  `tools/deterministic_signal_ml/build_dataset.py`
- **Description**: Create `confluence_members` and `confluence_snapshots` with
  exact schemas from the research contract. Use deterministic timeframe/level
  ranks and canonical tokens for presentation only. Derive peer counts without
  double-counting the anchor.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - Every anchor has exactly one `is_anchor=true` member row.
  - No duplicate anchor/member key exists.
  - Snapshot member count equals its member-row count; peer count is member
    count minus one.
  - Mixed BUY/SELL and non-adjacent timeframe combinations are preserved.
  - Canonical token order is deterministic and does not imply trigger order.
  - Snapshot earliest active-until is strictly after the anchor trigger.
- **Validation**:
  - Key, count, canonical-order, and interval assertions in existing tests.
  - DuckDB checks for duplicates, future members, expired members, and count
    mismatches return zero.
- **Rollback**: Revert Sprint 2.

### Task 2.3: Define Leakage Group Identity

- **Location**: `tools/deterministic_signal_ml/retest_confluence.py`,
  `tools/deterministic_signal_ml/build_dataset.py`
- **Description**: Derive `research_group_id` from symbol and the causal D1
  context active-open broker time, independent of `run_id`. This groups the
  same market day across repeated runs and contains every smaller active pivot
  window used by the snapshot.
- **Dependencies**: Sprint 1 D1 context and Task 2.2 snapshot output.
- **Acceptance criteria**:
  - Every complete anchor has one non-null group ID.
  - Repeated runs of the same symbol/D1 active open share a group ID.
  - Different symbols or D1 active opens do not collide.
  - Group ID is retained for splits/audits but is not a model feature.
- **Validation**:
  - Cross-run duplicate-date fixture assertions.
  - Exact feature-column exclusion check.
- **Rollback**: Revert Sprint 2.

### Task 2.4: Enforce Performance And Row Bounds

- **Location**: `tools/deterministic_signal_ml/report_writer.py`, existing test
  modules
- **Description**: Add quality fields for membership rows, maximum/mean active
  members, theoretical-bound violations, future/expired member violations, and
  derivation duration. Fail the build on any bound or causal violation.
- **Dependencies**: Tasks 2.1-2.3.
- **Acceptance criteria**:
  - Maximum active members cannot exceed `35`.
  - The accepted-run sweep target is at most `5` seconds on the same workstation
    used for the planning benchmark; slower environments must still show
    bounded scaling and no quadratic join in the implementation.
  - Output size and peak RSS are recorded, not hidden.
- **Validation**:
  - Timed accepted-run build and quality JSON inspection.
  - Source inspection confirms no broad interval self-join is used for member
    materialization.
- **Rollback**: Revert Sprint 2.

### Sprint 2 Gate

- [ ] All Sprint 2 tasks complete.
- [ ] Reference-fixture parity and same-trigger batch tests pass.
- [ ] Accepted-run member/snapshot counts and causal checks pass.
- [ ] Performance and theoretical-bound evidence is recorded.
- [ ] `git diff --check` passes and residual risks are documented.
- [ ] Hook state records implementation and validation transitions.
- [ ] Exactly one Sprint 2 commit is created with the proposed message.
- [ ] Hook state records the commit and Sprint 2 rollback point.
- [ ] Sprint 3 has not started before this gate completes.

## Sprint 3: Add Unordered Pattern Queries And Audits

**Goal**: Make dynamic first-touch combinations easy to filter and evaluate in
DuckDB without creating rigid runtime recipes or an exhaustive pattern miner.

**Dependencies**: Sprint 2 gate complete; member and snapshot schemas frozen.

**Tracked scope**:

- `tools/deterministic_signal_ml/query_confluence.py` (new)
- `tools/deterministic_signal_ml/pivot_fractal_audit.py`
- `tools/deterministic_signal_ml/report_writer.py`
- `tools/deterministic_signal_ml/tests/test_pivot_fractal_audit.py`
- `tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`

**Proposed commit**: `feat: audit unordered pivot retest confluence`

**Demo/Validation**:

```bash
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
rtk test .venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id sprint2_confluence_acceptance \
  --audit-id sprint3_confluence_audit \
  --minimum-group-support 20 \
  --overwrite
.venv/bin/python tools/deterministic_signal_ml/query_confluence.py \
  --dataset-id sprint2_confluence_acceptance \
  --member SELL:PERIOD_D1:R1 \
  --member BUY:PERIOD_M15:PP \
  --minimum-group-support 20
rtk git diff --check
```

Expected result: exact token-set matching is order-independent, mixed directions
are retained, pattern intervals are causal, support is counted at both anchor
and D1 research-group grain, and outcome metrics use broker-confirmed rows only.

**Rollback point**: Sprint 2 commit. Revert Sprint 3 to remove the query/audit
surface while retaining atomic derived Parquet tables.

### Task 3.1: Add Exact Set-Based Pattern Filtering

- **Location**: `tools/deterministic_signal_ml/query_confluence.py`
- **Description**: Add a small DuckDB CLI that accepts repeated validated
  `DIRECTION:TIMEFRAME:LEVEL` tokens, optionally accepts an `--anchor-member`
  token to identify the focal signal, matches anchors containing the complete
  set, and reports interval, support, and identity rows. Do not accept a
  sequence or infer missing members. Use parameterized values or safely quoted
  literals; reject malformed tokens and path traversal.
- **Dependencies**: Sprint 2 member table and canonical vocabulary.
- **Acceptance criteria**:
  - Reversing CLI member order returns the same anchors and intervals.
  - An optional anchor-member filter narrows the focal signal without imposing
    an order on the remaining requested members.
  - `D1 + M30`, `D1 + M15`, and mixed BUY/SELL sets are valid.
  - Duplicate requested tokens are normalized without changing semantics.
  - Unknown direction/timeframe/level tokens fail closed.
  - Results never include an anchor before all requested members have triggered
    or at/after any requested member has expired.
- **Validation**:
  - Deterministic fixture queries for unordered, mixed, missing, duplicate, and
    expired patterns.
  - CLI path/ID validation tests in an existing test module.
- **Rollback**: Revert Sprint 3.

### Task 3.2: Extend The Audit With Retest And Confluence Outputs

- **Location**: `tools/deterministic_signal_ml/pivot_fractal_audit.py`
- **Description**: Load and integrity-check the three derived Parquet tables.
  Preserve all current audit outputs, including same-tick `confluence.tsv`, and
  add retest distribution, snapshot distribution, canonical pair support, and
  pair broker-outcome reports. Keep admission and broker-outcome summaries
  separate.
- **Dependencies**: Task 3.1 vocabulary and Sprint 2 schemas.
- **Acceptance criteria**:
  - `retest_context_matrix.tsv` reports context timeframe, retest type, anchor
    direction relation, anchor support, and group support.
  - `confluence_snapshot_summary.tsv` reports bounded counts without outcome
    fields.
  - `confluence_pair_support.tsv` is set-based and reports anchor plus group
    support before any profitability metric.
  - `confluence_pair_outcomes.tsv` uses only broker-confirmed outcome anchors
    and reports outcome support, profitable count/rate, Wilson 95% interval,
    mean/median/total realized profit, and mean duration.
  - Denied attempts remain admission facts and are not classified as losses.
- **Validation**:
  - Existing structural-break-even versus realized-profit test continues to
    pass.
  - New exact expected TSV tests and repeated-audit determinism checks.
  - Orphan/duplicate/causal corruption fails before report generation.
- **Rollback**: Revert Sprint 3.

### Task 3.3: Apply Explicit Minimum-Support Rules

- **Location**: `tools/deterministic_signal_ml/query_confluence.py`,
  `tools/deterministic_signal_ml/pivot_fractal_audit.py`,
  `tools/deterministic_signal_ml/report_writer.py`
- **Description**: Preserve all atomic rows and raw support counts. Apply the
  recorded `--minimum-group-support` only to filtered/ranked summary sections;
  never delete source rows. Sort default reports by support and stable token,
  not by realized profit.
- **Dependencies**: Tasks 3.1-3.2.
- **Acceptance criteria**:
  - The threshold and both pre/post-filter counts are written to audit metadata.
  - Low-support patterns remain queryable and visibly marked exploratory.
  - No automatic best-pattern, threshold, or trading recommendation is emitted.
- **Validation**:
  - Boundary tests immediately below/at the threshold.
  - Report review confirms support-first deterministic ordering.
- **Rollback**: Revert Sprint 3.

### Sprint 3 Gate

- [ ] All Sprint 3 tasks complete.
- [ ] Exact-pattern order invariance and mixed-direction tests pass.
- [ ] Audit integrity, support, confidence interval, and target-family tests pass.
- [ ] Existing audit files and semantics remain available.
- [ ] `git diff --check` passes and residual risks are documented.
- [ ] Hook state records implementation and validation transitions.
- [ ] Exactly one Sprint 3 commit is created with the proposed message.
- [ ] Hook state records the commit and Sprint 3 rollback point.
- [ ] Sprint 4 has not started before this gate completes.

## Sprint 4: Add An Opt-In Confluence XGBoost Lane

**Goal**: Add a compact derived research feature set and leakage-safe grouped
splits while leaving the current base dataset/model lane as the default.

**Dependencies**: Sprint 3 gate complete; atomic/audit contracts stable.

**Tracked scope**:

- `tools/deterministic_signal_ml/retest_confluence.py`
- `tools/deterministic_signal_ml/build_dataset.py`
- `tools/deterministic_signal_ml/report_writer.py`
- `tools/deterministic_signal_ml/feature_encoder.py`
- `tools/deterministic_signal_ml/model_config.py`
- `tools/deterministic_signal_ml/validation_splits.py`
- `tools/deterministic_signal_ml/train_model.py`
- `tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`
- `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`

**Proposed commit**: `feat: add opt-in pivot confluence research features`

**Demo/Validation**:

```bash
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
rtk test .venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root /tmp/hft-grid-ai-sprint9-evidence/PivotFractalV9/runs \
  --run-id sprint9_natural_us30_final_20260112_20260725 \
  --dataset-id sprint4_confluence_features \
  --output-root artifacts/datasets \
  --target-family broker_outcome \
  --research-feature-set-id pivot_first_touch_confluence_v1 \
  --overwrite
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id sprint4_confluence_features \
  --model-id sprint4_confluence_smoke \
  --target-family broker_outcome \
  --overwrite
rtk git diff --check
```

Expected result: the opt-in dataset contains only approved trigger-time base
plus compact confluence features, uses D1 research-group chronological splits,
and emits only `OFFLINE_RESEARCH_ONLY` model artifacts. The existing command
without `--research-feature-set-id` remains the base lane.

**Rollback point**: Sprint 3 commit. Revert Sprint 4 to retain all DuckDB audit
capabilities while removing confluence fields from model training.

### Task 4.1: Define A Separate Derived Feature Contract

- **Location**: `tools/deterministic_signal_ml/retest_confluence.py`,
  `tools/deterministic_signal_ml/build_dataset.py`
- **Description**: Keep schema V9 source feature ID
  `schema_v9_pivot_fractal_xgb` unchanged. Add offline research feature ID
  `pivot_first_touch_confluence_v1`, exact categorical/numeric columns, and a
  CLI selector whose default preserves the current base lane.
- **Dependencies**: Sprint 3 frozen derived schemas.
- **Acceptance criteria**:
  - Dataset manifests record both source and research feature-set IDs.
  - Base feature columns remain exact and default behavior remains unchanged.
  - The confluence set excludes M1 retest type as a duplicate of direction,
    canonical pattern tokens, IDs, target fields, and every future-only field.
  - No high-cardinality discovered pattern becomes a model column.
- **Validation**:
  - Exact base/confluence feature-list tests.
  - Intersection with `FUTURE_ONLY_COLUMNS`, target columns, and identifier
    denylist is empty.
- **Rollback**: Revert Sprint 4.

### Task 4.2: Materialize Compact Trigger-Time Aggregates

- **Location**: `tools/deterministic_signal_ml/build_dataset.py`,
  `tools/deterministic_signal_ml/retest_confluence.py`,
  `tools/deterministic_signal_ml/report_writer.py`
- **Description**: Join one retest pivot and one confluence snapshot to each
  anchor training row. Add only approved macro retest types and bounded counts.
  Keep target projections exactly as the current broker-outcome/admission lanes.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - One training row remains one anchor attempt in its target family.
  - No row multiplication occurs from six context or many member rows.
  - All confluence values are available at the anchor trigger.
  - Missing derived facts fail strict confluence-dataset creation rather than
    receiving a favorable default.
- **Validation**:
  - Training row counts match the corresponding base lane.
  - Focused SQL checks for one-to-one joins and null feature counts.
  - Base and confluence manifests identify the same source runs/target rows.
- **Rollback**: Revert Sprint 4.

### Task 4.3: Strengthen Chronological Grouping

- **Location**: `tools/deterministic_signal_ml/validation_splits.py`,
  `tools/deterministic_signal_ml/train_model.py`
- **Description**: Use `research_group_id` for confluence datasets. Keep all
  rows for the same symbol/D1 active broker window together across runs, sort
  groups by first broker trigger, retain a group gap, and record exact group
  ranges in fold metadata. Preserve the current pivot-window grouping for base
  datasets unless the dataset explicitly declares the new group policy.
- **Dependencies**: Sprint 2 group identity and Task 4.2 matrix.
- **Acceptance criteria**:
  - No research group crosses train/test or train/holdout boundaries.
  - Duplicate same-symbol/D1 periods across run IDs stay in one partition.
  - Every active confluence member window for an anchor is contained within its
    research group.
  - Split metadata names group columns, gap, time ranges, row counts, and group
    counts.
- **Validation**:
  - Cross-run duplicate-period and overlapping-window split tests.
  - Fold/holdout disjointness assertions at row and group grain.
- **Rollback**: Revert Sprint 4.

### Task 4.4: Train Dynamically From The Manifest Feature Contract

- **Location**: `tools/deterministic_signal_ml/feature_encoder.py`,
  `tools/deterministic_signal_ml/model_config.py`,
  `tools/deterministic_signal_ml/train_model.py`
- **Description**: Read and validate the exact feature column list from the
  dataset manifest, keep fixed `hist` XGBoost configs and seeds, and record the
  source/research feature IDs plus grouped split policy in model artifacts. Do
  not add hyperparameter search or runtime export.
- **Dependencies**: Tasks 4.1-4.3.
- **Acceptance criteria**:
  - Both base and confluence datasets can train with their exact manifest
    columns.
  - Minimum training rows and minority-class support remain enforced.
  - Model manifests remain `OFFLINE_RESEARCH_ONLY` and
    `runtime_artifact_emitted=false`.
  - Model files are never copied to MQL5/Common Files or deployment paths.
- **Validation**:
  - Base and confluence smoke training on accepted data.
  - Unknown/mismatched feature IDs and manifest columns fail closed.
  - Encoder unseen-category behavior remains deterministic.
- **Rollback**: Revert Sprint 4 and rebuild ignored generated models with the
  prior revision if needed.

### Sprint 4 Gate

- [ ] All Sprint 4 tasks complete.
- [ ] Default base dataset/model behavior remains intact.
- [ ] Confluence feature denylist and one-row-per-anchor checks pass.
- [ ] D1 grouped chronological/walk-forward split tests pass.
- [ ] Base and confluence smoke models remain offline-only.
- [ ] `git diff --check` passes and residual risks are documented.
- [ ] Hook state records implementation and validation transitions.
- [ ] Exactly one Sprint 4 commit is created with the proposed message.
- [ ] Hook state records the commit and Sprint 4 rollback point.
- [ ] Sprint 5 has not started before this gate completes.

## Sprint 5: Run Natural-Data Acceptance, Ablation, And Closeout

**Goal**: Validate the complete offline pipeline on accepted natural V9 data,
measure cost, compare base and confluence models without tuning, document the
result, and close the plan without implying runtime approval.

**Dependencies**: Sprint 4 gate complete; accepted natural run available.

**Tracked scope**:

- `tools/deterministic_signal_ml/README.md`
- `docs/workflows/pivot-fractal-statistics-flow.md`
- `docs/workflows/pivot-fractal-offline-research-boundaries.md`
- `docs/research/pivot-retest-confluence-offline-acceptance.md` (new)
- `docs/plans/README.md`
- This plan file for final status/evidence updates while it remains at its
  active hook path

**Proposed commit**: `docs: validate pivot retest confluence research`

**Demo/Validation**:

```bash
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
rtk test .venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root /tmp/hft-grid-ai-sprint9-evidence/PivotFractalV9/runs \
  --run-id sprint9_natural_us30_final_20260112_20260725 \
  --dataset-id pivot_retest_base_acceptance \
  --target-family broker_outcome \
  --overwrite
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root /tmp/hft-grid-ai-sprint9-evidence/PivotFractalV9/runs \
  --run-id sprint9_natural_us30_final_20260112_20260725 \
  --dataset-id pivot_retest_confluence_acceptance \
  --target-family broker_outcome \
  --research-feature-set-id pivot_first_touch_confluence_v1 \
  --overwrite
.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id pivot_retest_confluence_acceptance \
  --audit-id pivot_retest_confluence_acceptance \
  --minimum-group-support 20 \
  --overwrite
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id pivot_retest_base_acceptance \
  --model-id pivot_retest_base_acceptance \
  --target-family broker_outcome \
  --overwrite
.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id pivot_retest_confluence_acceptance \
  --model-id pivot_retest_confluence_acceptance \
  --target-family broker_outcome \
  --overwrite
rtk git status --short --branch
rtk git diff --check
```

**Rollback point**: Sprint 4 commit. Revert Sprint 5 to restore prior active
documentation while retaining the implemented offline tooling. Generated
artifacts remain ignored and reproducible.

### Task 5.1: Re-run Full Strict V9 And Derived Integrity

- **Location**: Generated accepted dataset/audit artifacts and
  `docs/research/pivot-retest-confluence-offline-acceptance.md`
- **Description**: Validate the natural V9 source first, build both base and
  confluence datasets from the same run, and record exact source/derived row
  counts, distributions, causal checks, group counts, output bytes, and
  right-censored outcome handling.
- **Dependencies**: Sprint 4 complete.
- **Acceptance criteria**:
  - Source still reports schema `9`, `PIVOT_FRACTAL_V1`, natural completion,
    export OK, and strict referential integrity.
  - Retest contexts equal six times attempts with zero unavailable macro rows
    for the accepted run.
  - Member/snapshot counts match the frozen Sprint 2 policy and no count exceeds
    `35`.
  - The twelve documented interval-boundary open positions remain right
    censored and are not relabeled as losses.
  - Rejected `us30_test_run_1` is absent from all source manifests.
- **Validation**:
  - Dataset quality JSON, audit metadata, Parquet SQL checks, and source manifest
    review.
- **Rollback**: Revert Sprint 5 documentation; preserve generated evidence until
  the review is complete.

### Task 5.2: Benchmark Base Versus Derived Cost

- **Location**: Acceptance research note and generated manifest/quality files
- **Description**: Run paired builds on the same machine, input run, target
  family, and output filesystem. Record wall time, peak RSS, Parquet bytes, row
  counts, context ASOF duration, confluence sweep duration, and total overhead.
  Explain any material regression before closeout.
- **Dependencies**: Task 5.1.
- **Acceptance criteria**:
  - The implementation contains no full-history quadratic interval join.
  - Context and membership stages retain bounded scaling and the member bound.
  - On the current benchmark workstation, macro context remains within `5`
    seconds and membership within `5` seconds for the accepted six-month run.
  - Total overhead and additional disk bytes are explicitly reported; no
    performance claim is made without paired evidence.
- **Validation**:
  - `/usr/bin/time` paired commands and manifest duration/byte checks.
- **Rollback**: If the budget fails, fix within uncommitted Sprint 5 or revert
  to Sprint 4; do not weaken causal or completeness checks for speed.

### Task 5.3: Run A Fixed Baseline-Confluence Ablation

- **Location**: Generated model artifacts and acceptance research note
- **Description**: Train the base and confluence lanes on identical target rows,
  fixed XGBoost settings/seeds, and the same D1 research-group fold assignment.
  Report each fold and final holdout, not only aggregate best metrics. Do not
  tune against the holdout or promote features automatically.
- **Dependencies**: Tasks 5.1-5.2.
- **Acceptance criteria**:
  - Row IDs and target arrays are identical between ablation lanes.
  - Fold/group assignments are identical and disjoint.
  - Classification reports balanced accuracy, ROC AUC, average precision,
    precision, recall, and log loss where defined.
  - Broker-outcome regression reports MAE, RMSE, mean profit, and correlation.
  - The note reports fold consistency, support, and degradation as plainly as
    any improvement.
  - No single-run lift is described as production alpha or runtime approval.
- **Validation**:
  - Manifest/prediction joins and metric comparison script/query recorded in
    the research note.
- **Rollback**: Revert Sprint 5 documentation; generated models remain offline
  and may be discarded by exact model ID.

### Task 5.4: Finalize Operator Documentation And Boundaries

- **Location**: `tools/deterministic_signal_ml/README.md`,
  `docs/workflows/pivot-fractal-statistics-flow.md`,
  `docs/workflows/pivot-fractal-offline-research-boundaries.md`,
  `docs/research/pivot-retest-confluence-offline-acceptance.md`,
  `docs/plans/README.md`, this plan file
- **Description**: Document commands, table grains, label semantics, exact
  pattern querying, support/group rules, artifact paths, split policy,
  performance, and model boundary. Record final commit/rollback points and mark
  the plan complete after all gates pass.
- **Dependencies**: Tasks 5.1-5.3.
- **Acceptance criteria**:
  - Documentation distinguishes macro side context from actual first-touch
    confluence members.
  - It states that support/resistance roles are dynamic and mixed directions
    are expected, not failures.
  - It states that combinations are unordered and no `retest_sequence` exists.
  - It states DuckDB is the analysis layer and XGBoost remains optional/offline.
  - It contains no runtime filter, deployment, or live-rollout command.
  - The plan remains at its active path until hook completion; do not move it
    while hook state still validates this path.
- **Validation**:
  - Exact terminology/reference sweeps, link review, `git diff --check`, final
    `rtk git status`, and commit history review.
- **Rollback**: Revert Sprint 5.

### Sprint 5 Gate

- [ ] All Sprint 5 tasks complete.
- [ ] Full source, derived, audit, performance, and ablation evidence is recorded.
- [ ] No MQL5/runtime/schema file changed; otherwise this gate fails and a new
  compile/tester plan is required.
- [ ] Documentation and research approval boundaries are accurate.
- [ ] `git diff --check` passes and residual risks are current.
- [ ] Hook state records implementation and validation transitions.
- [ ] Exactly one Sprint 5 commit is created with the proposed message.
- [ ] Hook state records `commit_status=committed` and the rollback point.
- [ ] `active_plan_state.py complete` succeeds only after validation and commit
  gates pass.
- [ ] The completed plan is not moved while active hook state points to it.

## Testing Strategy

- **Unit**:
  - Retest vocabulary, equality tolerance, alignment, token parsing, canonical
    ordering, interval math, event-batch behavior, support thresholds, Wilson
    interval math, and feature denylist.
- **Integration**:
  - Strict V9 validation followed by typed dataset build, six-context output,
    member/snapshot materialization, Parquet write/read, audit generation,
    exact pattern query, model matrix, encoder, grouped splits, and training.
- **Negative/fail-closed**:
  - Future context window, expired context/member, missing macro context,
    duplicate context/member, later first touch visible early, terminal-boundary
    overlap, malformed token, path traversal, target/future feature leakage,
    incompatible feature manifest, orphan outcome, and rejected source run.
- **Chronological leakage**:
  - Same symbol/D1 broker window across runs stays in one partition; no
    research group crosses fold or holdout; all confluence members are causal
    and contained in the anchor group.
- **Statistical/research**:
  - Report anchor and D1 group support, confidence intervals, per-fold results,
    final holdout, unchanged row/target parity for ablation, and no automatic
    feature/pattern promotion.
- **Performance**:
  - Paired base/derived builds on the accepted six-month run, bounded maximum
    members, stage durations, wall time, peak RSS, and Parquet bytes. Inspect
    implementation/plan to ensure no quadratic full-history self-join.
- **Security/data handling**:
  - Dataset/audit/model IDs cannot escape configured roots; SQL values are
    safely parameterized/escaped; no broker credentials, account identifiers,
    VPS secrets, or private logs enter generated reports.
- **Migration/compatibility**:
  - Raw strict V9 TSVs remain valid and unchanged. Existing ignored datasets
    without derived manifest fields are rebuilt rather than relabeled.
- **MQL5/end-to-end**:
  - No compile or Strategy Tester rerun is required while tracked MQL5 files
    remain unchanged. Existing Sprint 9 runtime acceptance remains the source
    behavior baseline, not profitability evidence.
- **Accessibility**: Not applicable; no user interface is introduced.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Macro side context is mistaken for an actual independent macro touch | False causal narrative and overfit patterns | Name it prior-close retest context; actual members must be V9 attempts | Docs/tests distinguish context rows from member signal IDs |
| ASOF join selects a future or expired window | Leakage into every downstream feature | Latest active-open join plus strict terminal/source-boundary guards | Zero future/expired context rows |
| Same-trigger candidates see different peers | Batch-order leakage | Freeze identical broker-time batches before snapshot emission | Same-batch snapshots have identical member sets |
| Later attempts leak into earlier anchors | Inflated confluence and model performance | Event sweep adds only current batch and past members | Negative later-member test; zero future members |
| Direct interval join scales poorly | Slow six-month builds and high memory | Bounded five-window event sweep with max 35 members | Stage timing, bound checks, no broad self-join |
| High-order combination explosion | Unreadable reports and severe multiple testing | Persist atomic members; default pair summaries; exact requested-set queries only | No power-set table or itemset dependency |
| Profit-ranked rare patterns look attractive | Overfit research conclusions | Support-first sorting, D1 group support, confidence intervals, holdout evaluation | Threshold metadata and per-fold/holdout report |
| Correlated intraday anchors cross splits | Leakage and overstated generalization | Group by symbol plus D1 active broker window across runs | Zero group intersection across partitions |
| Outcomes/admission enter features | Direct target leakage | Explicit feature allowlist and future/target denylist | Empty denylist intersection and one-row-per-anchor checks |
| Floating equality flips labels | Unstable neutral classification | Fixed `1e-8` offline tolerance and delta persistence | Boundary unit tests and distribution review |
| Repeated historical runs split separately | Duplicate market periods in train and holdout | Research group omits run ID and keys same symbol/D1 period together | Cross-run duplicate-date test |
| Old invalid VPS run contaminates evidence | Invalid conclusions from known causal defects | Source manifest allowlist and explicit rejection in docs | Dataset manifest contains only accepted run IDs |
| Stale hook state resumes the completed V9 plan | Wrong sprint reminder or unsafe continuation | Inspect, verify archive, then scripted `init --replace` only after authorization | Hook inspect points to this plan/Sprint 1 |
| Plan is archived before hook completion | Hook validator loses its plan path | Keep active path through final complete transition | Final `complete` succeeds before any later archive move |
| XGBoost lane becomes perceived deployment | Premature runtime coupling | Offline-only manifests, no export/deploy path, fixed ablation only | `runtime_artifact_emitted=false`; no MQL5 model files |
| Temporary accepted evidence disappears | Final integration blocked | Restore the named run or use an equivalent natural strict V9 run | Source validation and provenance recorded before Sprint 5 |

## Rollback Plan

- Every sprint begins at the prior sprint commit and ends with exactly one new
  commit. Prefer `git revert <sprint_commit>` for shared/history-preserving
  rollback; never use destructive reset commands as a shortcut.
- Sprint 1 rollback removes derived retest context while preserving strict V9
  source validation and all raw run files.
- Sprint 2 rollback removes member/snapshot materialization while retaining the
  six-context table.
- Sprint 3 rollback removes query/audit presentation while retaining atomic
  Parquet facts.
- Sprint 4 rollback removes opt-in model features/splits while retaining
  DuckDB analysis. Existing base offline training remains available.
- Sprint 5 rollback restores prior documentation/research status. Generated
  datasets, audits, and models are ignored artifacts and may be regenerated or
  removed only by their exact IDs; never delete a broad artifact root.
- No sprint changes broker state, EA inputs, `.ex5`, Common Files raw exports,
  or live positions. There is no runtime rollback procedure in this plan.
- Hook rollback/recovery uses `active_plan_state.py inspect` and deliberate
  `init --replace`; never edit `.codex-hook-state/*.json` manually.
- If a runtime/schema gap is found, stop at the current committed rollback
  point and create a separate explicit plan. Do not fold MQL5 changes into an
  offline sprint.

## Execution Order

1. Receive explicit implementation authorization.
2. Record baseline, run hook tests/activation check, inspect stale state, and
   initialize this plan with scripted `init --replace`.
3. Implement Sprint 1 only.
4. Update hook state to implemented, run and record all Sprint 1 validation,
   update validation to passed, create exactly one Sprint 1 commit, record its
   hash, then update commit status.
5. Advance hook state exactly one sprint and repeat the full
   implement/validate/one-commit/rollback-point gate for Sprints 2-4.
6. Run Sprint 5 only after the schemas, audits, and feature contracts are
   frozen and an accepted natural V9 run is available.
7. Do not run MetaEditor or Strategy Tester unless MQL5 scope unexpectedly
   changes; if it does, block and re-plan.
8. Mark hook state complete only after Sprint 5 validation and commit gates
   pass. Keep the plan at its current path through that transition.
9. Archive the completed plan only in a later hook-safe maintenance action when
   no active state references the current path.

## Completion Checklist

- [ ] Hook state safely references this plan and no stale V9 sprint reminder.
- [ ] Every strict attempt has six causal immutable retest contexts.
- [ ] First-touch identity remains unchanged and no `retest_sequence` exists.
- [ ] Confluence members are causal, half-open, bounded, mixed-direction, and
  unordered.
- [ ] Exact requested combinations are queryable without exhaustive mining.
- [ ] Admission and broker-outcome analyses remain separate.
- [ ] Minimum support, group support, confidence intervals, and holdout results
  are visible.
- [ ] Base and opt-in confluence XGBoost lanes use identical target rows and
  leakage-safe grouped splits.
- [ ] DuckDB/Parquet performance and disk cost are measured on natural data.
- [ ] No MQL5 runtime, V9 header, EA input, broker execution, or live-rollout
  change occurred.
- [ ] Every sprint passed its validation gate and has exactly one commit plus a
  recorded rollback point.
- [ ] Final artifacts and documentation remain `OFFLINE_RESEARCH_ONLY`.

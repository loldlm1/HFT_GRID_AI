# Candle Pattern Discovery Execution

Recorded 2026-09-22 from the accepted chat plan and the user's instruction to
execute the whole plan. Complexity: high. This is the execution record of that
plan, grouped into four commit checkpoints; it does not expand its scope.

The [proposal](candle-pattern-discovery-proposal.md) owns the design rationale.
The [project index](docs/README.md) owns current progress. Private evidence and
commit/rollback receipts live in `.codex-artifacts/candle-discovery/`.

## Fixed Decisions And Scope

- Preserve Pivot V14 source behavior, identities, exports and existing research.
- Add `Candle_Pattern_Discovery.mq5`, with separate CandlePatternV1 exports.
- Discover completed Micro Harami/Engulfing patterns; capture Macro/Micro features.
  Keep pattern families and ALIGNED/OPPOSED research categories independent.
- Use ATR(13) x 1.0, shift 1 for originals and re-entries; capture shift 0 as data.
- Reset active pivot context each broker Macro candle. Retain per-level facts;
  select latest tested level, outermost for simultaneous ties, using normalized
  V14 touches and PP departure/return. Separate signal and pivot percent-B.
- Send checked FOK 1R requests in both directions; keep submitted SL/TP fixed.
  Record actual fill deviations. Other targets are virtual 2R/3R.
- Allow one immediate same-direction re-entry after confirmed original broker SL.
  Each entry owns its own full Macro-duration expiry and explicit time exit.
- Research first-N allowances follow native broker Macro candles, after causal
  node/type filters; count entered attempts, not rejected requests or ratio rows.
  Preserve parent dependencies; re-entry-only analysis is not a virtual-parent
  execution strategy. No shared allowance between direction categories.
- MetaEditor/MT5 MCP and automated checks own this delivery's acceptance. Human
  chart review and visual MT5 object adjustments are deferred by user instruction.
- No live orders, production deployment, production intake, dataset purge, or
  unrelated infrastructure changes. One agent and one writer per worktree.
- Routine defaults: Macro H1, Micro M3, fixed 0.01 lots, export disabled until a
  run ID is supplied. These are explicit new-EA defaults, not changes to V14.
- Pending required decisions: none. The final direction-category choice replaces
  the earlier proposed ALIGNED/OPPOSED tie-priority question.

## Baselines And Resources

- MT5 checkout: `2bc95d39d9e6ef2954bc3ffebef145dbc9d81d53`.
- Consumer baseline: `57fae95ecbf23d8f22fd2f49ff7048bcfb5c3589`.
- Consumer branch/worktree: `codex/candle-pattern-discovery`,
  `/home/admin/python_projects/hft-grid-ai-orchestrator-candle`.
- Reuse calculations from `services/indicators/pivot_points_calculator.mqh` and
  `services/trading_signals/pivot_context_features.mqh`; isolate new engine state
  in `services/candle_pattern/` rather than changing Pivot aggregators.
- New offline owner: `tools/candle_pattern_ml/`; existing V14 toolchain remains
  strict V14. Consumer owners are `apps/datasets` and `apps/research`.
- Follow `AGENTS.md`, `docs/environment/mt5-agentic-workflows.md`, and consumer
  contract/isolated-feedback guidance. Both MCP workspaces confirm build 6184,
  AVX2 compiler and native backtest availability under the configured MQL5 roots.

## Sprint 1: Contract And Preservation Baseline

Goal: pin the accepted behavior and rollback evidence before source changes.
Scope: proposal, this execution record, project index/instructions, runtime
contract. Capture source/binary hashes privately. Preserve original datasets.
Validation: resolve documentation links, instruction budget, `git diff --check`,
and inspect reviewed paths. No compiler/tester claim is made by this checkpoint.
Commit: `docs(candle): freeze discovery contract and execution baseline`.
Rollback: MT5 baseline above; recover documents with a reviewed revert.

## Sprint 2: Producer And Offline Contract

Depends on Sprint 1. Implement the dedicated EA, detection, context/features,
fresh broker checks, reconciliation, time exits, one re-entry, bounded virtual
trials and sealed typed exports. Build the independent Python schema validator,
research selection and focused fixtures through existing unittest workflows.
Validation: Python contract/selection tests, V14 source/hash preservation,
MetaEditor `get_workspace_info` then `compile_file` with zero errors/warnings,
regenerated EX5 metadata, and a bounded real-tick MT5 export/validation smoke.
Commit: `feat(candle): add ATR discovery producer and offline contract`.
Rollback: Sprint 1 commit plus retained matching binaries; preserve every run.

## Sprint 3: Additive Consumer Research

Depends on Sprint 2's sealed contract. Implement distinct Candle intake/storage
and independent pattern/direction research in the consumer worktree. Integrate
entry-type and per-Macro-candle first-N selection with parent dependencies and
explicit outcome types. Keep V14 intake, data and existing research unchanged.
Validation: changed-path selection through `tests/operations/local_feedback.py`,
focused isolated model/intake/domain/API and migration checks, plus a bounded
native UI journey for changed user flows. No production/staging data mutation.
Commit: `feat(candle): add independent candle dataset research` (consumer repo).
Rollback: consumer baseline above; additive migration rollback only when its
new owned data is absent. Do not undo or purge existing V14 data.

## Sprint 4: Automated Acceptance And Handoff

Depends on Sprint 3. Use MT5 MCP for bounded default/non-default Macro runs,
export-on/off broker equivalence, overlap, both directions, re-entry, rollover,
time exits, rejected requests, and stable family/direction allowances. Validate
sealed exports and exercise the producer-to-consumer path in isolated feedback.
Retain observed results, source/binary pins and explicit residual limits; update
the maintained guides and finish the handoff. Visual MT5 polish is deferred.
Validation: all required focused gates, exact include/reference sweeps,
`git diff --check`, source preservation, and recorded MCP/validator evidence.
Commit: `docs(candle): record automated acceptance and handoff` (MT5 repo).
Rollback: Sprint 2 producer and Sprint 3 consumer commits with matching binaries;
restore code independently from retained data. No deployment is performed.

## Validation And Execution Gates

Complete each checkpoint, run its required checks, create exactly one reviewed
commit in its owning repository, and record the commit and rollback parent before
advancing. Do not amend history or start a later checkpoint after a failed gate.
Use the installed Planner execution-state helper and inspect it after compaction.

Use existing unittest/isolated consumer runners; add behavior-focused fixtures,
not MQL5 test EAs, scripts, CI or a new test framework. Compiler and tester belong
to their MCPs; fallback is permitted only if a tool cannot execute and the reason
is recorded. Never stop another operator's tester or modify live positions.

Validate absence of future features, duplicate requests, cross-family/category
selection, fabricated time-exit fills, and orphan re-entries. Group original,
directions, ratios and children together during temporal validation and purge
overlapping outcome periods. Report counts, censoring, costs and bounded resource
observations rather than claiming profitability or full-history equivalence.

Primary risks are broker/virtual divergence, short ATR distances, shared account
margin, delayed broker closure and export failure. Fresh checked requests,
immutable protection, explicit states, bounded resources and retained chronology
are required mitigations. Passing automated checks completes this scope; it does
not claim live deployment or visual chart acceptance.

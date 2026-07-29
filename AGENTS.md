# HFT Grid AI - Agent Brief

This repository is being simplified into an always-on M1 market-data collector
with a minimal broker executor. Keep this file short; the active implementation
plan is the source of sprint scope and lives under `docs/plans/`.

## Entrypoint And Active Plan

- Entrypoint: `HFT_Grid_AI.mq5`.
- Active plan: `docs/plans/market-data-broker-executor-simplification-plan.md`.
- Environment runbook: `docs/environment/mt5-agentic-workflows.md`.
- Statistics workflow: `docs/workflows/extremum-engine-statistics-flow.md`.
- ML boundaries: `docs/workflows/deterministic-signal-ml-inference-flows.md`.

## Current Skill Stack

- `mql5-production-engineering` for MQL5 lifecycle, broker constraints, and
  Strategy Tester work.
- `token-saver-orchestrator` for compact RTK-first repository inspection.
- `planner` for ordered saved plans and sprint gates.
- `semantic-audit` for broad active-document and meaning-drift reviews when
  installed at `/home/loldlm/.codex/skills/semantic-audit`.

## Target Contract

- `EXTREMUM_V1` is the only signal source and runs on M1 without user session,
  direction, or concurrency selectors.
- The public inputs are only deterministic broker-session time basis, the two
  lot fields, statistics export, ML, pattern audit, and debug controls.
- Market observation and broker eligibility checks run even when export output
  is disabled; export controls persistence, not safety evaluation.
- A distinct attempt can own at most one broker position. Execution requires a
  hedging account; non-hedging accounts remain collection-only and fail sends
  closed.
- Broker state owns ticket, volume, entry, protection prices, close state, and
  realized profit after a fill. Local state never overwrites those facts.

## Broker Safety Kernel

Every attempt records broker facts at observation and refreshes them immediately
before any send. The pre-send result is the only authority allowed to send.
Checks include account margin mode, symbol trade mode, actual broker session,
terminal/MQL trade permission, bid/ask/spread, stops/freeze distances, volume
min/max/step, margin, `OrderCheck`, SL/TP validity, retcodes, symbol scope, and
stable internal magic scope. A high spread is observed, not a configurable
threshold denial.

## Deterministic Time

`FIXED_TIME_SESSIONS` stores broker timestamps unchanged. `EXNESS_SESSION` uses
the documented instrument DST calendar to normalize analysis timestamps (for
example US30 winter `14:30` broker time maps to `13:30` analysis time). Raw
broker time remains authoritative for scheduling, actual session checks,
durations, and causal ordering. Normalized time is for export, features,
research grouping, and pattern matching only; every normalized row records its
offset or equivalent manifest policy.

## ML And Audit Boundaries

- `ML_INFERENCE_SHADOW` is passive and cannot affect execution or risk.
- `ML_INFERENCE_FILTER` is Strategy Tester-only, runs after broker eligibility,
  and may only deny an otherwise admissible send.
- Pattern playback is research/tester scoped and cannot alter broker facts,
  lot sizing, SL/TP, or broker reconciliation.
- Historical schema/model artifacts remain immutable and are never relabeled.

## Validation And Commit Policy

- Do not add MQL5 harnesses, custom MQL5 test modules, test EAs/scripts, CI, or
  new test infrastructure.
- Sprints 1-5 use static call tracing, exact identifier checks, Python contract
  checks where already present, compact artifact review, and `git diff --check`.
- Do not run MetaEditor syntax checks or compiles in Sprints 1-5. Sprint 6 is
  the only real MetaEditor compile sprint and must finish with `0 errors, 0
  warnings`, followed by human Strategy Tester/chart verification.
- Complete and validate one sprint, create exactly one sprint-specific commit,
  record its rollback point, then advance one sprint.
- Preserve archived plans, research evidence, old datasets, and generated
  binaries; use new schema/run IDs for new artifacts.

## Include And Style Rules

- Keep the explicit include flow: tools -> management -> signals -> optional
  human-inspection frontend. Aggregators own order; avoid sibling includes and
  circular dependencies.
- Use 2-space indentation, `snake_case` variables, `CamelCase` functions, and
  `ALL_CAPS` enum values/constants.
- Avoid `auto`, lambdas, range-for, per-tick handle creation, unbounded logs,
  and repeated full-history scans.
- Check all indicator, market-data, file, array, and trade operations; release
  handles, timers, files, and chart resources in `OnDeinit`.

## Rollout Restriction

This plan does not authorize live rollout. Before any future deployment, the
target symbol must be flat under the previous internal identity, the account
must support hedging execution, and only one EA instance may run per account and
symbol.

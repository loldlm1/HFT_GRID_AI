# Planner Execution Discipline

Use this guide when executing an implementation plan created by `$planner` or
any equivalent Sprint-based plan. Local project rules in `AGENTS.md` still
control project-specific trading safety, tooling, and verification.

The plan is the execution contract. Do not treat it as background context only.
Execute Sprints in the order written unless the user explicitly changes the
order or the plan itself identifies safe independent dependencies.

Global Codex hooks may assist with active-plan continuity on this desktop, but
they do not change this file's gates. A hook reminder is a prompt to verify the
current state, not permission to skip validation, commit review, or trading-risk
checks.

## Instruction Relationship

When instructions conflict, follow the project `AGENTS.md` precedence rules. In
general:

1. Explicit user instruction for the current task controls the task.
2. Project `AGENTS.md` controls local invariants and safety rules.
3. This file controls how Sprint-based plans are executed.
4. The plan controls the intended implementation sequence.
5. Existing code conventions control local style when not otherwise specified.

This guide must not override trading-risk, license, secret-handling, broker, or
verification requirements from the local project.

## When To Create Or Revisit A Plan

Create or revisit a plan before continuing when any of these become true during
a task:

- The change crosses multiple modules, lifecycle stages, strategy contexts,
  shared helpers, or public contracts.
- The change touches order lifecycle, lot sizing, margin, drawdown, session
  windows, license checks, broker status, shared entitlement logic, external
  services, or generated runtime artifacts.
- The implementation path becomes ambiguous after local inspection.
- A requested small change reveals hidden architectural coupling.
- The current task starts requiring more than a narrow, directly verifiable
  patch.
- Tests, compile checks, or review reveal missing scope, missing dependencies,
  or a safer phased path.
- The current plan becomes stale, incomplete, unsafe, or inconsistent with local
  project rules.

For small, local, obvious changes, do not create a plan unless the user asks for
one.

## Complexity Classification

Classify the plan before implementation. Use the highest applicable complexity.

### Low Complexity

Use low complexity only when all of these are true:

- The plan has 1-2 Sprints.
- The change is local and easy to verify.
- The change does not affect trading behavior, public contracts, or architecture.
- The change does not touch high-risk areas.

Low-complexity plans may be executed fully in one batch.

### Medium Complexity

Use medium complexity when the plan is multi-step but mostly local, such as:

- A focused feature with clear implementation and validation steps.
- A refactor contained within one bounded area.
- UI/chart changes with clear acceptance criteria and no trading behavior impact.
- Non-critical data, docs, or configuration changes with straightforward rollback.

Medium-complexity plans may execute at most 50% of total Sprints in one batch.

### High Complexity

Use high complexity when the plan includes any of these:

- Multiple modules, systems, or architecture layers.
- Trading signal, grid planner, order lifecycle, protection, or shared helper
  changes.
- Large refactors or behavior-preserving migrations.
- External integrations, license workflows, async/timer behavior, or Strategy
  Tester optimization behavior.
- Areas where future Sprints depend strongly on prior Sprint validation.

High-complexity plans may execute at most 33% of total Sprints in one batch,
with a practical default cap of 3 Sprints per batch. A batch of 4 Sprints is
acceptable only when those Sprints are small, contiguous, low-risk, and mostly
documentation, tests, or narrow refactors.

### Critical Or Trading-Sensitive Complexity

Use critical complexity when any Sprint touches or can accidentally affect:

- Live order open, close, partial close, hedge, SAR, trailing, BE, or level-cap
  behavior.
- Magic-number, symbol, account, license, entitlement, or backend identity scope.
- Drawdown locks, daily budgets, session force-close, no-money handling, or
  broker-disabled/close-only states.
- Lot sizing, margin checks, stop/freeze distance handling, spread guards, or
  risk calculations.
- Secret/license exposure paths, logs, telemetry, files, or frontend-visible
  values.

Critical or trading-sensitive plans must be executed one Sprint per batch.

## Sprint Batch Sizing

Before editing files, select a contiguous Sprint batch. Never skip ahead.

Use these ceilings:

- Low complexity: full plan only when it has 1-2 Sprints and no high-risk areas.
- Medium complexity: at most `ceil(total_sprints * 0.50)` Sprints per batch.
- High complexity: at most `min(3, ceil(total_sprints * 0.33))` Sprints per
  batch by default.
- Critical or trading-sensitive: exactly 1 Sprint per batch.

The percentage is a ceiling, not a target. Choose a smaller batch when risk,
uncertainty, dependency depth, or verification cost is high.

## Execution Rules

For each selected batch:

1. Restate the selected Sprint numbers, goals, and expected validation before
   editing.
2. Confirm dependencies from prior Sprints are complete.
3. Implement only the selected contiguous Sprints.
4. Do not implement future Sprint work opportunistically unless it is strictly
   required to complete the current Sprint. If this happens, document it in the
   handoff.
5. Keep changes narrow and aligned with the plan's task paths, acceptance
   criteria, and validation steps.
6. Preserve existing public and trading contracts unless the current Sprint
   explicitly changes them.
7. Prefer local project conventions over generic framework patterns.
8. If the plan is discovered to be wrong, incomplete, unsafe, or stale, stop
   implementation and update or request revision before continuing.

## Sprint Completion Gate

A Sprint is not complete until all of these are true:

- Its tasks are implemented or explicitly deferred with a reason.
- Its acceptance criteria are satisfied.
- Its Sprint-level validation has run, or the exact reason it could not run is
  documented.
- Relevant focused tests, compile checks, or tester checks have passed, or
  failures are documented with next actions.
- The diff has been reviewed for unrelated changes, secrets, unsafe logs,
  trading-risk regressions, and scope creep.
- A commit has been created for that Sprint when the user or plan requires it
  and git is available.

Do not proceed to the next Sprint until the current Sprint passes this gate.

## Hook-Assisted Continuation

When global hooks are enabled, agents may maintain
`.codex-hook-state/active-plan-state.json` while executing a Sprint-based plan.
Use that state only for local continuity:

- Update it when starting a Sprint, after validation passes/fails, after the
  Sprint commit is created, and when a blocker or user question appears.
- Keep it small and redacted. Store only plan path, Sprint number/title, status,
  validation status, commit status, blocker status, and next action.
- Never store source code, full logs, account identifiers, broker credentials,
  license tokens, private traces, optimization sets, or `.env` values.
- If `Stop` asks Codex to continue, first verify the state against the real
  plan file, `git status --short`, and recent commits.
- If the hook state conflicts with the plan, git history, user instruction, or
  project safety rules, ignore the hook state and repair or delete it.

Hook state is never committed and must not be treated as audit evidence. The
commits, validation output, and handoff remain the durable record.

## Commit Discipline

Prefer one commit per completed Sprint when commits are requested or required by
the plan. Do not create commits just because a plan exists if the user did not
ask for commit work.

Before committing:

- Inspect `git status` and avoid mixing unrelated user changes.
- Include only files changed for the current Sprint.
- Use a concise commit message that references the Sprint number and intent.
- Do not commit if the user explicitly forbids commits.
- Do not commit unrelated dirty worktree changes.
- If unrelated changes are present and cannot be safely separated, stop and
  report the situation instead of guessing.

Suggested commit message format:

```text
Sprint N: implement <sprint goal>
```

If git is unavailable or commits are blocked, document that limitation in the
handoff. For plans where the user explicitly required commits before proceeding,
stop after the Sprint rather than continuing without commits.

## Validation Discipline

Use the narrowest meaningful validation during each Sprint and the local
project's required final checks before handoff.

Validation should match the Sprint risk:

- Documentation-only: proofread changed docs and verify links/paths.
- Focused code changes: run MetaEditor compile and targeted script/tester checks
  when available.
- Signal or indicator changes: validate indicator handles, buffer reads, slope
  or filter conditions, and tester behavior on representative inputs.
- Order lifecycle or risk changes: validate broker constraints, lot/margin math,
  retcodes, magic-number scope, cleanup, and forced close paths.
- License/shared guard changes: validate fail-closed behavior, magic number,
  entitlement profile macros, heartbeat/verify paths, daily result dedupe, and
  secret/log exposure.
- Frontend/chart changes: validate object names, cleanup, tester fallback, and
  performance impact.

Do not replace local project verification requirements with this generic list.
If local rules require stronger verification, follow the local rules.

## Handoff After Each Batch

After completing a batch, report:

- Sprints completed.
- Files changed.
- Validation/tests run and results.
- Commit hashes created, if any.
- Deviations from the plan, if any.
- Remaining Sprints.
- Recommended next batch.
- Risks, blockers, or manual follow-up.

Default behavior: stop after each batch and wait for the next execution
instruction. Continue to the next batch automatically only when the user
explicitly asked to execute the full plan.

## Handling Plan Problems

Stop and update or request revision of the plan when:

- A Sprint depends on work that was not planned.
- A task conflicts with project safety rules.
- Existing code makes the planned approach unsafe or unnecessarily invasive.
- The plan omits tests or validation for risky behavior.
- A later Sprint is required before an earlier Sprint can be completed.
- The implementation reveals a simpler or safer architecture that changes the
  plan materially.

When stopping, explain the exact conflict and propose the smallest safe plan
revision.

## Anti-Patterns

Avoid these behaviors:

- Executing the final objective while ignoring Sprint order.
- Skipping foundational Sprints because later work seems more useful.
- Mixing unrelated cleanup into Sprint commits.
- Creating one large final commit for many Sprints.
- Continuing after failed validation without documenting the failure.
- Expanding trading, license, or risk contracts without explicit plan/user
  approval.
- Using the plan as permission to bypass local safety or verification rules.

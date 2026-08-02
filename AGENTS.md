This is a MetaTrader 5 MQL5 Expert Advisor.

# Pivot HFT Agent Rules

Use this file for local project invariants. Keep reusable MQL5 engineering rules
in the `mql5-production-engineering` skill, and keep detailed strategy guides or
phase plans in `docs/`.

## Instruction Precedence

When instructions conflict, use this order:

1. Explicit user instruction for the current task.
2. This `AGENTS.md` file.
3. Project documentation in `docs/` and `services/shared/**`.
4. The `mql5-production-engineering` skill and any narrower applicable skill.
5. Existing local code conventions.
6. Official/current MQL5 and MetaTrader platform documentation.

## Research And MCP Usage

Use MCPs only when local files, this `AGENTS.md`, project docs, and applicable
skills are insufficient. Prefer the smallest useful lookup and stop researching
once the implementation decision is clear.

MCP usage order:

1. Local first: inspect code, inputs, includes, docs, plans, logs, and nearby
   conventions before networked tools.
2. `context7`: use when available for version-specific API behavior if it has
   an exact documentation match.
3. Web research or `tavily`: use only when enabled and when current MetaTrader,
   broker, platform, or security research cannot be answered locally. Prefer
   official MetaQuotes or broker sources.
4. `fetch`: use only when enabled and when a specific official URL is already
   known or a search result needs exact page details.
5. Stop early: capture only API names, constraints, source URLs, and the short
   reason they affect the change.

Never send account numbers, license tokens, API keys, broker credentials,
private logs, proprietary optimization sets, or `.env` values to MCP tools.

## Planner Execution Discipline

When executing a plan created by `$planner` or an equivalent Sprint-based plan,
read `docs/planner-execution-discipline.md` before editing.

Default execution policy:

- Execute Sprints strictly in the written order.
- Use contiguous Sprint batches only; never skip ahead.
- Low complexity: execute the full plan only when it has 1-2 low-risk Sprints.
- Medium complexity: execute at most 50% of total Sprints per batch.
- High complexity: execute at most 33% of total Sprints per batch, usually max 3.
- Critical or trading-safety/license-sensitive plans: execute one Sprint per
  batch.
- Complete validation before moving to the next Sprint. Every completed Sprint
  must have one brief commit summarizing that Sprint's feature or fix before
  continuing, unless the user explicitly forbids commits or git is unavailable.

If the plan becomes stale, unsafe, ambiguous, or incomplete, stop and update or
request revision before continuing.

## Codex Hooks And Compaction

This desktop may run global Codex hooks from
`C:\Users\loldlm\.codex\skills\codex-hooks`. Treat hooks as continuity helpers,
not as replacements for project rules.

- `PostToolUse` may clean safe local artifacts after tools run and may add
  context for risky commands that already executed. It must not be used as proof
  that a trading change is safe.
- `Stop` may ask Codex to continue an active Sprint plan when local hook state
  says validation or a Sprint commit is still pending. It must not bypass the
  Sprint Completion Gate below.
- `PreCompact`, `PostCompact`, and `SessionStart` may preserve a compact,
  redacted active-plan reminder across compaction.
- If an agent maintains `.codex-hook-state/active-plan-state.json`, keep it
  small, session-local, redacted, and untracked. Never store account numbers,
  broker credentials, license tokens, private logs, optimization sets, or source
  dumps in hook state.
- After any compaction, re-check `git status --short`, the current Sprint,
  validation status, and latest commit before editing.

## Project Map

- Entrypoint: `HFT_Grid_AI.mq5`.
- Include pipeline: standard MQL5 libraries -> `services/license_service_setup.mqh`
  -> service aggregators: `trading_tools`, `trading_management`,
  `trading_signals`, `frontend`.
- Inputs and indicator setup: `services/trading_management/*`.
- Pivot HFT state, detection, raw execution, local lifecycle, protection and
  sessions: `services/trading_signals/*`.
- Lower-level broker, price, money, array, lifecycle, logging, indicator, and
  order math helpers: `microservices/*`.
- Chart overlays, panels, and visual state only: `services/frontend/*` and
  `microservices/frontend/*`.
- Shared license implementation: `services/shared/license_guard_v1/*`.
- Strategy/user guides: `docs/guides/*`. Historical and active plans:
  `docs/plans/*`.

## Non-Negotiable Rules

- Do not change the include pipeline casually. Services must not re-include
  sibling aggregators, redeclare globals, or create circular dependencies.
- Preserve symbol and magic-number scoping for every order, position, deal,
  daily-result, hedge, close, and cleanup path.
- Canonical license logic lives in `services/shared/license_guard_v1/*`. Runtime
  live magic must come from `LicenseGetCachedMagicNumber()` after successful
  startup verification. Missing or invalid backend `magic_number` is fail-closed.
- Shared license daily-result dedupe and aggregation must stay scoped by
  `ea_id + magic_number` and deal filtering by `DEAL_MAGIC`.
- Respect daily signal budgets, session filters, market status, drawdown locks,
  debug stops, spread guards, margin checks, and broker close-only/disabled
  states. Pivot HFT uses one pending campaign and at most one managed hedging
  position at a time.
- Always use existing broker and math helpers for stop/freeze distances, price
  normalization, point distances, margin references, and symbol volume
  normalization.
- Check indicator handles, `CopyBuffer` calls, array bounds, trade retcodes, and
  `GetLastError()` paths. In Strategy Tester, critical invalid handles should
  fail fast when the existing code expects `TesterStop()`.
- Keep chart objects, comments, file logs, and debug output out of hot trading
  decisions unless an explicit configured input connects them.

## Architecture Contracts

- Pivot admission combines the current micro close, fixed Bollinger bands and
  classic macro pivots, then maintains one latest-level campaign.
- `pivot_hft_execution.mqh` owns raw hedging entries and verified fill
  registration. `pivot_hft_position_lifecycle.mqh` owns local SL, BE, trailing
  and net-result classification per ticket.
- `ProtectionRiskFilter` and `market_status_controller` own forced closes,
  drawdown/daily locks, market-close guard, broker failures, and pending force
  closes.
- Frontend modules render state only. Keep trading state authoritative in Pivot
  HFT signal, protection and license modules.

## Implementation Rules

- Follow local style: 2-space indentation, `snake_case` variables,
  `CamelCase` functions, `ALL_CAPS` enums/constants.
- Avoid `auto`, lambdas, range-for, and C++ idioms that do not map cleanly to
  MQL5.
- Use explicit struct constructors with initializer lists. Add default/copy
  constructors when arrays or assignments need them. Do not aggregate-initialize
  structs that define constructors.
- Keep new inputs in `services/trading_management/ea_inputs.mqh` with sane
  defaults and update indicator loading only when the input needs data.
- Keep hot paths cheap: no full-history scans, repeated `iCustom` handle
  creation, unbounded `ArrayResize`, noisy `Print`, or chart-object churn inside
  per-tick loops.
- Release indicator handles, timers, chart objects, file handles, and lifecycle
  state in the owning cleanup/deinit path.
- Avoid new dependencies or helper files unless they remove real duplication or
  match an existing local boundary.

## Verification

- Use the narrowest meaningful checks while developing.
- For compile validation on this install, use:

```powershell
& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"
```

- After reading `BUILD.log` and confirming the compile result, remove
  `BUILD.log`. This EA is compiled from a portable MT5 install, and stale build
  logs must not be reused as current validation evidence.
- If a future local test runner exists, prefer it for script harnesses and parse
  pass/fail markers plus MetaEditor warnings/errors.
- Do not build or require headless Strategy Tester matrix tests for MT5. Use
  compile gates plus manual/visual Strategy Tester or demo-chart validation when
  runtime broker behavior must be inspected.
- For Strategy Tester validation, prefer "Every tick based on real ticks" when
  tick-by-tick behavior, order lifecycle, session windows, or grid timing matters.
- Keep development logs compact. `query_debug.txt` may capture grid geometry,
  guard blocks, lifecycle transitions, and broker failures; clear or rotate it
  before long test sessions when relevant.
- Before final handoff, inspect the diff, report changed files, checks run,
  checks not run, and remaining trading or tester risk.

## Project Documentation

- `README.md`: Pivot HFT project overview.
- `docs/guides/pivot-hft-strategy-inputs.md`: active strategy guide.
- `docs/guides/pandora_box_guide_en.md` and `docs/guides/pandora_box_guide_es.md`:
  historical Pandora strategy guides.
- `docs/guides/pandora-box-strategy-inputs.md`: historical Pandora inputs.
- `docs/plans/*`: active and archived implementation plans.
- `docs/planner-execution-discipline.md`: Sprint batch, validation, and handoff
  rules for planner-based execution.
- `services/shared/license_guard_v1/README.md`,
  `backend-entitlements-contract.md`, and
  `license-shared-service-migration-plan.md`: license guard contract and rollout.

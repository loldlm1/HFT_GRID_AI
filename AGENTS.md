This is a MetaTrader 5 MQL5 Expert Advisor.

# HFT Grid AI Agent Rules

Use this file for local project invariants. Keep reusable MQL5 engineering rules
in the `mql5-functional` skill, and keep detailed strategy guides or phase plans
in `docs/`.

## Instruction Precedence

When instructions conflict, use this order:

1. Explicit user instruction for the current task.
2. This `AGENTS.md` file.
3. Project documentation in `docs/` and `services/shared/**`.
4. The `mql5-functional` skill and any narrower applicable skill.
5. Existing local code conventions.
6. Official/current MQL5 and MetaTrader platform documentation.

## Research And MCP Usage

Use MCPs only when local files, this `AGENTS.md`, project docs, and applicable
skills are insufficient. Prefer the smallest useful lookup and stop researching
once the implementation decision is clear.

MCP usage order:

1. Local first: inspect code, inputs, includes, docs, plans, logs, and nearby
   conventions before networked tools.
2. `context7`: use for version-specific MQL5/API behavior when it has an exact
   documentation match.
3. `tavily`: use for current MetaTrader, broker, platform, or security research
   that local files and `context7` cannot answer. Prefer official sources.
4. `fetch`: use only when a specific URL is already known or a search result
   needs exact page details.
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
- Complete validation before moving to the next Sprint. Create one commit per
  Sprint only when the user asked for commits or the plan requires them.

If the plan becomes stale, unsafe, ambiguous, or incomplete, stop and update or
request revision before continuing.

## Project Map

- Entrypoint: `HFT_Grid_AI.mq5`.
- Include pipeline: standard MQL5 libraries -> `services/license_service_setup.mqh`
  -> service aggregators: `trading_tools`, `trading_management`,
  `trading_management_strategies`, `trading_signals`, `frontend`.
- Inputs and indicator setup: `services/trading_management/*`.
- Grid trend-risk strategy glue: `services/trading_management_strategies/*`.
- Signal state, context indicators, filters, detection, channel guards, planner,
  order controller, protection, sessions, and telemetry:
  `services/trading_signals/*`.
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
- Respect `Signal_Concurrency_Mode`, daily signal budgets, session filters,
  market status, drawdown locks, debug stops, spread guards, margin checks, and
  broker close-only/disabled states.
- Always use existing broker and math helpers for stop/freeze distances, price
  normalization, point distances, margin references, and symbol volume
  normalization.
- Check indicator handles, `CopyBuffer` calls, array bounds, trade retcodes, and
  `GetLastError()` paths. In Strategy Tester, critical invalid handles should
  fail fast when the existing code expects `TesterStop()`.
- Keep chart objects, comments, file logs, and debug output out of hot trading
  decisions unless an explicit configured input connects them.

## Architecture Contracts

- Signal admission runs context gates in session -> macro -> trend -> base order.
  Contexts should evaluate only when their timeframe prints a new bar, while
  upstream cascade state stays aligned with the base bar.
- `CaptureContextIndicators()` should hydrate only data required by the current
  entry mode, slope toggles, channel MA filter, or fresh-structure guard.
- `StrategyContextEvaluateTrend()`, `StrategyCascadeAllowsSignal()`,
  `StrategyContextEvaluateEntry()`, and channel guards own signal authorization.
  Keep grid planning and order sending out of filter helpers.
- `BuildGridSignalPoints()` owns entry/TP/spacing geometry and broker-distance
  constraints. Preserve ATR/Keltner/points semantics and pending-stop guards.
- `GridOrderController` owns STOP -> ACTIVE -> TRAILING lifecycle, deeper level
  instantiation after fills, BE/trailing/final TP exits, and level-cap behavior.
- `ProtectionRiskFilter` and `market_status_controller` own forced closes,
  drawdown/daily locks, market-close guard, broker failures, and pending force
  closes.
- Frontend modules render state only. Keep trading state authoritative in signal,
  grid, protection, and license modules.

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

- If a future local test runner exists, prefer it for script harnesses and parse
  pass/fail markers plus MetaEditor warnings/errors.
- For Strategy Tester validation, prefer "Every tick based on real ticks" when
  tick-by-tick behavior, order lifecycle, session windows, or grid timing matters.
- Keep development logs compact. `query_debug.txt` may capture grid geometry,
  guard blocks, lifecycle transitions, and broker failures; clear or rotate it
  before long test sessions when relevant.
- Before final handoff, inspect the diff, report changed files, checks run,
  checks not run, and remaining trading or tester risk.

## Project Documentation

- `README.md`: project overview.
- `docs/guides/pandora_box_guide_en.md` and `docs/guides/pandora_box_guide_es.md`:
  Pandora strategy guide.
- `docs/guides/pandora-box-strategy-inputs.md`: Pandora inputs.
- `docs/plans/*`: active and archived implementation plans.
- `docs/planner-execution-discipline.md`: Sprint batch, validation, and handoff
  rules for planner-based execution.
- `services/shared/license_guard_v1/README.md`,
  `backend-entitlements-contract.md`, and
  `license-shared-service-migration-plan.md`: license guard contract and rollout.

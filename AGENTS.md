# AGENTS Brief - HFT Grid AI Foundation

Short, current notes for Codex agents and contributors. Keep this file brief; active implementation plans live in `docs/plans/` when present, and completed plans live in `docs/plans/archive/`.

---

## 1) Purpose And Entrypoint

- **Purpose**: MT5 Expert Advisor foundation for future strategy integration, broker-aware execution planning, and strict risk controls.
- **Entrypoint**: `HFT_Grid_AI.mq5`.
- **Active plan**: `docs/plans/deterministic-ma-stoch-strategies-plan.md`.
- **Archived plans**: completed refoundation and skill-stack alignment plans live under `docs/plans/archive/`.
- **Planning model**: create a new `$planner` plan under `docs/plans/` for any substantial future strategy, architecture, or repository-wide change.

## 2) Codex Skill Stack

Use the local Codex skills deliberately:

- **Primary MQL5 skill**: `mql5-production-engineering` for `.mq5`/`.mqh`, MetaEditor compile, trading lifecycle, broker/risk controls, indicator handles, Strategy Tester performance, and behavior-preserving refactors.
- **Primary shell/context skill**: `token-saver-orchestrator` for RTK-first shell output, concise search/build summaries, and token-efficient repo inspection.
- **Planning skill**: `planner` for sprint-based plans with acceptance criteria, validation, commit discipline, and explicit non-goals.
- **Audit skill**: `semantic-audit` for broad naming, documentation, contract, or meaning-drift reviews.
- **Situational production skills**: use framework-specific skills only when matching files/tasks appear, such as TypeScript, Python/Django, Rails, Phoenix, Flutter, PostgreSQL, DevOps, or premium UI.

Do not force unrelated skills into normal MQL5 work. Prefer the repo rules in this file when a generic skill conflicts with project-specific safety constraints.

## 3) Functional Include Pipeline

The EA follows one ordered include chain from setup to frontend. Keep this order and avoid sibling include drift.

```text
services/license_service_setup.mqh
services/trading_tools.mqh
services/trading_management.mqh
services/trading_management_strategies.mqh
services/trading_signals.mqh
services/frontend.mqh
```

Rules:

- Aggregators are the single source of truth for include order.
- Include lower layers only, or shared core/utils/indicators helpers.
- Do not introduce circular includes or sibling service includes.
- Keep the flow explicit: inputs -> indicators/context -> strategy candidate -> execution planning -> broker-aware simulation -> broker reconciliation -> protection/risk -> frontend/telemetry.

## 4) Foundation Scope

The project has been refounded away from legacy strategy-specific behavior. Removed feature groups and inputs must not be preserved through deprecated shims or compatibility aliases.

Do not reintroduce removed strategy feature groups or their former public inputs as active code, docs, compatibility aliases, or entitlement mappings.

Preserved foundation controls:

- License and account settings.
- Protection/risk controls simplified around strategy-range foundations.
- Session time filters.
- Strategy timeframe, Stoch Structure period, direction mode, and concurrency mode unless a later phase changes them explicitly.
- Developer debug controls.
- Stoch Structure remains the structural context source.

## 5) Naming And Domain Rules

- Do not introduce removed public enum prefixes, inputs, or strategy concepts.
- Phase 4 completed the domain rename to execution foundation terms.
- Preserve enum numeric semantics where user configuration compatibility depends on ordinal values.
- Preferred foundation vocabulary: `strategy`, `execution`, `range`, `leg`, `broker snapshot`, `execution planner`, and `execution lifecycle`.
- Use removed legacy domain vocabulary only inside historical planning artifacts.

## 6) Execution Source Of Truth

- Before a real broker position exists, local execution simulation owns candidate state.
- Local simulation must apply broker conditions before activation decisions: spread, stops level, freeze level, volume min/max/step, margin, market status, sessions, license, and protection gates.
- After a real broker position exists, broker state owns ticket, volume, entry price, close state, and realized profit.
- Local state may reconcile against broker facts, but must not overwrite broker facts.
- Future statistics must distinguish simulated decisions from broker-confirmed outcomes.

## 7) Trading Safety Rules

Never weaken these controls to make a refactor compile:

- License guard and entitlement checks.
- Spread, broker stops/freeze, volume min/max/step, and margin guards.
- Drawdown/protection controls.
- Session and market-status gates.
- Magic-number and symbol scoping.
- Real broker position reconciliation.

Any phase touching these controls must call out risk level in its phase plan.

## 8) Validation Policy

- No custom MQL5 tests, test harnesses, or agentic CI are part of this refoundation.
- Do not add custom MQL5 test files or CI for strategy work unless a future human explicitly reverses this policy.
- Validate implementation phases with MetaEditor compile plus human-in-the-loop Strategy Tester/chart verification.
- Visual strategy validation is human-in-the-loop: only enabled deterministic strategies should show their shifted M1 MA and their linked macro chart MA.
- Macro MA charts are validation aids only. They must not drive signal detection, risk management, broker reconciliation, or lifecycle decisions.
- In Strategy Tester visual mode, deterministic logic MA handles use `shift=0` and should be hidden with `TesterHideIndicators`; shifted MA handles are visual-only.
- Legacy custom tests and the old test runner have been removed.
- Documentation-only phases do not run MT5 compile.
- Implementation phases compile once at phase end, not after every atomic task.
- Compile portable/headless first whenever possible, then fallback to normal MetaEditor compile if needed.
- Treat compiler warnings and errors as phase failures unless a temporary exception is explicitly documented.

Preferred compile command shape for implementation phases:

```powershell
$mt5Root = "C:\Program Files\MetaTrader 5-1"
$metaeditor = Join-Path $mt5Root "MetaEditor64.exe"
$entrypoint = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$log = Join-Path $mt5Root "MQL5\Experts\HFT_Grid_AI\logs\compile\phase-build.log"
& $metaeditor /portable /s /compile:$entrypoint /log:$log
```

Fallback:

```powershell
& $metaeditor /s /compile:$entrypoint /log:$log
```

## 9) Style

- 2-space indentation.
- `snake_case` variables.
- `CamelCase` functions.
- `ALL_CAPS` enum values and constants.
- Avoid C++11 habits that MQL5 agents overuse: no `auto`, lambdas, or range-for.
- Prefer explicit constructors with initializer lists; add default/copy constructors when structs are used in arrays or assigned.
- Do not use aggregate initialization for structs that define constructors.
- Keep hot paths cheap: no per-tick handle creation, full-history scans, unbounded logging, or repeated market-data calls without a clear reason.

## 10) Canonical Repo Placement

- Preferred layout: `<MT5_ROOT>/MQL5/Experts/HFT_Grid_AI`.
- Keep `terminal64.exe` and `MetaEditor64.exe` in `<MT5_ROOT>`, not inside the EA repo.
- This workstation currently uses `C:\Program Files\MetaTrader 5-1`.

# Plan: Pivot HFT sobre Bollinger y pivotes clasicos

**Generated**: 2026-08-01
**Status**: Sprints 15-16 implementation, static review and the final compile
are complete. Manual real-tick QA is explicitly delegated to the user and
remains a release prerequisite until that session is executed.
**Estimated Complexity**: Critical / trading-sensitive

**Execution override**: Per explicit user authorization, the original batch
executed Sprints 1-8 in order with one sprint-specific commit each. Sprint 9 is
executed as one additional trading-sensitive sprint, skips MQL5 harness/CI
tests, and uses one MetaEditor compilation as its final gate.

**Execution record**: Sprints 1-8 were executed in order. The final portable
MetaEditor gate passed with `0 errors, 0 warnings`; `BUILD.log` and the temporary
Include junction needed by the already-open MetaEditor profile were removed.
No harness/CI or automated Strategy Tester matrix was run. Visual real-tick US30
and demo-chart validation remain explicit release prerequisites. Sprint 9
completed with the exact MetaEditor `5-1` gate at `0 errors, 0 warnings` in
`7624 ms`; `BUILD.log`, the temporary editor copy and the temporary Include
junction were removed. No harness/CI or automated tester matrix was run.

Sprint 14 completed the final static review with `git diff --check` passing and
the targeted include, history-boundary, file-log, chart-cleanup,
symbol/magic-scope and license-contract checks passing. The exact portable
MetaEditor `5-1` compile completed with `0 errors, 0 warnings` in `8772 ms`.
The current `BUILD.log` and temporary Include junction were removed after the
result was recorded; no harness, CI or Strategy Tester session was launched by
the agent. Manual real-tick chart, broker-history and `query_debug.txt`
correlation remains pending with the user.

**QA remediation validation override**: By explicit user instruction during
Sprint 10, Sprints 10-13 use static/diff review only. No MQL5 harness tests or
CI are created or executed. One MetaEditor compile is reserved for the final
Sprint 14 gate after all remediation code is complete. A Sprint 10 compile had
already passed at `0 errors, 0 warnings` before this override was received; its
temporary `BUILD.log`, helper script and Include junction were removed, and it
does not replace the required final Sprint 14 compile.

**Current remediation override**: The user authorized two additional
trading-sensitive sprints after the M30 audit. Sprints 15 and 16 must run in
order with one commit per sprint. No harness, CI or manual Strategy Tester QA
may be created or launched. The only compile for this remediation batch is the
final Sprint 16 MetaEditor gate.

Sprint 15 passed candidate-order, same-bar retry, multi-ticket, hot-path,
include-scope and diff checks without compiling, then was recorded as
`e1c3ba9`. Sprint 16 static checks confirm the old TP/SL/BE net-sign conflation
is absent, trigger and exit evidence is explicit, logger sharing/cleanup is
bounded, no include topology changed and no sensitive values were introduced.
The first final-gate invocation exposed the known portable MetaEditor profile
problem (`Include\Trade\Trade.mqh` missing) before code compilation. After
recreating only the temporary profile Include junction, the current source
compiled with `0 errors, 0 warnings` in `8649 ms`. The junction and `BUILD.log`
were removed; no harness, CI or Strategy Tester session was launched.

## Overview

Convertir HFT Grid AI en una estrategia tick-driven de Pivot HFT, conservando
la licencia, el magic por instancia, los filtros de mercado/sesion, las
protecciones de drawdown y los helpers de broker existentes. La logica de
negocio de Pandora y la semantica de grid se reemplazaran por una campana de
seguimiento de un solo pivote pendiente y un registro de posiciones locales
independientes.

La estrategia usara dos timeframes:

- `Pivot_HFT_Micro_Timeframe`, por defecto `PERIOD_M1`, controla Bollinger,
  la vela de campana y la ventana durante la que se permiten reintentos.
- `Pivot_HFT_Pivot_Timeframe`, por defecto `PERIOD_M30`, usa la vela macro
  cerrada anterior para calcular pivotes clasicos.

Una venta se arma cuando el cierre actual de la vela micro esta en o por encima
de una resistencia valida y el precio esta sobre la banda superior. Una compra
se arma con la condicion inversa en o por debajo de un soporte y la banda
inferior. La campana sigue el maximo del `Bid` para ventas o el minimo del
`Ask` para compras, y abre una orden de mercado cuando ocurre el retroceso
configurado.

Las ordenes de entrada se envian sin SL/TP al servidor. El precio real de fill
es la fuente de verdad para el SL local, el trailing step, el BE y el resultado
neto. Una posicion cerrada con resultado `<= 0` puede reintentar mientras su
vela micro original siga abierta; un resultado `> 0` completa la campana.

Se admiten multiples posiciones activas en cuentas MT5 de tipo hedging. Solo
existe una campana de seguimiento pendiente a la vez; si se toca otro pivote
antes del fill, el pivote mas reciente reemplaza al anterior. Una posicion ya
abierta no se cancela cuando cambia la vela micro o se recalculan los pivotes.

## Scope

- **In scope**:
  - Inputs minimos de Pivot HFT, reemplazando los inputs de estrategia Pandora,
    contextos y grid que queden sin consumidores.
  - Pivotes clasicos `P`, `R1-R3` y `S1-S3`, con `R1-R3` para ventas y `S1-S3`
    para compras. `P` queda disponible para visualizacion y diagnostico.
  - Bollinger nativa `iBands` en el timeframe micro, fija en periodo `21`,
    desviacion `2.0`, `PRICE_CLOSE` y lectura de la vela micro cerrada
    anterior (`shift=1`).
  - Maquina de estados pendiente -> seguimiento -> envio -> posicion activa ->
    cierre local -> reintento o campana completada.
  - Multiples posiciones activas independientes por ticket, simbolo y magic,
    con requisito de cuenta hedging.
  - Entradas de mercado sin proteccion SL/TP en servidor, con validacion de
    retcode, deal, fill, volumen, margen, spread y restricciones de mercado.
  - SL local, trailing step con BE, reintento despues de SL o BE y clasificacion
    por resultado neto real del deal.
  - Integracion con licencia y magic existentes sin cambios en el backend ni
    en `services/license_service_setup.mqh`.
  - Visualizacion compacta de pivotes, bandas y estado de la campana, mas logs
    acotados para armados, reemplazos, fills, cierres y bloqueos.
  - Documentacion activa, mapa de arquitectura y guia de validacion Pivot HFT.

- **Out of scope**:
  - Cambios a `services/shared/license_guard_v1/*`, contratos backend,
    `ea_id`, perfil de licencia o claves existentes.
  - Nuevos modos de pivotes, offsets, tolerancias, desviaciones Bollinger,
    multiplicadores de lote o menus de niveles configurables.
  - Ordenes pendientes, grid levels, hedge/SAR de la estrategia anterior,
    SL/TP enviados al servidor o posiciones sinteticas locales sin fill real.
  - Matrices headless de Strategy Tester; se usaran compile gates y pruebas
    visuales/manuales segun las reglas del proyecto.
  - Prometer latencia de HFT institucional; el alcance es ejecucion tick-driven
    para MT5 retail y su broker.

- **Fixed decisions**:
  - La cuenta operativa debe ser hedging. El EA bloqueara la inicializacion o
    las nuevas entradas en cuentas netting para no fusionar posiciones que
    requieren trailing independiente.
  - Los valores numericos de distancia se expresan como puntos MQL5: precio =
    `points * SymbolInfoDouble(_Symbol, SYMBOL_POINT)`. El valor inicial sera
    `25.0` para retroceso, SL local y step TP, y se ajustara en optimizacion.
  - La deteccion de venta usa el cierre actual de la vela micro obtenido con
    `iClose(_Symbol, Pivot_HFT_Micro_Timeframe, 0) >= Rn` y la banda superior
    de la vela anterior (`shift=1`); la
    compra usa la relacion `<= Sn` y banda inferior. No hay offset ni tolerancia
    adicional.
  - En venta se sigue el maximo del `Bid` y se vende cuando el `Bid` retrocede
    el numero de puntos configurado. En compra se sigue el minimo del `Ask` y
    se compra cuando el `Ask` rebota el numero configurado.
  - El pivote valido mas reciente reemplaza al pivote pendiente anterior antes
    del fill. No se mantienen varias campanas pendientes.
  - La campana pendiente expira al cierre de su vela micro. Una posicion activa
    continua hasta su cierre local aunque cambien la vela micro o los pivotes.
  - El step trailing usa `Pivot_HFT_TP_Step_Points` como intervalo favorable:
    el primer step mueve el SL a BE y cada step posterior avanza el SL por un
    intervalo. Un cierre neto en BE (`<= 0`) permite reintentar.
  - El resultado neto usa profit, swap, commission y fee de los deals asociados
    al ticket/position id y al magic del EA.
  - La licencia sigue identificandose como Pandora en backend; las referencias
    de licencia y el seed de magic de tester se conservan deliberadamente.

- **Assumptions**:
  - El simbolo principal de validacion es la variante US30 disponible en el
    broker; el nombre exacto puede ser `US30`, `US30.cash` u otro.
  - El timeframe micro es soportado por MT5 y no es mayor que el timeframe de
    pivotes. La vela macro usada para niveles siempre es la ultima vela cerrada.
  - El limite diario, spread, sesiones, drawdown, market-status y licencia
    siguen siendo gates globales para nuevas campanas; una sesion configurada
    como force-close puede cerrar posiciones activas segun su contrato actual.
  - Los targets locales se normalizan al tick size efectivo del simbolo, pero
    no se amplian artificialmente a `SYMBOL_TRADE_STOPS_LEVEL` porque no se
    envian como SL/TP de entrada al broker.

## Named Resources

- **Project instructions**:
  - `AGENTS.md`
  - `docs/planner-execution-discipline.md`
  - `README.md`
- **Current implementation anchors**:
  - `HFT_Grid_AI.mq5`
  - `services/trading_management/ea_inputs.mqh`
  - `services/trading_management/indicator_definitions_loader.mqh`
  - `services/trading_signals.mqh`
  - `services/trading_signals/signal_params_struct.mqh`
  - `services/trading_signals/pandora_box_detection.mqh`
  - `services/trading_signals/pandora_box_state.mqh`
  - `services/trading_signals/grid_order_controller.mqh`
  - `microservices/trading_signals/grid_order_lifecycle.mqh`
  - `services/trading_signals/tick_signals_manager.mqh`
  - `services/trading_signals/protection_risk_filter.mqh`
  - `services/trading_signals/market_status_controller.mqh`
  - `microservices/trading_signals/grid_order_helpers.mqh`
  - `microservices/utils/price_math.mqh`
  - `microservices/utils/money_functions.mqh`
- **New implementation files planned**:
  - `services/trading_signals/pivot_hft_state.mqh`
  - `services/trading_signals/pivot_hft_levels.mqh`
  - `services/trading_signals/pivot_hft_indicators.mqh`
  - `services/trading_signals/pivot_hft_detection.mqh`
  - `services/trading_signals/pivot_hft_execution.mqh`
  - `services/trading_signals/pivot_hft_position_lifecycle.mqh`
  - `services/frontend/pivot_hft_panel.mqh`
  - `services/frontend/pivot_hft_visualization.mqh`
  - `docs/guides/pivot-hft-strategy-inputs.md`
- **Tests and validation**:
  - MetaEditor compile gate for `HFT_Grid_AI.mq5`.
  - Visual Strategy Tester with `Every tick based on real ticks`.
  - Demo-chart hedging validation on the broker's US30 symbol.
  - `query_debug.txt` only for bounded diagnostic scenarios; rotate before
    longer tester sessions.
- **External documentation**:
  - MQL5 `iBands`: https://www.mql5.com/en/docs/indicators/ibands
  - MQL5 `CopyBuffer`: https://www.mql5.com/en/docs/series/copybuffer
  - MQL5 `iTime`: https://www.mql5.com/en/docs/series/itime
  - MQL5 `SymbolInfoDouble`: https://www.mql5.com/en/docs/marketinformation/symbolinfodouble
  - MQL5 `CTrade::Buy`: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuy
  - MQL5 `CTrade::Sell`: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradesell
  - MQL5 `CTrade::ResultRetcode`: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctraderesultretcode
  - MQL5 `CTrade::PositionClose`: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionclose
- **Operational resources**:
  - Portable MetaEditor: `C:\Program Files\MetaTrader 5-1\MetaEditor64.exe`
  - EA entrypoint: `C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5`
  - Existing shared license/backend configuration remains unchanged.

## Prerequisites

- Confirm the broker account is `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`.
- Record the broker's exact US30 symbol, digits, `SYMBOL_POINT`, tick size,
  volume min/max/step, spread behavior and trading sessions.
- Establish a clean baseline compile and preserve any unrelated worktree state.
- Confirm the existing backend license still authorizes the preserved Pandora
  profile and magic contract; no backend migration is part of this plan.
- Prepare a visual tester period containing several US30 volatility events and
  enough closed bars for both the micro Bollinger and macro pivot candle.

## Sprint 1: Pivot HFT Contracts And Input Boundary

**Goal**: Add the new strategy contract and state boundaries while keeping the
EA compilable and the shared license path unchanged.
**Dependencies**: Baseline repository inspection and hedging-account prerequisite.
**Tracked scope**: `microservices/core/enums.mqh`, `services/trading_management/ea_inputs.mqh`, `services/trading_signals/pivot_hft_state.mqh`, `services/trading_signals.mqh`, `services/trading_management.mqh`.
**Commit**: `feat: define pivot hft contracts and inputs`
**Demo/Validation**:

- Compile `HFT_Grid_AI.mq5` with the project MetaEditor command.
- Confirm the Inputs panel exposes only the minimal Pivot HFT strategy fields,
  retains license/protection/session fields, and defaults distance fields to
  `25.0`.

**Rollback point**: Restore the pre-sprint commit; no live behavior is enabled
until the new detection path is wired in later sprints.

### Task 1.1: Define Pivot HFT enums and state structs

- **Location**: `microservices/core/enums.mqh`, `services/trading_signals/pivot_hft_state.mqh`
- **Description**: Define campaign states for idle, armed, tracking,
  order-pending, active, closed-negative, completed and expired. Define a
  pivot-level identity, macro pivot snapshot, micro-candle campaign state and
  per-position state. Include explicit constructors/copy behavior for dynamic
  arrays and ticket fields.
- **Dependencies**: None.
- **Acceptance criteria**:
  - No state field uses a Pandora name.
  - Position state stores direction, pivot level, campaign micro-bar time,
    fill price/time, local SL, trailing step, ticket, comment and close outcome.
  - A collection can hold more than one active hedging position while exactly
    one pending campaign is represented.
- **Validation**:
  - Compile gate and a source scan for constructor/default initialization.
- **Rollback**: Remove only the new enum/struct definitions.

### Task 1.2: Stage the minimal Pivot HFT input group

- **Location**: `services/trading_management/ea_inputs.mqh`
- **Description**: Add `Pivot_HFT_Micro_Timeframe`,
  `Pivot_HFT_Pivot_Timeframe`, `Pivot_HFT_Direction_Mode`,
  `Pivot_HFT_Retracement_Points`, `Pivot_HFT_Local_SL_Points`,
  `Pivot_HFT_TP_Step_Points`, `Pivot_HFT_Lot_Size` and
  `Pivot_HFT_Enable_Visualization`. Keep `EA_License_Key`, `Custom_Magic`,
  `EA_Instance_Id`, `Max_Spread`, session filters and protection controls.
  Keep legacy Pandora/context/grid inputs temporarily so existing callers still
  compile; mark them as transitional and remove them only in Sprint 7 after the
  old order path is disconnected. Keep license identifiers in
  `services/license_service_setup.mqh` untouched.
- **Dependencies**: Task 1.1.
- **Acceptance criteria**:
  - All three distance defaults are `25.0` and are documented as MQL5 points.
  - Bollinger parameters and pivot level selection are not exposed as new inputs.
  - No new input changes the shared license/backend contract.
- **Validation**:
  - Compile gate; inspect generated input names/defaults in the MetaEditor log
    or visual tester Inputs panel.
- **Rollback**: Remove only the staged Pivot HFT inputs; keep the legacy input
  block until its callers are migrated.

### Task 1.3: Add a temporary include boundary for the new strategy

- **Location**: `services/trading_signals.mqh`, `services/trading_management.mqh`
- **Description**: Add the new state include in the existing aggregator order
  without re-including sibling aggregators. Keep legacy includes temporarily
  only where required for compilation, and document the planned removal.
- **Dependencies**: Tasks 1.1 and 1.2.
- **Acceptance criteria**:
  - Include order remains one-way and has no circular dependency.
  - Shared broker, protection and license services remain available.
- **Validation**:
  - Compile gate plus `rg "#include"` review of the aggregator graph.
- **Rollback**: Remove the temporary include only.

### Sprint 1 Gate

- [ ] All Sprint 1 tasks complete.
- [ ] Compile validation passes and evidence is recorded.
- [ ] Residual input migration risks are documented.
- [ ] Exactly one Sprint 1 commit is created with the proposed message.
- [ ] The rollback commit/hash is recorded.
- [ ] Sprint 2 has not started before this gate completes.

## Sprint 2: Macro Pivot And Micro Bollinger Data Layer

**Goal**: Produce a validated, cached snapshot of the current micro Bollinger
and previous closed macro-candle pivots.
**Dependencies**: Sprint 1.
**Tracked scope**: `services/trading_signals/pivot_hft_levels.mqh`, `services/trading_signals/pivot_hft_indicators.mqh`, `services/trading_management/indicator_definitions_loader.mqh`, `HFT_Grid_AI.mq5` cleanup hooks.
**Commit**: `feat: add pivot and bollinger data layer`
**Demo/Validation**:

- Run the compile gate.
- In visual tester, enable visualization/logs and confirm one macro snapshot
  per closed macro bar and one cached Bollinger handle on the micro timeframe.
- Force an invalid handle or insufficient history in tester and confirm the
  configured fail-fast behavior without sending an order.

**Rollback point**: Revert the data-layer commit while retaining the input
  contract from Sprint 1.

### Task 2.1: Implement classic pivot calculation

- **Location**: `services/trading_signals/pivot_hft_levels.mqh`
- **Description**: Read the previous closed candle from
  `Pivot_HFT_Pivot_Timeframe` and calculate `P`, `R1`, `R2`, `R3`, `S1`, `S2`,
  `S3` using the standard formulas. Store the macro bar time and source OHLC so
  recalculation occurs only when the macro bar advances.
- **Dependencies**: Sprint 1 state and timeframe inputs.
- **Acceptance criteria**:
  - No current/incomplete macro candle contributes to levels.
  - Values are rejected when OHLC or timeframe data is unavailable.
  - For a close already beyond several resistance/supports, helper selection
    can identify the latest touched level deterministically.
- **Validation**:
  - Compare logged values against a hand-calculated US30 candle in visual
    tester; test missing-history and zero-price guards.
- **Rollback**: Disable pivot snapshot calls and preserve state structs.

### Task 2.2: Create and cache native Bollinger handle

- **Location**: `services/trading_signals/pivot_hft_indicators.mqh`,
  `services/trading_management/indicator_definitions_loader.mqh`
- **Description**: Create one `iBands` handle for the micro timeframe with
  period `21`, deviation `2.0` and `PRICE_CLOSE`. Sprint 9 supersedes the
  original current-candle read: buffers `1` (upper) and `2` (lower) now use
  the previous closed candle (`shift=1`) with one refresh per source bar. Do
  not recreate the handle per tick.
- **Dependencies**: Task 2.1.
- **Acceptance criteria**:
  - Invalid handles stop safely in tester and block live detection.
  - The handle is released in the owning deinitialization path.
  - Current micro bar timing is independent of the chart timeframe.
- **Validation**:
  - Compile gate; visual tester check that the cached values match the chart's
    standard Bollinger 21/2.0/close settings.
- **Rollback**: Re-enable legacy loader only until the new handle path is fixed.

### Task 2.3: Centralize point and price normalization

- **Location**: `microservices/utils/price_math.mqh`,
  `services/trading_signals/pivot_hft_levels.mqh`,
  `services/trading_signals/pivot_hft_state.mqh`
- **Description**: Reuse the current convention where numeric distances are
  multiplied by `SymbolInfoDouble(_Symbol, SYMBOL_POINT)`. Normalize derived
  prices to the effective tick size and preserve broker-constraint helpers for
  broker-facing actions. Do not apply broker stop-distance clamping to local
  targets that are never sent in the entry request.
- **Dependencies**: Tasks 2.1 and 2.2.
- **Acceptance criteria**:
  - `25.0` produces the same price-distance convention used by the existing
    Pandora/grid helpers for the active symbol.
  - Point-size, tick-size and zero-value fallbacks are explicit and logged only
    behind debug settings.
- **Validation**:
  - Validate on US30 symbols with different digits/point sizes and inspect
    normalized target prices in `query_debug.txt`.
- **Rollback**: Use existing `GridResolvePointSize`/price helpers until the
  strategy helper is verified.

### Sprint 2 Gate

- [ ] Pivot and Bollinger snapshots are independently verifiable.
- [ ] Compile and visual data checks pass; no order path is enabled yet.
- [ ] Indicator-release and insufficient-history behavior are documented.
- [ ] Exactly one Sprint 2 commit is created and rollback point recorded.
- [ ] Sprint 3 has not started before this gate completes.

## Sprint 3: Micro Campaign Detection And Latest-Pivot Replacement

**Goal**: Detect the requested volatility condition and maintain exactly one
pending follow campaign per symbol while preserving micro-bar boundaries.
**Dependencies**: Sprint 2.
**Tracked scope**: `services/trading_signals/pivot_hft_detection.mqh`,
`services/trading_signals/pivot_hft_state.mqh`, `services/trading_signals/market_signal_detection.mqh` or its replacement, `HFT_Grid_AI.mq5` orchestration hooks.
**Commit**: `feat: implement pivot hft campaign detection`
**Demo/Validation**:

- Compile with the project gate.
- In visual tester, create scenarios for a sell above the upper band crossing
  `R1` then `R2`, and a buy below the lower band crossing `S1` then `S2`.
- Confirm the pending campaign always stores the latest valid touched pivot and
  that no second pending campaign is created before the first fills or expires.

**Rollback point**: Revert detector wiring while keeping the data-layer commit.

### Task 3.1: Detect micro-bar transitions and campaign expiry

- **Location**: `services/trading_signals/pivot_hft_detection.mqh`
- **Description**: Cache `iTime(_Symbol, Pivot_HFT_Micro_Timeframe, 0)`. On a new
  micro bar, finalize the previous pending campaign as expired unless it is an
  active position, then reset only the pending tracker. Existing positions keep
  their own campaign bar time and lifecycle.
- **Dependencies**: Sprint 2 snapshots.
- **Acceptance criteria**:
  - Reattempts are possible only while the original micro bar is open.
  - A chart timeframe change does not alter the strategy timing.
  - Active positions survive micro-bar and macro-pivot transitions.
- **Validation**:
  - Visual tester step across multiple M1/M3 bars while the chart is on a
    different timeframe.
- **Rollback**: Disable micro-bar expiry and restore the prior tick loop only
  during diagnosis.

### Task 3.2: Implement exact band/pivot admission and level selection

- **Location**: `services/trading_signals/pivot_hft_detection.mqh`,
  `services/trading_signals/pivot_hft_levels.mqh`
- **Description**: For SELL require the current micro close from
  `iClose(_Symbol, Pivot_HFT_Micro_Timeframe, 0)` above the upper band and
  `close_0 >= Rn`; select the highest currently crossed resistance. For BUY
  require the current micro close below the lower band and `close_0 <= Sn`;
  select the lowest currently crossed support. No offset or tolerance is applied.
- **Dependencies**: Task 3.1.
- **Acceptance criteria**:
  - Multi-level touches select the most recent level deterministically.
  - The Bollinger condition arms the campaign but does not cancel tracking when
    the favorable retracement moves back inside the band.
  - Direction-specific `Bid`/`Ask` usage is explicit and consistent.
- **Validation**:
  - Hand-driven visual tester cases around equality, multi-level crossings,
    spread changes and re-entry inside the band.
- **Rollback**: Revert only signal-admission changes.

### Task 3.3: Implement extreme tracking and retracement trigger

- **Location**: `services/trading_signals/pivot_hft_detection.mqh`,
  `services/trading_signals/pivot_hft_state.mqh`
- **Description**: For a sell, track the highest `Bid` after arming and emit an
  entry intent when `Bid <= tracked_high - retracement_price`. For a buy, track
  the lowest `Ask` and emit an intent when `Ask >= tracked_low +
  retracement_price`. Reset the tracker whenever the latest pivot replaces the
  pending campaign.
- **Dependencies**: Task 3.2.
- **Acceptance criteria**:
  - A strong breakout does not open immediately at the pivot.
  - A favorable retracement opens at most one order intent for the current
    tracker state.
  - Negative/BE closes can re-arm only through a fresh extreme/retracement
    sequence while the micro bar remains open.
- **Validation**:
  - Visual tester tick sequence with breakout, partial retracement, full
    retracement, failed trigger and repeated SL/BE cycles.
- **Rollback**: Disable order-intent emission while retaining diagnostic state.

### Sprint 3 Gate

- [ ] Detection, latest-level replacement and micro expiry pass visual checks.
- [ ] No live order is sent by the detector alone.
- [ ] Compile result and representative tick evidence are recorded.
- [ ] Exactly one Sprint 3 commit is created and rollback point recorded.
- [ ] Sprint 4 has not started before this gate completes.

## Sprint 4: Raw Hedging Execution And Position Registry

**Goal**: Convert entry intents into real hedging positions without broker SL/TP
and without local phantom positions.
**Dependencies**: Sprint 3.
**Tracked scope**: `services/trading_signals/pivot_hft_execution.mqh`, `services/trading_signals/pivot_hft_state.mqh`, `microservices/trading_signals/grid_order_lifecycle.mqh` or extracted raw-send helper, `microservices/trading_signals/grid_order_helpers.mqh`, `services/trading_signals/market_status_controller.mqh`.
**Commit**: `feat: add raw hedging execution for pivot hft`
**Demo/Validation**:

- Compile with MetaEditor.
- Confirm a valid entry sends `CTrade::Buy`/`Sell` with zero SL and TP, a
  deterministic comment and the runtime magic.
- Force spread, margin, disabled-trading and invalid-volume conditions and
  confirm no synthetic local position is created.

**Rollback point**: Restore the pre-execution entry path; no position lifecycle
  state should be retained without a verified deal/ticket.

### Task 4.1: Enforce hedging account and symbol/magic scope

- **Location**: `services/trading_signals/pivot_hft_execution.mqh`,
  `HFT_Grid_AI.mq5`, `services/trading_signals/market_status_controller.mqh`
- **Description**: Check `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING` during startup or
  before new entries. Preserve symbol and runtime magic filtering for every
  position/deal lookup. Block new signals with a compact reason on netting
  accounts while leaving license and risk cleanup paths authoritative.
- **Dependencies**: Sprint 3 state.
- **Acceptance criteria**:
  - Netting accounts cannot create Pivot HFT entries.
  - Positions from other symbols, magic values or charts never enter the local
    registry.
  - Multiple same-symbol positions are represented independently on hedging
    accounts.
- **Validation**:
  - Demo/tester checks on hedging and a controlled netting account or mocked
    margin-mode path; source review of all selection loops.
- **Rollback**: Disable only new-entry admission on unsupported margin mode.

### Task 4.2: Extract a raw market order sender

- **Location**: `services/trading_signals/pivot_hft_execution.mqh`,
  `microservices/trading_signals/grid_order_lifecycle.mqh`
- **Description**: Reuse broker guardrails, normalized fixed volume, filling
  mode and market-status checks. Send `Buy(volume, symbol, 0.0, 0.0, 0.0,
  comment)` or the sell equivalent. Require `ResultRetcode`, `ResultDeal`,
  `ResultPrice` and position discovery before creating active state. Retry only
  through a fresh eligible trigger; never fabricate a local fill after rejection.
- **Dependencies**: Task 4.1.
- **Acceptance criteria**:
  - Entry requests contain no initial server SL/TP.
  - A `true` boolean from `CTrade` without a successful retcode/deal is not
    treated as an executed position.
  - Broker failures are recorded without noisy per-tick output.
- **Validation**:
  - Normal fill and forced retcode scenarios in visual tester; inspect request
    and result diagnostics.
- **Rollback**: Disable raw sender and keep detector intents queued for the next
  controlled test.

### Task 4.3: Register actual fills and release the pending campaign

- **Location**: `services/trading_signals/pivot_hft_execution.mqh`,
  `services/trading_signals/pivot_hft_state.mqh`
- **Description**: Resolve the actual position ticket by result deal/comment,
  snapshot fill price/time and clear only the pending campaign. Permit another
  pending campaign on a later tick or micro bar while the new position remains
  active.
- **Dependencies**: Task 4.2.
- **Acceptance criteria**:
  - The registry can hold multiple live tickets.
  - Every active state is tied to the actual fill price used for local targets.
  - A newer pivot cannot mutate an already active position's pivot metadata.
- **Validation**:
  - Two or more fills across consecutive micro bars in a hedging tester run;
    verify independent comments, tickets and fill anchors.
- **Rollback**: Revert registry insertion while preserving broker diagnostics.

### Sprint 4 Gate

- [ ] Hedging-only guard and raw order semantics pass.
- [ ] No local phantom fills exist after broker rejection.
- [ ] Multiple active positions remain symbol/magic scoped.
- [ ] Compile and broker-result evidence are recorded.
- [ ] Exactly one Sprint 4 commit is created and rollback point recorded.
- [ ] Sprint 5 has not started before this gate completes.

## Sprint 5: Local SL, BE, Trailing Step And Outcome Reattempts

**Goal**: Manage every actual position locally and re-arm negative/BE results
without server-side SL/TP.
**Dependencies**: Sprint 4.
**Tracked scope**: `services/trading_signals/pivot_hft_position_lifecycle.mqh`, `services/trading_signals/pivot_hft_state.mqh`, `services/trading_signals/tick_signals_manager.mqh` or replacement, `microservices/trading_signals/grid_break_even_utils.mqh`, `microservices/trading_signals/grid_order_helpers.mqh`.
**Commit**: `feat: implement pivot hft local trailing lifecycle`
**Demo/Validation**:

- Compile with the project gate.
- Run visual real-tick scenarios for initial SL, BE, multiple trailing steps,
  positive close, negative close and exact zero/commission-negative close.
- Confirm active positions continue after the micro candle closes and later
  micro bars can create additional independent positions.

**Rollback point**: Revert the local lifecycle commit; raw entry records remain
  inspectable but no new local close behavior is retained.

### Task 5.1: Compute local targets from actual fill

- **Location**: `services/trading_signals/pivot_hft_position_lifecycle.mqh`
- **Description**: Use `Ask` as buy fill/entry-side quote and `Bid` as sell fill
  quote; use the opposite close quote for local exits. Compute initial SL from
  `Pivot_HFT_Local_SL_Points * SYMBOL_POINT`, normalize to effective tick size,
  and never include SL/TP in the original entry request.
- **Dependencies**: Sprint 4 fill registry.
- **Acceptance criteria**:
  - Local SL direction and price normalization are correct for BUY and SELL.
  - Target math uses actual fill rather than pivot or theoretical trigger.
  - Broker stop/freeze distance does not silently rewrite local target math.
- **Validation**:
  - Hand-calculated US30 cases with `_Point=0.1` and another point size;
    inspect local target logs.
- **Rollback**: Disable local close evaluation while preserving state snapshots.

### Task 5.2: Implement step trailing and BE

- **Location**: `services/trading_signals/pivot_hft_position_lifecycle.mqh`,
  `microservices/trading_signals/grid_break_even_utils.mqh` as a reusable math
  boundary only
- **Description**: Resolve favorable movement using the executable close quote.
  At step one move the local stop to BE; at later steps advance it monotonically
  by `Pivot_HFT_TP_Step_Points`. Do not move a stop backwards. Mark the local
  state as trailing-active and preserve the highest completed step.
- **Dependencies**: Task 5.1.
- **Acceptance criteria**:
  - Stop movement is monotonic and direction-safe.
  - BE is evaluated locally and a BE close is classified as `<= 0` for retry.
  - All local targets remain independent per ticket.
- **Validation**:
  - Synthetic tick sequences for 0, 1, 2 and several steps in both directions;
    compare expected price levels and close behavior.
- **Rollback**: Fall back to initial local SL-only evaluation for diagnostics.

### Task 5.3: Close by ticket and classify net outcome

- **Location**: `services/trading_signals/pivot_hft_position_lifecycle.mqh`,
  `services/trading_signals/tick_signals_manager.mqh`,
  `services/trading_signals/market_signal_cleanup.mqh`
- **Description**: On local SL/trailing hit call `CTrade::PositionClose(ticket)`
  only when broker actions are allowed, check its retcode, and keep the state
  active if the close fails. After history is available, aggregate the ticket's
  deals scoped by symbol/magic and classify `net_result > 0` as completed;
  otherwise mark it reattemptable while the originating micro bar is open.
- **Dependencies**: Task 5.2.
- **Acceptance criteria**:
  - A close failure cannot remove the active registry entry.
  - Profit, swap, commission and fee are included in outcome classification.
  - Positive close prevents reattempt; negative and BE close re-arm only before
    micro-bar expiry.
- **Validation**:
  - Tester/demo scenarios with positive TP-step trail, SL, BE, commission-only
    negative and forced close retcodes.
- **Rollback**: Keep active registry and defer outcome cleanup until the next
  verified history pass.

### Sprint 5 Gate

- [ ] Local SL, BE, trailing and close-by-ticket behavior is validated both sides.
- [ ] Negative/BE reattempt and positive completion rules are evidenced.
- [ ] Multiple active position states remain independent.
- [ ] Compile and real-tick tester evidence are recorded.
- [ ] Exactly one Sprint 5 commit is created and rollback point recorded.
- [ ] Sprint 6 has not started before this gate completes.

## Sprint 6: OnTick Integration, Protection, Sessions And Daily Accounting

**Goal**: Make Pivot HFT the only active strategy path while preserving the
project's non-negotiable risk, license and market-status boundaries.
**Dependencies**: Sprint 5.
**Tracked scope**: `HFT_Grid_AI.mq5`, `services/trading_signals.mqh`,
`services/trading_signals/protection_risk_filter.mqh`,
`services/trading_signals/market_status_controller.mqh`,
`services/trading_signals/market_signal_state.mqh`,
`services/shared/license_guard_v1/*` only for read-only compatibility checks.
**Commit**: `feat: integrate pivot hft with runtime guards`
**Demo/Validation**:

- Compile with the project gate.
- Verify startup license/magic behavior is unchanged.
- Run visual scenarios with spread block, session block, drawdown lock,
  broker close-only/disabled mode, Algo Trading disabled and daily budget.
- Confirm existing active positions are force-closed only by the existing
  protection/market-status contracts, not by pivot detection.

**Rollback point**: Restore the previous `OnTick` orchestration while keeping
  the new modules disconnected.

### Task 6.1: Replace the signal orchestration

- **Location**: `HFT_Grid_AI.mq5`, `services/trading_signals.mqh`
- **Description**: Replace `PandoraDetectSignals`, generic context detection,
  grid tick manager and grid lifecycle calls with ordered Pivot HFT calls:
  refresh rates -> protection/status checks -> macro/micro snapshots -> pending
  campaign update -> raw entry admission -> active-position lifecycle -> UI.
  Keep the timer, license refresh and removal path unchanged.
- **Dependencies**: Sprint 5 lifecycle.
- **Acceptance criteria**:
  - No Pandora or generic grid detector can send an order.
  - New campaign admission is gated by session, spread, market status, margin,
    daily budget and license exactly once per eligible tick.
  - Existing active positions are updated every tick even when no new campaign
    is allowed, subject to existing broker-action permissions.
- **Validation**:
  - Compile plus source call-graph review with `rg`.
- **Rollback**: Restore the prior `Main`/`Main_Tick` path until integration is
  complete.

### Task 6.2: Adapt protection and daily-result boundaries

- **Location**: `services/trading_signals/protection_risk_filter.mqh`,
  `services/trading_signals/market_signal_state.mqh`
- **Description**: Replace `SignalParams`/Pandora array assumptions with the
  Pivot HFT position registry or a narrow lifecycle adapter. Preserve forced
  close of all EA positions by symbol/magic, daily signal accounting and shared
  license daily-result dedupe. Do not alter backend payloads or entitlement code.
- **Dependencies**: Task 6.1.
- **Acceptance criteria**:
  - Drawdown and broker-mode force close reaches every active ticket.
  - Daily results remain scoped by `ea_id + magic_number` and deal magic.
  - Protection cannot create, rearm or mutate a pending pivot campaign.
- **Validation**:
  - Compile; tester forced-drawdown and close-only scenarios; review daily
    result logs for symbol/magic scope and dedupe.
- **Rollback**: Keep an adapter around the old arrays until all forced-close
  paths pass.

### Task 6.3: Preserve hedging and license runtime identity

- **Location**: `HFT_Grid_AI.mq5`, `services/license_service_setup.mqh`,
  `services/shared/license_guard_v1/*`
- **Description**: Do not edit the shared license implementation or backend
  identifiers. Preserve `LicenseGetCachedMagicNumber()` in live mode and the
  existing tester magic seed. Verify all new comments and ticket searches use
  the runtime magic without changing license scope.
- **Dependencies**: Task 6.2.
- **Acceptance criteria**:
  - Live startup fails closed exactly as before when license magic is missing.
  - Tester still uses its deterministic custom/test magic behavior.
  - No secret, license token or account identifier enters logs or new state.
- **Validation**:
  - Compile, source diff review and controlled license/tester startup checks.
- **Rollback**: Revert only the adapter/orchestration changes; never bypass the
  shared license path.

### Sprint 6 Gate

- [ ] Pivot HFT is the only order-producing path.
- [ ] Session, market, spread, margin, daily and protection gates pass tests.
- [ ] License and magic behavior remains unchanged and fail-closed.
- [ ] Compile and forced-close evidence are recorded.
- [ ] Exactly one Sprint 6 commit is created and rollback point recorded.
- [ ] Sprint 7 has not started before this gate completes.

## Sprint 7: De-Pandora Cleanup, Frontend And Documentation

**Goal**: Remove obsolete Pandora/grid business code and expose the new strategy
without disturbing the shared license implementation or historical plan archive.
**Dependencies**: Sprint 6.
**Tracked scope**: `services/frontend.mqh`, new Pivot HFT frontend files,
`services/frontend/pandora_box_panel.mqh`,
`services/frontend/pandora_box_visualization.mqh`,
`microservices/core/enums.mqh`, obsolete signal/grid files after dependency
scan, `README.md`, `AGENTS.md`, `docs/guides/*`.
**Commit**: `refactor: remove pandora strategy and document pivot hft`
**Demo/Validation**:

- Compile after every deletion batch, not only at sprint end.
- Run visual tester with chart objects enabled and disabled; confirm clean
  `OnDeinit` removal and no object churn on every tick.
- Verify `rg "Pandora|PANDORA|pandora"` returns only intentionally preserved
  license identifiers and historical archived documents.

**Rollback point**: Restore the cleanup commit; the functional Pivot HFT path
  remains available from Sprint 6.

### Task 7.1: Remove Pandora business state and grid-only branches

- **Location**: `services/trading_signals/pandora_box_detection.mqh`,
  `services/trading_signals/pandora_box_state.mqh`,
  `services/trading_signals/grid_order_controller.mqh`,
  `microservices/trading_signals/grid_order_lifecycle.mqh`,
  `services/trading_signals/signal_params_struct.mqh`,
  `microservices/core/enums.mqh`
- **Description**: Delete or stop including Pandora-specific files and fields
  only after `rg` proves there are no active callers. Remove grid planner,
  context and hedge/SAR branches that have no Pivot HFT consumer. Preserve
  lower-level broker, price, money, array, lifecycle and logging helpers when
  they still serve the new path or protection services. At this point remove
  the transitional Pandora/context/grid inputs, including
  `Signal_Concurrency_Mode`, because the user-approved concurrency contract is
  one pending campaign plus multiple independent hedging positions.
- **Dependencies**: Sprint 6 call graph and protection adapter.
- **Acceptance criteria**:
  - No runtime path calls Pandora detection, local-only simulation, grid level
    creation or Pandora trailing.
  - Include topology remains acyclic and all remaining state has explicit
    constructors.
  - Historical `docs/plans/archive/*` files are not rewritten as implementation
    truth.
- **Validation**:
  - `rg` dependency audit, compile after each file batch and diff review for
    accidental removal of shared risk/license helpers.
- **Rollback**: Restore deleted files from the Sprint 7 pre-cleanup commit.

### Task 7.2: Replace frontend and telemetry labels

- **Location**: `services/frontend.mqh`,
  `services/frontend/pivot_hft_panel.mqh`,
  `services/frontend/pivot_hft_visualization.mqh`,
  `services/frontend/pandora_box_panel.mqh`,
  `services/frontend/pandora_box_visualization.mqh`
- **Description**: Render current macro pivots, Bollinger upper/lower, pending
  latest pivot, tracked extreme, retracement trigger, active ticket count,
  local SL/BE/trailing step and last broker error. Update only on state/bar
  changes where possible. Keep chart objects informational and never use them
  for signal admission.
- **Dependencies**: Task 7.1.
- **Acceptance criteria**:
  - Visual tester remains readable with multiple active tickets.
  - Deinit removes all Pivot HFT objects and comments.
  - No Pandora labels remain in active UI except intentionally preserved license
    profile text, if that panel is still shared.
- **Validation**:
  - Visual tester and demo chart attach/detach; object count and cleanup review.
- **Rollback**: Reconnect the existing generic visualization while preserving
  trading state.

### Task 7.3: Update active documentation and project instructions

- **Location**: `README.md`, `AGENTS.md`,
  `docs/guides/pivot-hft-strategy-inputs.md`, existing Pandora guides
- **Description**: Document two timeframe roles, classic pivot formulas, fixed
  Bollinger parameters, 25-point defaults, point conversion, latest-pivot
  replacement, hedging-only requirement, multiple active positions, local
  targets, BE reattempt, raw-entry risk and tester checklist. Mark old Pandora
  guides obsolete or move them to historical documentation without changing
  archived plans. Update the entrypoint product description to Pivot HFT while
  keeping the internal license profile, backend `ea_id` and tester magic seed
  unchanged. Keep the license/backend exception explicit.
- **Dependencies**: Tasks 7.1 and 7.2.
- **Acceptance criteria**:
  - Documentation matches the final input names and state transitions.
  - It warns that no server SL/TP exists and that Algo Trading/broker outages
    can delay local closes under the existing market-status contract.
  - No private keys, account numbers, credentials or proprietary logs are added.
- **Validation**:
  - Markdown link/path review and source-to-doc input comparison.
- **Rollback**: Restore active docs while leaving historical archives untouched.

### Sprint 7 Gate

- [x] Pandora/grid runtime business logic is removed or proven unreachable.
- [ ] Frontend and deinit cleanup pass visual checks. Static cleanup passed;
  attach/detach visual validation remains manual.
- [x] Active docs and AGENTS map are synchronized with the new architecture.
- [x] Compile and `rg` cleanup evidence are recorded.
- [x] Exactly one Sprint 7 commit is created and rollback point recorded.
- [x] Sprint 8 has not started before this gate completes.

## Sprint 8: Final Compile, Real-Tick Regression And Handoff

**Goal**: Prove the integrated EA compiles and the critical strategy/risk paths
are manually verifiable before any live or demo rollout.
**Dependencies**: Sprint 7.
**Tracked scope**: Final diff, `README.md`, `docs/guides/pivot-hft-strategy-inputs.md`,
temporary `BUILD.log` only.
**Commit**: `test: complete pivot hft compile and regression gate`
**Demo/Validation**:

- Run the exact MetaEditor compile command below and parse all errors/warnings.
- Remove `BUILD.log` immediately after recording the current result.
- Run visual Strategy Tester on the broker's US30 symbol using `Every tick
  based on real ticks`.
- Perform the manual matrix in the Testing Strategy section.

**Rollback point**: The last known-good Sprint 7 commit remains the release
rollback if any final regression is found.

### Task 8.1: Execute compile and static safety review

- **Location**: Entire repository, especially `HFT_Grid_AI.mq5`, aggregators,
  state and lifecycle modules.
- **Description**: Compile, inspect warnings/errors, review include order,
  handle release, array bounds, ticket/symbol/magic scopes, raw order request
  parameters, close retcodes and secret/log exposure.
- **Dependencies**: All prior sprints.
- **Acceptance criteria**:
  - MetaEditor reports zero errors and no unexplained warnings.
  - `BUILD.log` is removed after evidence is captured.
  - No generated `.ex5`, tester logs or debug artifacts are added to the diff
    unless explicitly tracked by the repository.
- **Validation**:
  - `& "C:\Program Files\MetaTrader 5-1\MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5" /log:"C:\Program Files\MetaTrader 5-1\MQL5\Experts\HFT_Grid_AI\BUILD.log"`
  - Inspect `BUILD.log`, then remove it.
- **Rollback**: Return to the Sprint 7 rollback point if the compile gate fails.

### Task 8.2: Run critical visual tester scenarios

- **Location**: Strategy Tester configuration and `query_debug.txt` only.
- **Description**: Execute representative scenarios: no history/invalid handle,
  sell and buy latest-pivot replacement, strong breakout plus retracement,
  repeated SL, repeated BE, positive trailing completion, multiple active
  hedging positions, spread/margin block, broker rejection, close failure,
  session filter, drawdown force close, market close-only/disabled, and micro
  versus macro timeframe transitions.
- **Dependencies**: Task 8.1.
- **Acceptance criteria**:
  - Every scenario produces the expected state transition and bounded diagnostic.
  - No order carries server SL/TP at entry.
  - Local target math remains anchored to each actual fill.
  - Multiple positions never cross symbol/magic/ticket boundaries.
- **Validation**:
  - Visual tester with real ticks plus demo-chart spot checks on US30.
- **Rollback**: Do not promote to demo/live; retain the last known-good commit
  and document the failing scenario.

### Task 8.3: Review diff, rollback and release checklist

- **Location**: Git diff, `README.md`, `docs/guides/pivot-hft-strategy-inputs.md`.
- **Description**: Confirm only planned files changed, no secrets or private
  artifacts are present, rollback commit hashes are recorded, and the handoff
  lists checks run, checks not run, residual live risks and next tester actions.
- **Dependencies**: Task 8.2.
- **Acceptance criteria**:
  - Every sprint has exactly one implementation commit.
  - The final handoff explicitly states hedging-only operation and no server
    SL/TP protection.
  - Demo validation is required before live use.
- **Validation**:
  - `git status --short`, `git diff --stat`, `git diff --check`, final `rg`
    scans and manual checklist review.
- **Rollback**: Use the recorded last-known-good sprint commit.

### Sprint 8 Gate

- [x] Final compile passes with current `BUILD.log` evidence, then the log is removed.
- [x] Real-tick/manual regression matrix is complete or each gap is documented.
- [x] Diff, secret, scope, magic and risk review passes.
- [x] Exactly one Sprint 8 commit is created and rollback point recorded.
- [x] Completion checklist and residual risks are current.

## Sprint 9: Tester Hot-Path Optimization And Closed-Candle Bands

**Goal**: Reduce Strategy Tester work outside an eligible session and remove
per-tick indicator/UI overhead while keeping protection, lifecycle, licensing,
symbol/magic scope and hedging behavior unchanged. Bollinger entry filters use
the previous closed micro candle (`shift=1`) and refresh only when that source
bar changes.
**Dependencies**: Sprint 8.
**Tracked scope**: `HFT_Grid_AI.mq5`,
`services/trading_signals/pivot_hft_indicators.mqh`,
`services/trading_signals/pivot_hft_detection.mqh`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/session_time_filter_manager.mqh`,
`services/trading_signals/pivot_hft_levels.mqh`,
`services/frontend/pivot_hft_visualization.mqh`, `README.md`,
`docs/guides/pivot-hft-strategy-inputs.md` and this plan.
**Commit**: `perf: optimize pivot hft tester hot path`
**Demo/Validation**:

- Run static graph, scope and diff checks without MQL5 harness/CI tests.
- Run exactly one MetaEditor compile, parse all errors/warnings, then remove
  `BUILD.log`.
- Confirm non-visual tester runs do not create chart objects or refresh the
  frontend, and that the Bollinger buffers are read at `shift=1` once per
  closed micro bar.

**Rollback point**: `2c2da88` (Sprint 8 final compile gate).

### Task 9.1: Use the previous closed micro candle and cache source-bar reads

- **Location**: `services/trading_signals/pivot_hft_indicators.mqh`.
- **Description**: Read upper/lower buffers `1/2` at `shift=1`, anchor the
  cache to `iTime(micro_tf, 1)`, honor `force_refresh`, and return the cached
  snapshot while the source candle is unchanged. Preserve invalid-handle,
  insufficient-history and tester fail-fast behavior.
- **Acceptance criteria**:
  - No `CopyBuffer` is performed on every tick for the same closed candle.
  - Upper/lower values remain normalized and independently validated.
  - The handle is still released by the existing deinit path.

### Task 9.2: Gate expensive strategy resources by the session window

- **Location**: `HFT_Grid_AI.mq5`,
  `services/trading_signals/session_time_filter_manager.mqh`,
  `services/trading_signals/pivot_hft_detection.mqh` and state helpers.
- **Description**: Cache session-window evaluation at minute granularity. Make
  the Bollinger handle lazy and release it when the session window closes;
  reset only the pending campaign on deactivation. Keep open-position local
  SL/BE/trailing processing and pending force-closes active outside the window.
  Skip new-entry quote/spread/data detection work when no session is eligible,
  while preserving all market, protection, daily, license and broker guards.
  Refresh symbol quotes with one tick read and reuse cached broker point data.
- **Acceptance criteria**:
  - Outside session with no managed live position, no entry indicator refresh,
    spread calculation or frontend refresh occurs.
  - Session re-entry creates one Bollinger handle and resumes detection without
    changing pivot selection or position scope.
  - Active positions continue to receive local protection and force-close
    handling regardless of session state.

### Task 9.3: Remove tester-only frontend and repeated hot-path work

- **Location**: `services/frontend/pivot_hft_visualization.mqh`,
  `services/trading_signals/pivot_hft_state.mqh`,
  `services/trading_signals/pivot_hft_levels.mqh` and active docs.
- **Description**: Disable chart objects/comments in non-visual Strategy Tester
  mode, cache repeated micro-bar/close reads for one tick, and reuse cached
  symbol point/tick metadata for normalization. Document the closed-candle
  Bollinger semantics and tester optimization behavior without changing the
  backend identity or server-side SL/TP contract.
- **Acceptance criteria**:
  - Non-visual tester execution has no chart-object churn or `Comment` updates.
  - Point/tick normalization remains equivalent on US30 broker variants.
  - README and input guide state `shift=1` and session-gated resources.

### Sprint 9 Gate

- [x] Closed-candle Bollinger and per-source-bar cache are implemented.
- [x] Session-gated resources and active-position protection paths are reviewed.
- [x] Static scope/include/diff checks pass without harness/CI tests.
- [x] Exactly one Sprint 9 MetaEditor compile passes with `0 errors, 0 warnings`.
- [x] `BUILD.log` is removed and exactly one Sprint 9 commit is created.

## Sprint 10: Persistent Lifecycle Audit Logging

**Goal**: Add bounded, agent-readable file diagnostics for the complete Pivot
HFT lifecycle without changing trading admission, broker requests, local
protection, license identity or session behavior.
**Dependencies**: Sprint 9 and the first visual QA findings.
**Tracked scope**: `services/trading_management/ea_inputs.mqh`,
`microservices/utils/file_logger.mqh`, `services/trading_tools.mqh`,
`services/trading_signals.mqh`, a Pivot HFT diagnostics module, Pivot HFT
detection/execution/lifecycle modules, session/protection/debug-stop paths,
`HFT_Grid_AI.mq5` and this plan.
**Commit**: `Sprint 10: add pivot hft lifecycle audit logging`

### Task 10.1: Add an explicit file-log boundary

- Add `Enable_File_Logs=false` independently from journal `Enable_Logs`.
- Reuse the common-files logger and write to `query_debug.txt` with a run id,
  symbol and runtime magic on every record.
- Emit run start/end records and print the resolved file path once when file
  logging is enabled.
- Warn once on file-open/write failure; never log license keys, account numbers,
  backend payloads or credentials.

### Task 10.2: Record lifecycle transitions, not tick noise

- Log campaign arm, replacement, expiry, retracement trigger and retry reset.
- Log entry guard blocks, broker send result, verified fill registration and
  unresolved-fill failures.
- Log local SL initialization, trailing-step advancement, local close request,
  broker close result, net result, reattempt and completion.
- Log session transitions, market-status transitions, force-close scheduling
  and debug tester stops. Repeated broker failures must be throttled or emitted
  only on meaningful state changes.

### Task 10.3: Validate the audit contract

- Confirm disabled file logging performs no formatting or file I/O in hot paths.
- Confirm enabled logging produces bounded pipe-delimited records that can be
  correlated by run, campaign sequence and ticket.
- Use static include/hot-path/secret/diff review only, then create one Sprint
  10 commit. The single remediation compile is deferred to Sprint 14.

### Sprint 10 Gate

- [x] `Enable_File_Logs` and the active logger boundary are implemented.
- [x] Campaign, execution, position, protection, session and debug-stop events
  have bounded audit coverage.
- [x] Static hot-path, secret, include-order and scope review passes.
- [x] Sprint 10 static validation passes; final compile remains deferred to
  Sprint 14 by explicit user instruction.
- [x] Exactly one Sprint 10 commit is created before Sprint 11 starts.

## Sprint 11: Tested-Level State And Historical Reconstruction

**Goal**: Model level validity independently from trade outcome and reconstruct
which current macro pivots were already tested before the EA could operate.
**Dependencies**: Sprint 10 audit evidence.
**Tracked scope**: `HFT_Grid_AI.mq5`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_levels.mqh`, diagnostics and this plan.
**Commit**: `Sprint 11: reconstruct tested pivot levels`

### Task 11.1: Define the tested-level lifetime

- Key validity by the current pivot-set activation and source macro candle.
- Treat a level as touched when a closed micro candle satisfies
  `low <= level <= high`.
- Keep a touch in the currently open micro candle provisional; burn it only
  when the next micro candle opens.
- Reset tested state only when a new macro pivot set becomes active, even when
  its numeric price equals a prior level.

### Task 11.2: Scan from the pivot-set base

- Use bounded `CopyRates` on `Pivot_HFT_Micro_Timeframe` from the current macro
  bar open through the last fully closed micro candle, regardless of sessions.
- Cache the last scanned closed micro bar and scan only missing bars afterward.
- Reconstruct deterministically on init, session re-entry and EA reattachment.
- Fail closed for new campaigns while required history is unavailable or
  unsynchronized, and record the reason in the audit log.

### Task 11.3: Validate in observation-only mode

- Compare reconstructed masks against hand inspection and the first-test logic
  in `indicators/Pivot_MultiTF_Range_Channel_v2.20.mq5` without adding an
  `iCustom` dependency.
- Verify multi-level candle touches, current-open-bar behavior, macro rollover
  and restart consistency before the mask gates entries.
- Complete static scope/history-boundary review and create one Sprint 11
  commit. Do not compile before Sprint 14.

### Sprint 11 Gate

- [x] Tested-level state is separate from campaign completion/position outcome.
- [x] Historical reconstruction is bounded, cached and session-independent.
- [x] Incomplete history fails closed and produces actionable audit evidence.
- [x] Sprint 11 static validation passes; final compile remains deferred to
  Sprint 14.
- [x] Exactly one Sprint 11 commit is created before Sprint 12 starts.

## Sprint 12: Burned-Level Admission And Session Integration

**Goal**: Enforce the reconstructed validity state in live campaign admission
while preserving same-micro-bar retries and all existing risk controls.
**Dependencies**: Sprint 11 reconstruction evidence.
**Tracked scope**: `HFT_Grid_AI.mq5`, Pivot HFT state/levels/detection,
indicator-resource activation, lifecycle retry handling, diagnostics and docs.
**Commit**: `Sprint 12: enforce burned pivot levels`

### Task 12.1: Gate candidate selection by untested levels

- Exclude burned `R1-R3` and `S1-S3` before latest-level selection.
- Burn every level intersected by a newly closed micro candle, even when no
  Bollinger admission, campaign or order occurred.
- Keep the existing same-bar occupancy rule so negative/BE reattempts remain
  possible only inside their original micro candle.

### Task 12.2: Order refresh and catch-up safely

- On a micro transition, finalize the old pivot set before refreshing a macro
  set whose activation starts at the same timestamp.
- Run catch-up before the first eligible detection on init or session re-entry.
- Preserve active positions, local SL/trailing, force closes and symbol/magic
  scope outside the entry session.

### Task 12.3: Validate behavioral scenarios

- Prove an H1 level touched before a 13:30 session cannot arm at 13:30 while an
  untouched sibling level remains eligible.
- Prove a first touch remains usable during its open micro candle but cannot
  arm in later candles.
- Verify multi-level touches, macro rollover, restart, same-bar SL/BE retries,
  positive completion, external/protection closes and all admission guards.
- Complete static behavior/scope review and create one Sprint 12 commit. Do
  not compile before Sprint 14.

### Sprint 12 Gate

- [x] Burned levels cannot create later campaigns in the same macro pivot set.
- [x] Same-bar retries and active-position lifecycle remain unchanged.
- [x] Session catch-up and macro/micro boundary ordering pass review.
- [x] Sprint 12 static validation passes; final compile remains deferred to
  Sprint 14.
- [x] Exactly one Sprint 12 commit is created before Sprint 13 starts.

## Sprint 13: Ticket-Scoped Visual Lifecycle QA

**Goal**: Make campaign tracking and each live position understandable in the
visual tester without allowing chart state to influence trading.
**Dependencies**: Sprint 12 behavior gate.
**Tracked scope**: `HFT_Grid_AI.mq5`,
`services/frontend/pivot_hft_panel.mqh`,
`services/frontend/pivot_hft_visualization.mqh`, Pivot HFT state/detection
accessors, docs and this plan.
**Commit**: `Sprint 13: visualize pivot hft order lifecycle`

### Task 13.1: Render the pending campaign

- Highlight the selected pivot and draw the tracked extreme plus the live
  retracement-entry threshold.
- Distinguish tracking, entry-ready and expired states without recreating chart
  objects on every tick.
- Hide or mute burned levels and mark their first closed-micro-bar test.

### Task 13.2: Render each position by ticket

- Draw actual fill entry and current local SL/trailing line for every managed
  ticket, with direction, ticket, BE state and trailing-step label.
- Update existing objects only when their price/state changes and remove them
  when the position completes.
- Keep non-visual tester mode free of chart objects/comments and remove every
  private object during deinit.

### Task 13.3: Validate readability and cleanup

- Inspect multiple simultaneous hedging tickets, trailing movement, BE, local
  close and forced/external close scenarios.
- Confirm object names are deterministic and ticket-scoped, object count stays
  bounded, and frontend state never feeds detection or execution.
- Complete static object-lifecycle/performance review and create one Sprint 13
  commit. Do not compile before Sprint 14.

### Sprint 13 Gate

- [x] Pending extreme and retracement threshold are visible and accurate.
- [x] Fill, local SL/BE/trailing and step state are visible per ticket.
- [x] Burned-level markers, object update cost and cleanup pass static review.
- [x] Sprint 13 static validation passes; final compile remains deferred to
  Sprint 14.
- [x] Exactly one Sprint 13 commit is created before Sprint 14 starts.

## Sprint 14: Real-Tick QA Regression And Final Handoff

**Goal**: Correlate chart, broker history and audit log across the reported QA
defects, then make the active documentation and release risks current.
**Dependencies**: Sprint 13 visual gate.
**Tracked scope**: final diff, active docs, this plan and temporary validation
artifacts only.
**Commit**: `Sprint 14: complete pivot hft qa regression`

### Task 14.1: Run final static and compile gates

- Review include topology, hot-path work, history scan bounds, symbol/magic
  scope, file-log redaction, chart cleanup and untouched license contracts.
- Run the only post-override MetaEditor compile, require `0 errors, 0 warnings`,
  inspect the current `BUILD.log` and remove it.
- Do not create or run MQL5 harness tests or CI.

### Task 14.2: Run the visual real-tick matrix

- Cover H1 pivots with a 13:30 session, pre-session tests, current-bar burn
  timing, multiple levels, macro rollover and EA restart/re-attach.
- Cover entry trigger, broker fill, local SL, BE, trailing steps, negative/BE
  retry, positive completion, multiple tickets, protection close and debug stop.
- Correlate each chart transition with broker history and `query_debug.txt`.
- Per explicit user instruction, the agent must not launch or manipulate manual
  Strategy Tester QA. The complete matrix and evidence fields are documented in
  `docs/guides/pivot-hft-strategy-inputs.md` for the user's visual run; until
  that run exists, these scenarios remain an explicit release gap.

### Task 14.3: Finalize documentation and handoff

- Update README/input guide with tested-level semantics, file-log location,
  visual object meanings and manual validation checklist.
- Record checks run, checks not run, tester gaps, residual local-SL risk and
  rollback hashes. Do not promote to live use without the manual real-tick
  evidence requested by the project.
- Create one Sprint 14 commit after all available gates pass.

### Sprint 14 Gate

- [x] Final static and MetaEditor compile gates pass; `BUILD.log` is removed.
- [x] Real-tick visual scenarios are explicitly documented as a remaining
  manual gap delegated to the user; the agent did not launch the tester.
- [ ] Chart, history and audit evidence agree for tested levels and lifecycle.
- [x] Active docs, rollback points and residual risks are current.
- [x] Exactly one Sprint 14 commit is created and the plan status is final.

## Sprint 15: Occupied-Level Campaign Arbitration And Audit Throttling

**Goal**: Keep a valid pending campaign alive when a newer touched level is
already occupied, select the next eligible sibling level when possible, and
bound repeated occupied-level diagnostics on the tick path.
**Dependencies**: Sprint 14 static audit evidence; no runtime QA is launched by
the agent.
**Tracked scope**: `services/trading_signals/pivot_hft_levels.mqh`,
`services/trading_signals/pivot_hft_detection.mqh`, Pivot HFT state accessors,
the active input guide and this plan.
**Commit**: `Sprint 15: arbitrate occupied pivot campaigns`

### Task 15.1: Arbitrate occupied candidates

- Evaluate touched, unburned resistance/support levels from newest to oldest
  while skipping levels occupied by an active or same-bar completed campaign.
- Preserve the current pending campaign when the newly preferred level is
  occupied; never reset the global campaign merely because one candidate is
  unavailable.
- Keep position-scoped reattempts able to select their original level inside
  the original micro candle.

### Task 15.2: Bound occupied-level diagnostics

- Emit one `CAMPAIGN_LEVEL_OCCUPIED` record per changed bar/direction/mask
  state, including the selected fallback (or `NONE`) and the active sequence.
- Do not format or write repeated identical occupancy records on every tick.
- Preserve all existing campaign replacement, burn, session, spread, margin,
  protection, market-status and symbol/magic gates.

### Task 15.3: Validate the arbitration boundary

- Complete static candidate-order, same-bar retry, multi-ticket, hot-path and
  include-scope review; do not compile or run manual QA before Sprint 16.
- Record the acceptance evidence and create exactly one Sprint 15 commit.

### Sprint 15 Gate

- [x] Occupied newest levels fall back to an untouched sibling when one exists.
- [x] An occupied candidate cannot erase an unrelated pending campaign.
- [x] Reattempts still target their own level and micro candle.
- [x] Occupancy logs are state-change bounded and static validation passes.
- [x] Exactly one Sprint 15 commit is created before Sprint 16 starts.

## Sprint 16: Complete Close/Run Audit Semantics And Logger Robustness

**Goal**: Make close records distinguish trigger cause from net result, retain
actual exit deal/price evidence, prevent run-id collisions across repeated
tester executions, and make common-file logging resilient for shared instances.
**Dependencies**: Sprint 15 behavior gate.
**Tracked scope**: `microservices/core/enums.mqh`,
`microservices/utils/file_logger.mqh`,
`services/trading_signals/pivot_hft_state.mqh`,
`services/trading_signals/pivot_hft_position_lifecycle.mqh`,
`services/trading_signals/pivot_hft_diagnostics.mqh`, active docs and this plan.
**Commit**: `Sprint 16: harden pivot hft audit semantics`

### Task 16.1: Separate close trigger and net classification

- Record `INITIAL_SL`, `BREAK_EVEN`, `TRAILING` or `EXTERNAL` as the close
  trigger independently from `PROFIT`, `LOSS` or `FLAT` net classification.
- Capture the trigger quote, trigger stop, trailing step/cause and close time
  without changing local protection or same-bar reattempt rules.

### Task 16.2: Correlate the actual exit

- Aggregate close deals by the existing symbol, magic and position-identifier
  scope, retain the latest exit deal ticket and a volume-weighted actual close
  price, and include them in `POSITION_FINALIZED`.
- Keep entry fills, partial close history, daily accounting and protection
  behavior intact; do not weaken fail-closed broker handling.

### Task 16.3: Harden the common-file logger and run identity

- Use a shared append handle with explicit read/write sharing, seek-to-end per
  record, flush and deterministic cleanup; retry once after a transient handle
  failure and warn only once.
- Build the run id with simulated time plus monotonic process/chart tokens so
  identical tester reruns do not collapse into one audit run.
- Update the guide/README with the new close fields and logger guarantees.

### Task 16.4: Final validation gate

- Perform static/diff, secret, include-topology, lifecycle-cleanup,
  symbol/magic-scope and formatting checks. Do not create or run harness/CI or
  manual Strategy Tester QA.
- Run the sole MetaEditor compile after all Sprint 16 changes, require `0
  errors, 0 warnings`, inspect and remove `BUILD.log`, then create exactly one
  Sprint 16 commit.

### Sprint 16 Gate

- [x] Close trigger and net class are explicit and no longer conflated.
- [x] Exit deal ticket, actual close price and trigger evidence are auditable.
- [x] Shared logging survives repeated/shared instances without hot-path open/
  close churn or unbounded retries.
- [x] Unique run ids separate identical tester reruns.
- [x] Final compile passes with `0 errors, 0 warnings` and `BUILD.log` is
  removed.
- [x] Exactly one Sprint 16 commit is created and the plan is current.

## Testing Strategy

- **Unit**:
  - Hand-check classic pivot formulas and latest-level selection.
  - Validate point conversion as `points * SYMBOL_POINT`, tick normalization,
    direction-specific quote selection and trailing-step monotonicity.
  - Exercise constructors, array growth, bounds and state reset paths.
- **Integration**:
  - Native `iBands` handle creation, buffer `1/2` reads, micro-bar timing,
    macro-bar refresh and handle release.
  - Raw `CTrade` request/retcode/deal/fill handling with zero server SL/TP.
  - Hedging ticket registry, symbol/magic filters, close-by-ticket and history
    net-outcome aggregation.
  - Session, spread, margin, daily budget, market-status, drawdown and license
    guards.
- **End-to-end/manual**:
  - Visual tester on US30 with real ticks, micro M1/M3 and macro M30 examples.
  - Sell above upper band at R1/R2/R3 and buy below lower band at S1/S2/S3.
  - Latest-pivot replacement before fill; repeated SL and BE reattempts;
    positive trailing completion; active position surviving bar/pivot refresh;
    multiple simultaneous hedging positions.
- **Non-functional**:
  - One cached indicator handle; no per-tick handle creation, full-history scan,
    unbounded logging or chart-object churn.
  - Fail closed for invalid handles, unsupported margin mode, missing license
    magic and impossible volume/margin conditions.
  - Explicit residual risk review for local-only protection during disconnect,
    disabled Algo Trading or broker close-only states.

## Risks And Gotchas

| Risk | Impact | Mitigation | Validation signal |
| --- | --- | --- | --- |
| Local SL/TP are not on the server | Large unprotected exposure during terminal, network or Algo Trading failure | Preserve market-status behavior, log active local protection state, require demo validation and document the risk prominently | Disable trading/network path in tester/demo and confirm no false local close is reported |
| Netting account merges same-symbol positions | Individual campaigns lose independent fill/trailing state | Fail closed unless `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING` | Margin-mode gate and multiple-ticket test |
| US30 point size differs by broker | 25 points may represent different price movement | Use existing `SYMBOL_POINT` convention and log symbol point/tick metadata once | Compare `_Point=0.1` and other symbol configurations |
| Current micro close crosses several pivots | Duplicate pending orders or nondeterministic level choice | One pending campaign; latest valid level replaces previous | Multi-level crossing scenario selects highest R or lowest S |
| Broker returns `true` but no deal | Phantom local position or wrong anchor | Require retcode, deal and actual ticket before active state | Forced retcode/rejection test |
| Multiple active positions grow risk rapidly | Margin exhaustion and drawdown | Preserve spread/margin/daily/protection guards and exact hedging scope; monitor active count | Multi-position and no-money tester scenarios |
| Local close fails while target is hit | Position remains open beyond intended local target | Keep state active, retry close under broker-action permissions, record retcode | Forced close failure and recovery scenario |
| Indicator data is unavailable or stale | False pivot/Bollinger signals | Cached handle, minimum-bars checks, new-bar refresh and tester fail-fast | Invalid handle/history scenario |
| Legacy grid/Pandora references survive cleanup | Conflicting order paths or compile regressions | Dependency scan before deletion and compile after each cleanup batch | Final `rg` scan and call-graph review |
| License identity is partly renamed | Backend entitlement or magic mismatch | Leave `services/license_service_setup.mqh` and shared guard untouched | Live/tester startup and magic-scope review |

## Rollback Plan

- Roll back one sprint at a time in reverse order, starting with the latest
  known-good commit recorded at each Sprint Gate.
- If final tester behavior fails, stop before demo/live use and return to the
  Sprint 7 cleanup rollback point; if cleanup itself is unsafe, return to the
  Sprint 6 integrated-but-not-cleaned path.
- If raw execution or local lifecycle is unsafe, revert to the last commit that
  compiled without the new order path and do not restore Pandora trading logic
  piecemeal.
- Never restore old Pandora includes while leaving new state arrays active; use
  a complete sprint commit so the include graph and lifecycle state match.
- Do not alter or roll back shared license backend files as part of strategy
  rollback. Keep the existing license/magic contract in every state.
- Remove temporary `BUILD.log` and rotate `query_debug.txt` after diagnostics;
  do not use stale logs as validation evidence.

## Execution Order

1. Implement Sprint 1 only.
2. Run and record all Sprint 1 validation.
3. Create exactly one Sprint 1 commit and record its rollback point.
4. Start Sprint 2 only after the Sprint 1 gate passes.
5. Repeat the gate for each sprint in order; because this plan is critical and
   trading-sensitive, execute exactly one sprint per batch.
6. Execute Sprint 9 only after Sprint 8, using one compile and one commit.
7. Stop and revise this plan if implementation reveals a missing risk,
   lifecycle dependency, unsafe broker assumption or license contract change.

## Completion Checklist

- [x] Every sprint has passed its authorized static/compile validation gate.
- [x] Every sprint has exactly one sprint-specific commit.
- [x] Final MetaEditor compile passes and `BUILD.log` is removed.
- [ ] Real-tick US30 visual/manual validation is recorded.
- [ ] Hedging-only behavior, multiple tickets and symbol/magic scope are proven at runtime.
- [ ] Local SL/BE/trailing, negative/BE reattempt and positive completion are proven at runtime.
- [x] Session, spread, margin, daily, drawdown, market-status and license guards remain active in the compiled graph.
- [x] Residual risk from no server SL/TP is documented and demo approval is explicit.
- [x] Rollback points, remaining tester gaps and changed files are included in the handoff.

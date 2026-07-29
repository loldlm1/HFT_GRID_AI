# Market Data Broker Executor Simplification Closeout

**Archived**: 2026-07-29
**Status**: Complete
**Active schema**: v8

## Summary

The six-sprint refoundation is complete. The EA is now an always-on M1
extremum market-data collector with one small, hedging-only broker execution
path, deterministic broker/analysis timestamps, mandatory broker checks, one
ticket per accepted attempt, broker-side SL, and fixed 1R TP.

## Archived Plan

- `market-data-broker-executor-simplification-plan.md`

## Final Acceptance

- Exact public surface: six input groups and eleven fields.
- Final source footprint: 41 tracked MQL5 files and 13,559 lines, down from 81
  files and 30,882 lines.
- Python compile and all 17 existing schema/research tests passed.
- Real MetaEditor compile passed with `0 errors, 0 warnings` in 50,490 ms.
  The ignored log is `logs/compile/agentic-build.log`; the regenerated
  `HFT_Grid_AI.ex5` inspected on 2026-07-29 is 442,517 bytes.
- Human Strategy Tester/chart acceptance passed on 2026-07-29. Winter US30
  normalized `14:30 -> 13:30` at `-60`; summer kept `13:30 -> 13:30` at `0`.
  Fixed-time equality and spring US/UK DST transitions also passed.
- The winter run reconciled 143 cycles, 1,380 attempts, 4,400 execution checks,
  and 313 broker outcomes. The summer run reconciled 137 cycles, 1,380
  attempts, 4,080 checks, and 329 outcomes.
- Invalid volume and insufficient margin each produced 15,170 blocks with no
  sends or tickets. One invalid-stops send was broker-rejected, exported as an
  `order_send` block, and produced no ticket.
- All accepted pre-send geometries were exactly 1R. The 313 inspected winter
  closes had 313 unique tickets with broker-side SL/TP.
- Export-disabled runtime was 3.779 seconds and export-enabled runtime was
  7.678 seconds for the same one-day tester period.

Generated Common Files runs, Parquet datasets, compile logs, binaries, query
debug output, and screenshots remain external/ignored evidence.

## Commit Sequence

- Sprint 1: `6a8e978` - `refactor: remove legacy commercial and runtime gates`
- Sprint 2: `c9d39dd` - `refactor: reduce execution to one broker position`
- Sprint 3: `377181e` - `feat: export deterministic broker checks in schema v8`
- Sprint 4: `641e326` - `refactor: cut research tooling over to schema v8`
- Sprint 5: `322db7d` - `docs: align the market data broker executor foundation`
- Sprint 6: `chore: validate market data broker executor refoundation` - the
  commit containing this archive is the final rollback point.

## Restrictions And Residual Risks

- This closeout does not authorize live rollout. Old-version positions must be
  flat, the account must use retail hedging, and only one EA instance may run
  per account and symbol before a future deployment plan proceeds.
- Schema v8 model artifacts remain research-only and are not approved for MT5
  runtime inference.
- The autumn 2026 DST replay remains a post-date operational check. Winter,
  summer, and spring US/UK transition behavior passed the available acceptance
  periods.
- Holidays, one-off broker schedule changes, maintenance pauses, and missing
  ticks remain broker facts; the collector does not synthesize absent data.

Start a new explicitly invoked `$planner` plan for live rollout, another schema,
runtime model approval, broker-specific calendar changes, or a new execution
strategy.

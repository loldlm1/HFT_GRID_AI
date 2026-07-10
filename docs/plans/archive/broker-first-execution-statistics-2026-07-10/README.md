# Broker-First Execution Statistics Closeout

**Archived**: 2026-07-10
**Status**: Complete

## Summary

The broker-first execution/statistics alignment work is complete and archived.
The EA now separates candidate/admission events from broker-confirmed outcomes,
supports broker-side partial TP legs, records leg-level outcomes, gates partial
TP statistics on broker confirmation, and exports signal-level `profit_r` using
broker net R for broker-confirmed outcomes.

## Archived Plans

- `broker-first-execution-statistics-alignment-plan.md`
- `partial-tp-broker-first-multi-ticket-plan.md`
- `partial-tp-async-broker-confirmation-plan.md`
- `broker-outcome-profit-r-alignment-plan.md`

## Final Validation

- MetaEditor compile passed with `0 errors, 0 warnings`.
- Latest audited Strategy Tester run:
  - run id: `xauusd_2025_dataset_1`
  - `features=880`
  - `outcomes=879`
  - `legs=2637`
  - `joined=879`
  - `entry_delta_counts`: all partial TP legs at `0.0s`
  - `BROKER_PROFIT` rows with non-positive `profit_r`: `0`
  - `BROKER_LOSS` rows with non-negative `profit_r`: `0`
- Remaining expected validation warning:
  - one broker-entered feature row had no broker-close/outcome inside the
    one-month tester range and is excluded from supervised training.

## Related Research

See:

- `docs/research/archive/broker-first-execution-statistics-2026-07-10/`

## Follow-Up Policy

Start a new plan under `docs/plans/` for any future substantial change to
execution lifecycle, broker admission, lot sizing, partial TP semantics, or
statistics schema.

# Macro/Micro Pivot V10 Short-Run Audit - 2026-08-06

## Disposition

The human XAUUSD real-tick Strategy Tester run is valid diagnostic evidence for
`PIVOT_FRACTAL_V2` and strict schema V10. The trading runtime, exported dataset,
offline audit, and offline training flow pass the checks performed here.

One corrective issue is limited to `query_debug.txt`: attempt and terminal line
prefixes use log-emission time instead of immutable event time, and denied
attempts render unavailable request facts as numeric values. Sprint 9 corrects
that diagnostic ambiguity without changing trading, risk, V10, or model
behavior. This run is not final human acceptance and does not authorize live
rollout.

## Evidence Identity

- Symbol and setup: `XAUUSD`, `EXNESS_SESSION`, Macro `H1`, Micro `M3`,
  `PRICE_WEIGHTED` Bands, reference-balance percentage `0.01` of `1,000,000`.
- Tester interval: `2026.06.08 00:00:00` through
  `2026.07.31 20:57:59` broker time.
- V10 run ID: `test_run_1`.
- Runtime export: six files under external Common Files
  `PivotFractalV10/runs/test_run_1`.
- Debug file: external Common Files `query_debug.txt`, 5,742 lines, 2.2 MB,
  SHA-256 `4c5428dd7999b1c17a6a5f615d13749e44cc131331c9bd2cbd5fb2186649b7b3`.
- V10 folder size: 8.5 MB.
- Ignored research artifacts:
  - `artifacts/datasets/test_run_1_acceptance_20260806` - 2.4 MB;
  - `artifacts/audits/test_run_1_acceptance_20260806` - 28 KB;
  - `artifacts/models/test_run_1_acceptance_20260806` - 3.2 MB.

## Deterministic Exness Time

All 20,775 exported broker/analysis/offset timestamp triples satisfy:

```text
analysis_time = broker_time + offset_minutes
```

Every row has offset `0`, which is correct for XAUUSD during the UK DST period
covered by June-July 2026. Static review confirms that XAU/XAG/XPT/XPD prefixes
select the UK calendar, including broker suffixes, and that the 2026 policy is:

| Broker timestamp | Analysis offset |
| --- | ---: |
| Before `2026.03.29 01:00:00` | `-60` minutes |
| `2026.03.29 01:00:00` through `2026.10.25 00:59:59` | `0` minutes |
| From `2026.10.25 01:00:00` | `-60` minutes |

Normalization remains export-only. Raw broker time still owns windows,
triggers, checks, orders, reconciliation, duration, and chronological splits.

This run empirically proves the summer branch only. The code path is
deterministic across seasons, but a short winter or transition-boundary human
run remains required in Sprint 10 for broker-side empirical confirmation.

## Query Debug Reconciliation

The debug log contains one session header and exactly one line for every
expected event:

| Event | Debug rows | Matching V10 rows | Missing/extra IDs |
| --- | ---: | ---: | ---: |
| `PIVOT_ATTEMPT` | 1,922 | 1,922 attempts | 0 |
| `PIVOT_SEND_RESULT` | 1,910 | 1,910 send-result checks | 0 |
| `PIVOT_TERMINAL` | 1,909 | 1,909 outcomes | 0 |

Stable fields reconcile with no unexplained mismatch: window/signal identity,
timeframe, level, direction, trigger quote, structural SL, sent request
geometry, normalized volume, quote expectations, broker retcode/comment,
order/deal/position identity, terminal reason, gross/net result, and binary
classification.

The one send failure is consistent in both sources:

```text
signal_id=sig_14884156845125308774
retcode=10016
comment=Invalid stops
block=order_send:api=false|retcode=10016|error=4756|comment=Invalid stops
```

The 12 denied attempts are also correct operationally. A gap placed the fresh
entry beyond the captured structural stop, so the controller failed closed with
`STRUCTURAL_STOP_WRONG_SIDE_OF_FRESH_ENTRY` before `OrderSend`.

Two diagnostic rendering defect classes were localized:

- 95 attempt prefixes are one second later than immutable
  `trigger_broker_time`; send/reconciliation completed after the trigger second
  before the attempt line was emitted.
- Two terminal prefixes are one second later than broker `close_broker_time`.
- All 12 denied attempt lines print a fresh entry plus zero request/volume/quote
  facts, although no broker request exists. V10 correctly stores request facts
  as null and preserves the configured reference risk budget of `100`.

These are debug-output semantics only. They do not alter signal state, broker
authorization, exported V10 facts, or outcomes.

## Strict V10 And Independent Structure Audit

Strict validation passed:

```text
schema V10 validation ok | runs=1 | attempts=1922 | outcomes=1909
```

The natural summary reports:

- 910 Macro windows;
- 1,922 attempts and 7,663 execution checks;
- 1,909 broker-confirmed outcomes;
- 1,922 complete feature snapshots and zero incomplete snapshots;
- 951 TP, 957 SL, and one excluded manual close;
- 12 denied attempts and one failed send;
- zero duplicates, referential errors, or row-integrity errors;
- `export_status=OK` and `completion_status=NATURAL`.

An independent read-only audit reproduced the core contracts with zero
violations:

- classic PP/S1-S3/R1-R3 formulas, tick normalization, and strict ladder order;
- previous completed H1 source ownership and causal window times;
- PP role, support-buy/resistance-sell direction, and inclusive Bid triggers;
- all eight structural SL routes and fresh Bid/Ask price-distance 1R geometry;
- `100` account-currency reference risk, normalized volume ordering, and denied
  request nullability;
- Micro shift-0 width, normalized width, and `%B`; Macro shift-1 width and pivot
  `%B`;
- six multi-candidate shared-quote groups with identical shared Micro feature
  snapshots;
- contiguous execution-check sequences and expected lifecycle patterns;
- immutable outcome SL/TP, volume closure, duration, cost sums, adverse-positive
  entry/exit slippage, R values, and strict binary classification.

Observed level coverage includes every family: 689 PP, 407 S1, 183 S2, 72 S3,
367 R1, 148 R2, and 56 R3 attempts.

## Research Flow

The complete run produced 1,922 `research_matrix` rows and 1,908 strict
`binary_outcomes` rows. The audit reports a 49.84% TP rate and keeps the one
manual close separate from binary performance.

Offline XGBoost training completed all four deterministic ablations on 1,908
rows:

| Ablation | ROC AUC | Balanced accuracy |
| --- | ---: | ---: |
| Base | 0.5466 | 0.5505 |
| Widths | 0.5540 | 0.5484 |
| Micro `%B` | 0.5517 | 0.5336 |
| Macro pivot `%B` | 0.5312 | 0.5320 |

These values are a smoke test, not a profitability conclusion. Approval remains
`OFFLINE_RESEARCH_ONLY`, and no MT5 runtime artifact was emitted.

## Corrective Resolution And Remaining Human Work

Sprint 9 completed the diagnostic-only correction:

1. attempt/send/terminal debug lines now use captured trigger, send-check, and
   broker-close event times;
2. unavailable denied-request facts now render as `n/a`;
3. configured reference risk is distinct from an absent request plan, while
   fixed-lot mode reports no reference budget;
4. Python compileall and all 23 existing contract tests passed;
5. the final MetaEditor compile regenerated `.ex5` with
   `0 errors, 0 warnings`.

The compiler result was `Result: 0 errors, 0 warnings, 6396 ms elapsed,
cpu='X64 Regular'`. The regenerated binary is 163,142 bytes with SHA-256
`0e023a5441469021edd46858e6432d7a0c740328442ef508c70f6a6bb9957376`.

Sprint 10 still requires the user's renewed human evidence for winter/boundary
time behavior, selected Data Window Bands values, visual/nonvisual behavior,
and paired export-disabled/export-enabled performance. Older-engine positions
must remain flat, and live rollout remains unauthorized.

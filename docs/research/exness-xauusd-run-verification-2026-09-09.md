# XAUUSD Exness V13 Run Verification - 2026-09-09

## Result

`EXNESS_SESSION` and H1/M10/M3 are correct for the existing Exness workflow.
The tester completed successfully, but this run does **not** receive a clean
V13 data-acceptance pass: 1,109 broker-parent deep censor rows disagree with
their parent's recorded close time. This is independent of the analysis-time
offset setting. Preserve the run as evidence pending correction and acceptance.

Run: `Common/Files/PivotFractalV13/runs/XAUUSD_Exness_Run_2015/`.
Symbol: `XAUUSD_Exness_2015`. Configuration: `cfg_16903817463078901211`.

## Confirmed Tester And Export Facts

- Tester journal: **generating based on real ticks**; test passed in
  `7:43:11.625`, with 332,994,255 ticks and 1,223,906 M3 bars.
- Requested interval: `2015-08-10 00:00` to `2026-09-08 00:00` exclusive.
- MT5 explicitly moved the actual start to `2015-08-11 00:00` to provide
  beginning history. August 10 supplies 461 M3 bars, 139 M10 bars and 24 H1 bars.
- The prepared source contains 333,083,223 ticks. August 10 contains 88,968;
  subtracting that warm-up day gives exactly the tester's 332,994,255 ticks.
  This reconciles counts; it is not an exhaustive tester tick-by-tick re-export.
- Actual export ends at `2026-09-07 23:59:58`, with `export_status=OK` and
  `completion_status=NATURAL`. File metadata remained unchanged during auditing.
- Manifest and tester inputs agree: `EXNESS_SESSION`, H1/M10/M3,
  `Lot_Type=EXECUTION_LOT_REFERENCE_BALANCE_PERCENT`, `Lot_Strategy_Size=0.001`.
  The tester records a 50 ms execution delay.
- All twelve expected TSV files are present, totaling 14,759,900,517 bytes.
  Ten fact tables contain 34,394,222 rows, matching the summary's file counts.
- The producer reports zero duplicate, reference and row-integrity errors.
  Active-state peaks remain below their declared caps, with zero capacity
  rejections. These producer counters do not cover the censor-time defect below.

## Confirmed Validation Failure

The full-file relational audit finds 1,109 `CENSORED_PARENT_EXIT` outcomes across
513 links, 491 deep events and 264 broker parents with terminal times later than
`broker_outcomes.close_broker_time`:

| Difference | Outcome Rows |
| --- | ---: |
| +1 second | 1,073 |
| +2 seconds | 30 |
| +3 seconds | 6 |

Every affected parent is `BROKER`; virtual-parent censor timestamps match.
All affected outcomes retain `virtual_binary_eligible=0` and a null binary target.
They have not been relabeled as wins or losses.

Example: parent `broker_17399006381623350226` closes at
`2015.08.13 05:55:04`, while linked outcome
`deep_outcome_11871739768232891951` is censored at `2015.08.13 05:55:06`.

The producer's
[`BuildDeepPivotParentExitOutcome`](../../services/trading_signals/deep_pivot_lifecycle.mqh)
uses the current observation tick's time. Broker reconciliation separately records
the authoritative close-deal time. The strict
[V13 validator](../../tools/deterministic_signal_ml/schema_contract.py)
requires those censor and parent terminal timestamps to agree.

The unchanged `_validate_deep` was executed on one complete original event
slice: one event, 19 parent links, three deep trials and 57 deep outcomes, plus
their original window/origin/parent dependencies. It rejects the slice with
`parent-exit censor time mismatch`. This independently confirms the relational
audit finding without loading the whole run into Python dictionaries.

Resolve this producer/contract inconsistency and validate a fresh, separately
identified export before accepting the run or starting equivalent long runs.
Do not overwrite the existing evidence or relax the validator to declare it clean.
No EA source, input, terminal setting, imported history or run TSV was changed
during this verification.

## Session Setting For All Four Symbols

| Custom Symbol | Setting | Calendar Used By Current EA |
| --- | --- | --- |
| `XAUUSD_Exness_2015` | `EXNESS_SESSION` | UK metals |
| `EURUSD_Exness_2015` | `EXNESS_SESSION` | US default |
| `GBPJPY_Exness_2015` | `EXNESS_SESSION` | US default |
| `BTCUSD_Exness_2017` | `EXNESS_SESSION` | US default |

The suffixes preserve the base-symbol classification. In the current
[`market_data_time.mqh`](../../services/utils/market_data_time.mqh), summer
analysis time equals broker time; winter analysis time is broker time minus
60 minutes. UK transitions use the last March/October Sunday at 01:00 on the
broker clock. US transitions use the second March/first November Sunday at 02:00
on that clock. This describes the implemented research calendar; it is not a
claim that imported UTC ticks have a local London or New York timezone.

All 18 exported timestamp-triplet groups in this XAUUSD run satisfy both the
arithmetic and the implemented UK calendar across every row. H1 origins include
78,095 summer-offset rows and 52,547 winter-offset rows.

`Broker_Session` is used for export normalization, configuration identity and
logging. It does not shift ticks, candles, pivot identities, durations or broker
execution. Actual trading-session checks use `SymbolInfoSessionTrade` and broker
time independently. BTCUSD receives the same analysis policy even though its
trading schedule differs from FX/metals. Keep the existing Shift=0 imports.

## Scope And Retained Evidence

The bounded DuckDB audit reused the maintained schema's headers, types and
manifest validation. It scanned every fact file and checked identities,
timeframes, counts, timestamp triplets, selected joins, eight H1 lanes, three deep
trials/outcomes, completed durations, parent intervals and binary labels.
Of 89 recorded checks, 88 pass and the parent-exit censor check fails.

The full `build_dataset.py --validate-only` command was **not run**. Its current
implementation materializes all TSV rows as Python dictionaries and repeatedly
searches H1 outcomes for deep parents. The bounded audit and focused unchanged
validator reproduction do not certify all other semantic, geometry, feature or
money rules. Fifteen H1 origins and three deep events explicitly report incomplete
feature snapshots; their flags remain intact.

Local evidence under `.codex-artifacts/v13-run-audit-20260909/`:

- `structural-time-report.json` and `verify_run.py`: counts, checks, source metadata
  and code hashes; no full duplicate run retained.
- `tester-evidence.json`: filtered, account-redacted startup/completion evidence.
- `tick-count-reconciliation.json`: reuse of previously audited full H1 source bars.
- `parent-censor-detail.json`: affected counts, time deltas and examples.
- `strict-validator-reproduction.json` and `reproduce_censor.py`: unchanged
  validator rejection on the original event slice. Its row number is local to
  that slice, not the original multi-million-row TSV.

The prior [custom-symbol audit](exness-custom-symbol-alignment-2026-09-09.md)
still governs import and broker-equivalence scope. Full broker equivalence remains
`INCONCLUSIVE`. This run verification does not add a deployment approval.

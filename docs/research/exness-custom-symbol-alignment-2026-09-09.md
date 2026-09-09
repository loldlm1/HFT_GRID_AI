# Exness Custom-Symbol Alignment - 2026-09-09

The four custom symbols map to the intended broker instruments and preserve
the prepared source history under the checks below. Their ticks and candles
are not identical to the connected broker feed. Full specification/P&L parity
and formal broker-equivalence acceptance remain unverified.

This read-only audit used the connected Exness demo account (USD, hedging),
MT5 build 6184, with 100,000 chart bars configured.
No symbol properties, histories, settings or trading state were changed.

## Mapping And Import Checks

| Custom symbol | Broker | Source ticks / native tick volume | H1 bars | H1 mismatches |
| --- | --- | ---: | ---: | ---: |
| `XAUUSD_Exness_2015` | `XAUUSD` | 333,083,223 | 61,549 | 0 |
| `EURUSD_Exness_2015` | `EURUSD` | 168,825,623 | 68,464 | 0 |
| `GBPJPY_Exness_2015` | `GBPJPY` | 204,237,488 | 68,183 | 0 |
| `BTCUSD_Exness_2017` | `BTCUSD` | 312,330,265 | 67,396 | 0 |

For every symbol, all 24 exposed core properties match: digits, point,
contract size, currencies, calculation mode, volume limits/step, execution
and filling modes, stops/freeze levels, margins, swaps and floating spread.

Every one of the 265,592 native H1 Bid OHLC/tick-volume rows
matches an independent exact-decimal aggregation of the retained source TSV.
The total is 1,018,476,599 ticks, including repeated ticks.
The scan also reconciles every daily source count. Coverage ends at
2026-09-08 00:00 UTC exclusive and starts at each file's first source tick.

The bounded streaming H1 aggregator reuses the maintained exact source parser.
It matches the independent DuckDB result over the entire EURUSD history and
all 12 already-audited native H1 sample captures. Both engines and their
input/output hashes are recorded in the local evidence.

The maintained `freeze-capture`/`audit-capture` service additionally verifies 69,129
ticks in 12 one-hour windows: 12:00-13:00 on 2026-01-14, 2026-07-15 and
2026-09-07 for each custom symbol. All 12 preserve exact timestamps, Bid/Ask,
duplicate multiplicity and order. July and September M1/M3/M10/H1 native bar
checks also pass. January has the reader limitations recorded below.

This is full-history H1 verification plus exact sampled tick verification.
An exhaustive native tick-by-tick re-export of all four histories was not run.

## Broker Feed Differences

The September 7 comparison covers 12:00-13:00 UTC. Each broker capture passes
its own tick-derived M1/M3/M10/H1 bar audit. Comparing the custom and broker
captures then produces these differences:

| Broker | Custom ticks | Broker ticks | M1 candles with different OHLC / 60 | Largest M1 OHLC difference (price units) |
| --- | ---: | ---: | ---: | ---: |
| `XAUUSD` | 7,403 | 7,404 | 43 | 0.342 |
| `EURUSD` | 1,371 | 822 | 40 | 0.00004 |
| `GBPJPY` | 4,133 | 3,624 | 31 | 0.006 |
| `BTCUSD` | 3,676 | 3,632 | 51 | 4.55 |

The available paired samples support Shift=0, with median broker delays
around 37-40 ms. This does not certify every historical clock regime.
Exact broker tick identity fails for all four symbols. The observed EURUSD
price differences are much larger than its approved <=1e-16 representation
normalization. These diagnostic measurements are not a calibrated acceptance
under a pinned broker-comparison profile.

## Unverified Evidence

- The MCP reader reports broker tick size and tick value as zero for all
  four instruments. Positive custom values cannot prove equality to those
  unavailable broker values. Chart mode and quote/trade sessions are also
  absent from the reader, so full specification/P&L parity remains open.
- January M1 responses are empty for all symbols; BTCUSD January M3 is also
  unavailable. These are recorded as missing native evidence, with raw
  responses retained, rather than accepted as empty trading periods.
- XAUUSD January/July broker tick reads remain empty after a retry. Their
  native bar responses do not substitute for complete broker ticks.
- GBPJPY January broker native bars report 4,363 H1 ticks against 4,368
  captured broker ticks. Its own tick-volume consistency audit fails; the
  custom-symbol source comparison passes.
- This reader advertises broker tick availability from January 2026.
  It cannot establish broker tick parity for the earlier archive years.

## Reproducible Evidence

Raw responses preserve their original JSON numeric text. Request limits,
intervals, frozen hashes, per-sample service audits, full H1 captures and
reports remain under ignored `.codex-artifacts/exness-alignment-20260909/`.
The compact result is `alignment-report.json`; retained scripts record the
exact aggregation and service calls. Frozen sample captures can be replayed
offline with `audit-capture`, writing to a fresh report path.

The [source preparation record](exness-single-file-preparation-2026-09-09.md)
retains the TSV coverage, policies and checksums. The
[service documentation](../../tools/exness_tick_history/README.md#capture-once-audit-offline)
and [workflow](../workflows/exness-tick-history.md) describe the separate
registered round-trip, specification and broker acceptance gates.

# Exness Tick History

An offline Python CLI for immutable Exness archives and MT5 research input.
Python 3.11+ is required (`tomllib`); the validated environment is Python 3.12
with DuckDB 1.5.4. Run from the repository root:

```bash
.venv/bin/python -m pip install -r tools/exness_tick_history/requirements.txt
.venv/bin/python -m tools.exness_tick_history --help
.venv/bin/python -m tools.exness_tick_history inspect-config
.venv/bin/python -m tools.exness_tick_history probe-archive --year 2026 --month 9 --day 1
.venv/bin/python -m tools.exness_tick_history inspect-archive <local.zip> --year 2026 --month 9 --day 1
.venv/bin/python -m tools.exness_tick_history inventory --start 2026-08-01 --end 2026-09-02 --granularity auto
.venv/bin/python -m tools.exness_tick_history download --inventory <inventory_id> --resume
.venv/bin/python -m tools.exness_tick_history build --inventory <inventory_id> --dataset-id <new_dataset_id>
.venv/bin/python -m tools.exness_tick_history audit --dataset-id <dataset_id>
.venv/bin/python -m tools.exness_tick_history export-mt5 --dataset-id <dataset_id> --export-id <new_export_id> --specification <spec.json> --clock <clock.json>
.venv/bin/python -m tools.exness_tick_history compare-roundtrip --export-id <export_id> --native-export <native.tsv> --evidence <native-evidence.json>
.venv/bin/python -m tools.exness_tick_history seasonal-schedule --year 2026
.venv/bin/python -m tools.exness_tick_history compare-broker --dataset-id <dataset_id> --reference <reference.json> --roundtrip-report <roundtrip-report.json> --comparison-id <new_comparison_id>
.venv/bin/python -m tools.exness_tick_history seasonal-report --year 2026 --comparisons <winter_id> <summer_id> <transition_ids>
.venv/bin/python -m unittest discover -s tools/exness_tick_history/tests -p 'test_*.py'
```

Copy `profiles/xauusd_pro.example.toml` to the ignored data root for private
configuration. Pass `--config <path>` before the command. Explicit dates mean
`[start, end)` in UTC; `latest-published` is resolved during inventory. Archive
symbol, broker suffix/override, account type and live/demo mode are independent.
Use a different profile ID for each account/feed. The source CSV does not prove
that the selected archive matches a Pro account.

`inspect-config` performs no writes, network calls or terminal actions. Exit 2
means configuration error; exit 3 means unavailable source or failed integrity;
exit 130 means interruption. Reports distinguish incomplete evidence from a
demonstrated mismatch. Secrets are not accepted in configuration; urllib honors
the operator's existing proxy environment without printing its values.

The archive host may work when the Exness selection page returns 403. A denied
request does not establish missing history or a market holiday. This tool does
not control a VPN. Never change raw timestamps or quotes to obtain a match.

Inventory freezes a UTC cutoff, HEAD evidence, estimated bytes and disjoint
source intervals in `runs/<inventory_id>/inventory.json`. Auto mode prefers
whole completed years, then months, then days. Explicit year/month modes may
fetch extra container days for a subrange; inspect `extra_container_days` and
the byte estimate before downloading. Missing larger containers fall back to
smaller ones only after 404. Access failures remain distinct from unavailable
URLs. A latest-publication HEAD is a candidate until body/coverage validation.

Downloads stream through `partial/`, verify size, ZIP limits and CRC, then
publish under `archives/<sha256>/`. The SQLite ledger records verified objects.
Repeat the same command to verify and reuse completed bytes. Ctrl-C retains
owned partials; `--resume` uses them only when validator, size and byte range
agree. Without `--resume`, only disposable partials restart. A changed source
requires a fresh inventory; previous archive versions remain intact. Run one
writer per data root. A stale lock file is harmless once its OS lock is released;
never delete another process's active lock. Incomplete downloads exit 3 and
write details to `runs/<inventory_id>/download-status.json`.

Build writes ordered UTC-date Parquet partitions with `DECIMAL(38,12)` quotes
and source archive/member/row provenance. Quotes outside the supported exact
range or precision are quarantined, never rounded. A day is sorted by timestamp
and original row number; byte-identical source rows remain separate ticks.
Each source is spooled on disk before per-day DuckDB sorting, with four open
spool files, 4,096-row read batches, one database thread and configured memory/
spill limits. Memory limits apply to DuckDB's buffer manager, not total RSS.
Budget about twice the largest expanded source for working storage, plus
retained ZIPs, Parquet, future MT5 text/history, and the configured reserve.

Interrupted builds resume completed sources/partitions in `<dataset_id>-partial`.
The final directory appears only after row conservation and manifests are
written. Source spools are removed after their partitions are published to
staging; raw ZIPs remain. Reusing an ID with changed inputs fails. IDs ending
in `-partial` are reserved. Invalid rows and reasons remain in the dataset's
source-hash directory, alongside `source-summary.json`.

`quality.json` reports conservation, regressions, precision and report-only
spread/jump flags. Each date has `activity.json` with minute/hour counts and
unreviewed gaps over 60 seconds. Dates with no ticks remain unknown closures.
`audit` rechecks physical and ordered logical hashes. Exit 4 means inconclusive
coverage; exit 3 means failed integrity. An integrity pass concerns the supplied
archive and transformation; it does not prove missing intraday ticks never
existed, native import equality, or broker equivalence.

Export requires reviewed local copies of `profiles/specification.example.json`
and `profiles/clock.example.json`. Both examples intentionally fail verification.
Fill the native properties, captured symbol list and `feed_sha256` printed by
`inspect-config`; record the actual evidence before setting `operator_verified`.
Sessions use weekday 0=Monday and seconds within the day; split overnight
sessions at midnight. Clock intervals are UTC, contiguous, explicit and
reversible. Ambiguous backward clock changes block export of that map.

The native package uses ASCII, tabs, one header line, zero Last/Volume and
Shift=0. Files are ordered in `exports/<export_id>/import-manifest.json`.
`--chunk-rows` is a soft row bound because equal-time groups stay intact.
The source UTC dataset is unchanged. Unknown coverage remains visible in the
export; quarantined/empty data cannot export. Do not select a partially imported
symbol for accepted research. Use a new export ID and custom symbol whenever
the data, specification or clock changes.

Native re-exports require explicit milliseconds and all six columns. Choose
`--encoding utf-16` for a BOM-bearing native UTF-16 export; default is UTF-8
with optional BOM. Exact quote equality can pass while `mt5_round_trip` remains
inconclusive until metadata and all four native timeframe bar files are supplied.
See the workflow for the evidence schema and guided native steps.

Broker comparison accepts complete native TSV or MCP JSONL captures. It uses
one-to-one chronological matches within the pinned time delta and never reuses
a broker tick. Price-error quantiles describe matched pairs; unmatched counts
and fractions on each feed remain mandatory independent gates. Minute/hour
activity, session segments, day boundaries, tied-order defects and diagnostic
hour shifts remain visible. Native Bid OHLC and completed-bar pivot inputs are
compared at M1/M3/M10/H1. Twenty-six real prior bars per period are required for
warm-up; only the selected day contributes to scored bar metrics.

Comparison reports are immutable JSON/Markdown under `comparisons/<id>/`.
Native acceptance needs the matching successful round-trip report. Unpinned
limits, unidentified feeds, incomplete captures and missing warm-up cannot
produce acceptance. Profile pinning requires every numeric threshold plus
name, rationale, UTC pin time and separate pilot dates. The comparator records
the profile hash; do not change thresholds after scoring an acceptance day.

`seasonal-report` reports winter/summer sample acceptance separately from the
broader clock-regime diagnostics. Future transition dates remain untested.
Neither result certifies every historical year or real broker execution.

See the [workflow](../../docs/workflows/exness-tick-history.md) for the source,
terminal and acceptance contract. Native MT5 checks are pending until the
operator completes the guided steps after the implementation batch.

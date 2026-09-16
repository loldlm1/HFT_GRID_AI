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
.venv/bin/python -m tools.exness_tick_history freeze-capture --requests <capture-requests.json> --output <capture-frozen.json>
.venv/bin/python -m tools.exness_tick_history audit-capture --capture <capture-frozen.json> --expected-ticks <import.tsv> --expected-sha256 <sha256> --score-day <YYYY-MM-DD> --report <audit.json>
.venv/bin/python -m tools.exness_tick_history seasonal-schedule --year 2026
.venv/bin/python -m tools.exness_tick_history compare-broker --dataset-id <dataset_id> --reference <reference.json> --roundtrip-report <roundtrip-report.json> --comparison-id <new_comparison_id>
.venv/bin/python -m tools.exness_tick_history seasonal-report --year 2026 --comparisons <winter_id> <summer_id> <transition_ids>
.venv/bin/python -m tools.exness_tick_history storage-plan --inventory <full_inventory_id> --pilot-dataset <pilot_dataset_id>
.venv/bin/python -m tools.exness_tick_history network-check --year 2026 --month 9 --day 1
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

## One Persistent MT5 File Per Symbol

`prepare-mt5-file` prepares one reusable `<SYMBOL>_ticks.tsv` plus a checksum and
coverage manifest in an explicitly selected visible directory. It accepts a
frozen inventory directly and downloads missing sources as it processes them:

```bash
.venv/bin/python -m tools.exness_tick_history --config <symbol-profile.toml> \
  inventory --start 2015-01-01 --end latest-published
.venv/bin/python -m tools.exness_tick_history --config <symbol-profile.toml> \
  prepare-mt5-file --inventory <inventory_id> --preparation-id <new_preparation_id> \
  --output-dir "$HOME/Documents/Exness_Tick_Data"
```

Use separate profiles/data roots for XAUUSD, EURUSD, GBPJPY and BTCUSD, setting
each profile's `profile_id`, `base_symbol` and `archive_symbol`. The first three
have published annual sources from 2015; BTCUSD starts in 2017. The manifest
records the actual first/last tick, rather than inventing earlier history.
`latest-published` excludes the current, incomplete UTC day. A 404 remains an
explicit unavailable interval; it is not filled with synthetic ticks.

This command requires a C++17 compiler (`g++` or `c++` with 128-bit integer
support). It builds and checksum-pins the small repository-owned streaming
helper in the data root. Quotes use exact integer/decimal validation without
floating-point conversion. Already ordered sources stream directly; sources
with regressions receive a stable external sort, preserving equal-time order
and duplicate multiplicity. GNU sort uses the profile's memory budget and a
conservative spill preflight; DuckDB supplies the portable bounded fallback.
No Parquet dataset or full-history in-memory table is required.

Each completed archive is appended to one accumulating file, flushed and
checkpointed. Resume verifies all committed byte ranges and removes only an
uncommitted tail. Final publication requires complete native-format/order/row
validation and SHA-256 readback. The same ID resumes or verifies the same
inputs; changed inputs, code or price policy require a new ID/output directory.
Existing unrelated output files are never overwritten.

Owned downloads, extracted CSVs and per-source parts are removed after their
bytes are committed. Existing shared archives from earlier `download` runs are
reused and retained. `--keep-work-files` explicitly retains the preparation's
temporary files. Small inventories, checkpoints, source hashes, helper build
receipts and `preparations/<id>/performance.json` remain in the data root.

The file contains source UTC, six tab-separated MT5 columns, one header, exact
millisecond timestamps and zero Last/Volume. Import with tabs, one header row
skipped, zero columns skipped and Shift=0 into a custom symbol whose properties
were configured first. This source-only preparation does not attest a broker
specification, clock/feed equivalence, native import or registered round trip.
The verified `export-mt5` acceptance workflow remains separate.

Strict price validation is the default. Some EURUSD sources contain decimal
representation artifacts such as `1.1847699999999999`. Only an explicit
`--normalize-eurusd-decimal-artifacts` selection permits values with more than
12 decimal places to become five-decimal quotes, and only within an exact
`0.0000000000000001` distance. Other symbols, larger differences, crossed source
quotes and invalid values still fail. Every tick is retained; the manifest
records the policy, affected row/quote counts, maximum change and bounded
before/after examples. Original archive bytes remain unchanged. This explicit
derived-file policy does not relax the strict Parquet builder or certify a
broker feed.

## Registered Dataset Workflow

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
Follow the guided native steps and evidence schema below.

## Guided Native Import And Round-Trip Evidence

For a newly requested registered package, discover terminal MCP schemas and call
`get_workspace_info` first. Verify Wine prefix, terminal/build, host/Windows path
mapping, account mode and exact broker symbol. Pin the archive-to-broker feed,
complete native specification and reversible historical UTC/broker clock.
A zero/unavailable trade tick or tick value cannot establish specification/P&L
parity; never infer the trade tick from Point. Keep the EA's export-only Exness
analysis adjustment separate from source UTC and imported broker timestamps.

In MT5, open Market Watch -> Symbols (Ctrl+U). Create a fresh, unused custom name
from the export manifest, copying the verified broker specification first. Names
must fit 31 characters; retain `XAU` for the existing gold calendar mapping.
Never import into the broker symbol. Freeze digits, point, chart mode and other
properties before import: changing some properties later erases history. A
corrected specification uses a fresh symbol/version rather than blind edits.

Import manifest chunks in order through the custom symbol's Ticks tab. Select
tabs, skip one header row, skip zero columns, preserve the six preview columns,
and use Shift=0. Record each file/hash/count privately. Import replaces its
covered interval, including holes; partial imports are not accepted history.
Recovery reuses exact owned chunks only after reconciling replaced intervals,
or uses a fresh custom symbol. The separate source-only preparation is not a
registered export and does not create an attested round trip automatically.

Re-export the entire interval with milliseconds, preserving equal-time groups.
Capture native M1/M3/M10/H1 bars over the same coverage. Expected native bar
columns are `<DATE> <TIME> <OPEN> <HIGH> <LOW> <CLOSE> <TICKVOL> <VOL> <SPREAD>`,
tab-separated, dotted dates and `HH:MM:SS`; tick times include milliseconds.
MT5 can derive bars from imported ticks. Verify availability/equality for each
new package; if bars are missing, the gate remains pending. Do not synthesize
bars or invent a separate bar-import convention.

Create private evidence beside the native files, only after the operations pass:

```json
{
  "schema_version": 1,
  "operator_verified": true,
  "complete": true,
  "export_manifest_sha256": "from-import-manifest",
  "native_specification_sha256": "hash-of-frozen-verified-specification",
  "custom_symbol": "name-from-import-manifest",
  "native_ticks_sha256": "sha256-of-complete-native-reexport",
  "native_bars": {
    "M1": {"path": "M1.tsv", "sha256": "file-sha256"},
    "M3": {"path": "M3.tsv", "sha256": "file-sha256"},
    "M10": {"path": "M10.tsv", "sha256": "file-sha256"},
    "H1": {"path": "H1.tsv", "sha256": "file-sha256"}
  }
}
```

Placeholder hashes are not evidence. The booleans attest completed operations,
never preparation alone. `compare-roundtrip` checks ordered time/Bid/Ask
multiplicity, specification/file hashes and exact native Bid OHLC. Missing
native evidence yields INCONCLUSIVE; demonstrated tick/spec/bar mismatch yields
FAIL. Full-range tick verification is distinct from H1 or sampled tick checks.

## Capture Once, Audit Offline

`freeze-capture` seals existing raw MCP JSON responses and their actual request
intervals, row counts and reader limits. It writes a separate immutable manifest
beside the request manifest, with a SHA-256 for every response. It does not call
MT5, download data, copy tick files, approve a feed or infer missing metadata.
Keep responses under the manifest directory; absolute paths, parent traversal,
symlinks and duplicate file ownership are refused.

The request manifest uses the following shape. Include one entry for every
disjoint tick request, in request order, and captured M1/M3/M10/H1 bar responses:

```json
{
  "schema_version": 1,
  "symbol": "XAUUSD_EXN_PRO_S1",
  "requested_from": "2026-07-13T00:00:00",
  "requested_to": "2026-07-16T00:00:00",
  "entries": [
    {
      "path": "ticks/first-response.json",
      "start": "2026-07-13T00:00:00",
      "end": "2026-07-16T00:00:00",
      "rows": 0,
      "limit": 10000
    }
  ],
  "bars": {
    "M1": {
      "path": "bars/M1.json",
      "start": "2026-07-13T00:00:00",
      "end": "2026-07-16T00:00:00",
      "rows": 0,
      "limit": 10000
    }
  }
}
```

The zero counts are placeholders, not evidence of a closure. Raw files contain
the MCP response object with `symbol`, `period` and `history`, preserving the
original JSON numeric text. Save those bytes directly; parsing prices into
JavaScript floats and serializing them again can destroy precision. Record the
actual limits, never inferred values. A legacy bar limit may be `null`; bar
completeness then rests on exact equality to every tick-derived candle. Tick
limits are mandatory. Include missing timeframes before claiming a full audit.
Bar requests cover the same interval as ticks, with boundaries aligned to each
supplied timeframe. A frozen manifest cannot be overwritten with changed input.

`audit-capture` rechecks checksums, exact symbol/period, exhaustive half-open
interval coverage, millisecond precision, monotonic order and row counts. It
compares the optional TSV once, row for row, including Bid/Ask and equal-time
multiplicity/order. Its expected checksum must come from the prepared import
manifest. It derives M1/M3/M10/H1 Bid OHLC and tick volumes in that same pass,
keeping one current candle per timeframe and one bounded tick response in
memory. Raw responses are capped at 16 MiB and 100,000 rows; split larger
requests. There is no full-history tick array or normalization copy on disk.

Reader-limit-sized tick responses yield `INCONCLUSIVE` and deterministic
bisected recapture requests. Never resume from the last returned tick. A
saturated single millisecond requires a complete native export. Empty intervals
need exact supplied TSV equality; that proves equality of the supplied data,
not market closure. Missing bars or fewer than 26 real preceding bars when
`--score-day` is used remain inconclusive. Zero support cannot pass.

Exit codes are 0 for `PASS`, 3 for `FAIL`, and 4 for `INCONCLUSIVE`. The report
contains bounded mismatch examples, counts, ordered quote hashes, input hashes
and the auditor implementation hash. Same inputs and implementation produce
byte-identical reports; replay needs neither a running terminal nor a private
profile. Reports are immutable, so changed evidence/code requires a new report
path. These diagnostics never set `mt5_round_trip=PASS` for an unregistered TSV
or replace the verified specification/clock/feed gates of broker acceptance.

## Seasonal References And Scoring

Copy `profiles/reference.example.json` into an ignored reference directory.
Its booleans/placeholders intentionally prevent acceptance. Supply verified clock
and specification objects, feed/profile hash, actual terminal build/capture time,
and a predeclared scored day/reason. Keep Pro demo/live references separate.
Map the entire broker day explicitly to UTC; include adjacent source partitions
when the mapping crosses a date boundary.

Pin limits using an independent pilot, not the already-inspected January 14 and
July 15, 2026 scored days. The private TOML comparison table needs every numeric
threshold plus these metadata fields:

```toml
status = "PINNED"
name = "xauusd-pro-modern-v1"
pinned_at_utc = "2026-09-05T00:00:00.000Z" # replace with the actual pin time
pilot_dates = ["2026-08-25"]               # replace with the reviewed pilot
rationale = "Evidence supporting each frozen limit"
# Include every numeric threshold from the profile contract as well.
```

Freeze references before scoring; do not raise thresholds after inspecting
failures or calibrate on acceptance days. `inspect-config` exposes the exact
feed/comparison hashes. The example reference's January 14 broker interval is
interpreted by its clock object, not assumed to be UTC.

Use native all-quote tick exports or raw MCP JSON with original numeric lexemes.
For MCP JSONL retain `time_ms`, `bid` and `ask` without float conversion. Despite
its name, `time_ms` is `YYYY.MM.DD HH:MM:SS.mmm`, interpreted under the verified
broker clock, not an integer epoch. Each tick entry declares a disjoint
`[start_broker_msc, end_broker_msc)` interval, SHA-256, row count, format and
completeness. MCP entries require a positive `limit` and
`millisecond_and_all_quotes_verified=true` only after checking those semantics.
Keep account/community fields out of captures.

For `rows >= limit`, bisect and recapture both halves; never advance from the
last returned tick. The existing `split_capture_interval` preserves tied ticks.
A saturated one-millisecond interval requires a complete native export. Empty
broker captures need `empty_interval_evidence`; they do not prove market closure.
Capture native M1/M3/M10/H1 and at least 26 real completed prior bars per period,
plus the scored day. Include real source warm-up; the comparator examines at
most seven prior UTC days. Never fill missing minutes. Warm-up diagnostics are
separate from scored errors; tick-derived diagnostics do not replace missing
native broker bars.

Use the exact dataset's successful round-trip report for `compare-broker`.
Diagnostic -1/0/+1-hour comparisons never adjust data. `seasonal-schedule` lists
winter/summer and Friday/Monday US/UK transition/mismatch-week captures. Future
transition dates remain untested. The aggregate uses that deterministic schedule;
a replacement day must be justified and frozen explicitly, not selected after a
failure. Seasonal sample acceptance does not certify all historical clock regimes.

### Retained Seasonal Diagnostic Evidence

The September 6, 2026 captures prove exact diagnostic import preservation with
Shift=0, not registered export or broker acceptance. Preserve these existing
symbols and raw reports; reacquire only changed, missing, corrupt or potentially
truncated evidence.

| Evidence | Winter | Summer |
| --- | --- | --- |
| Custom symbol | `XAUUSD_EXN_PRO_W1` | `XAUUSD_EXN_PRO_S1` |
| UTC start | 2026-01-12 20:00 | 2026-07-13 00:00 |
| Exclusive UTC end | 2026-01-15 00:00 | 2026-07-16 00:00 |
| Scored day / ticks | January 14 / 459,039 | July 15 / 272,226 |
| Full-range ticks | 922,664 | 947,513 |
| Adjacent equal-time rows | 6,254 | 4,473 |
| Native M1 / M3 / M10 / H1 bars | 2,929 / 979 / 294 / 49 | 4,134 / 1,380 / 414 / 69 |
| Preceding completed H1 bars | 26 | 46 |
| Tick and native-bar audit | PASS, zero mismatches | PASS, zero mismatches |

These native bars were generated from ticks. The verified ranges need no new
import, separate bar import or chart opening. Winter's final compact file starts
at 20:00. `.codex-artifacts/exness-seasonal-native-20260906/` retains request/frozen
capture manifests, `seasonal-native-imports-v1.json` and reports:

- `winter-audit-v1.json`: SHA-256 `40f03493e3e04b430e80f652524fba077e00745e0589e7192d96686c964e4975`.
- `summer-audit-v2.json`: SHA-256 `6f9f4ec7dc4918128773f3da553c3bae1aa6ee1a9acc7ea27f11c91112712df5`.

Original source/broker captures are in `.codex-artifacts/exness-seasonal-20260906/`;
datasets include `xauusd-winter-20260112-15-v1` and `xauusd-summer-20260713-16-v1`
under `artifacts/exness_tick_history/`. Earlier pilot evidence remains in
`.codex-artifacts/exness-sprint1/`, `.codex-artifacts/exness-native-probe-20260906/`
and `.codex-artifacts/exness-2015-parser-sample.json`. Archived task checkpoints
and the original seasonal preparation guide remain in
`.codex-artifacts/thread-closeout-exness-20260907/hook-state/`; preserve them.

Observed broker delays were 38 ms winter / 37 ms summer; maximum M1 OHLC
errors were 1.605 / 0.375 price units in tick-derived diagnostics. January native
broker M1 was unavailable with the 100,000-bar reader limit. The reader reported
zero broker tick size/value; custom tick values differed (0.1 winter, 1 summer).
These measurements do not establish specification/P&L parity or every year's
clock regime. Full original diagnostics and capture-auditor commit/rollback pins
are recoverable at baseline Git path
`bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93:docs/research/exness-tick-history-handoff-2026-09-07.md`.

## Operator Validation Queue

Use the [current index](../../docs/README.md) before a new task; reuse accepted
inputs and captures rather than repeating completed work. For remaining gates:

1. Pin actual profile/feed, terminal/build, nonzero trade tick, native sessions
   and complete specification. Verify historical UTC/broker clock separately
   from EA analysis time.
2. Complete the registered export and exhaustive round trip with verified native
   evidence. Diagnostic imports cannot supply invented export IDs/attestations.
3. Pin the independent pilot limits and frozen complete seasonal references;
   obtain missing native broker bars before formal scoring. Preserve failures.
4. For a registered full-history workflow, refresh `storage-plan` from a measured
   pilot and available disk, then download/build/audit/export/import. The historic
   146.4 GB estimate exceeded then-free 120.4 GB; neither is a current measurement
   or the requirement of the completed source-only preparation. HEAD availability
   is not source-body or full-coverage evidence. Use new IDs for extensions.
5. For newly requested tester acceptance, use the corrected source with real
   ticks, real warm-up, the verified session and periods, and an isolated run ID.
   Inspect reports/journals for modeled-tick substitution and history errors.
6. Apply [strict V14 validation/build/audit](../deterministic_signal_ml/README.md#acceptance-and-downstream-boundary),
   retaining the support floor of 30 and explicit insufficient support. Full
   recovered-run semantics cannot be inferred from a bounded chronology pass.
7. Write `research-provenance` outside V14 with the actual source/binary,
   dataset/export, specification/clock and tester evidence. Follow the
   [compile/tester runbook](../../docs/environment/mt5-agentic-workflows.md)
   only when source/toolchain or a new acceptance gate requires it.

No procedure authorizes live rollout. Human chart/rendering verification remains
a separate operational gate. Resume only task-owned partial downloads/builds;
do not delete another writer's lock, overwrite accepted bytes or edit checksums
to hide corruption. Restore matching immutable data or create an isolated version.

## Broker Comparison

Broker comparison accepts complete native TSV, MCP JSONL or raw MCP JSON
captures. For raw responses, set a tick/reference bar entry's `format` to
`mcp_json`, preserve its raw file checksum and record the actual positive reader
`limit`. Other completeness and reference requirements still apply. The exact
response symbol must match the reference's verified broker symbol. No JSONL or
bar TSV copy is needed. It uses
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

For a registered Parquet/export backfill, freeze an inventory from 2015 to `latest-published`,
then run `storage-plan` using a measured pilot dataset. Its explicit estimates
include retained archives, Parquet, native text/history, the largest source's
working storage, spill allowance and reserve. `--text-bytes-per-tick` and
`--mt5-bytes-per-tick` may be refined from native pilot measurements; defaults
are conservative estimates, not measured MT5 disk use. Unknown sizes or an
insufficient estimate exit 4. Provision a dedicated larger data root or measure
the native pilot before launching a full workflow that exceeds available space.

Extending history uses another inventory/dataset/export ID on the same data
root. Verified unchanged archives are reused from the ledger; the new dataset
does not append into a prior accepted version. A changed URL validator creates
a new source request identity. If immutable bytes are corrupted or missing,
restore the matching checksum from a retained backup or use a new data root
and source version; do not edit the ledger to claim repaired evidence.

After an operator-owned tester run, `research-provenance` records dataset,
export, custom-symbol, clock/spec and EA source/binary hashes outside V14:

```bash
.venv/bin/python -m tools.exness_tick_history research-provenance \
  --dataset-id <dataset_id> --export-id <export_id> \
  --research-id <new_research_id> --v14-run-id <run_id> \
  --ea-source HFT_Grid_AI.mq5 --ea-binary HFT_Grid_AI.ex5 \
  --tester-evidence <private_tester_evidence.json>
```

The optional tester evidence contains `tester_build`, `operator_validation`
and `settings`. Allowed settings are `model`, `start`, `end`, `warmup_start`,
`Broker_Session`, `Macro_Timeframe`, `Deep_Timeframe`, `Micro_Timeframe`,
`Enable_Signal_Feature_Export`, `Signal_Feature_Run_Id`, `execution_delay_ms`.
This sidecar records provenance only; it never certifies a tester run, writes
inside the V14 folder, trains a model or activates broker execution.
Its own schema is version 2, with `v14_run_id` and `v14_run_files_written`;
the producer dataset schema remains 14. The old CLI option is removed. Retained
historical sidecars remain immutable and are not converted or loaded as V14.

See the [current project index](../../docs/README.md) for accepted source,
custom-symbol, tester and recovery evidence and remaining operational gates.

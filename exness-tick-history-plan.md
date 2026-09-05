# Plan: Exness Tick History Service And MT5 Research Validation

**Generated**: 2026-09-05
**Status**: Authorized implementation in progress; manual MT5 acceptance deferred until the six-sprint code batch is complete
**Complexity**: High data-integrity requirements; isolated offline Python tooling
**Discovery baseline**: `bot/pivot_points_fractal`, `5cb7b24`

The user confirmed Ubuntu 22.04/24.04 with Wine, Pro demo/live symbols without
suffixes today and configurable suffixes for future accounts, a Python CLI with
MT5 MCP assistance where supported, and exact clock alignment with measured
broker quote similarity plus an exact custom-symbol import round trip. The
user also accepted guided MT5 custom-symbol creation and import for the initial
release, with MCP-assisted reads and comparison after import. These design
choices are settled; execution is authorized under the steering recorded here.

## Execution Steering: Deferred Operator Acceptance

The user authorized execution of Sprints 1 through 6 with validation and commits,
then explicitly requested completing the implementation batch before the guided
MT5 steps and final validation. This instruction supersedes the original order
of operator-dependent gates throughout this plan.

For each sprint, complete its implementation, available automated tests, source/
include and safety review, and one sprint-specific commit before advancing.
Record native import/specification checks, full custom-symbol round trip,
seasonal broker acceptance, and operator/tester evidence as `PENDING_OPERATOR`
where they depend on the deferred steps. Do not treat these deferred checks as
passed or describe the data as broker-equivalent. Automated failures still block
advancement. At the end of the code batch, provide a concrete operator checklist
and preserve the remaining validation state for continuation. Full-history
operations remain bounded by actual available storage and source integrity; do
not hide a resource/access failure or claim an unperformed backfill succeeded.

## Overview

Build a local Python service that discovers and downloads the available Exness
tick history for an explicitly selected instrument/feed, preserves the source
archives, produces a deterministic sanitized dataset, and exports files for an
MT5 custom symbol. Validate the imported data against the export exactly, then
compare it with the selected Exness broker symbol on a complete winter day and
a complete summer day before using the full history for V13 signal statistics.

The default request is XAUUSD, intended for the Pro feed, from 2015 through the
latest published complete day. Requested dates and actual available coverage
are separate facts. The current EA, its broker safety kernel, its analysis-time
policy, and the twelve-file V13 schema remain authoritative and unchanged.

```text
explicit instrument/feed + date range
  -> archive inventory and coverage ledger
  -> immutable verified ZIPs
  -> exact UTC quotes with source-row provenance
  -> bounded, deterministic merge and quality report
  -> versioned MT5 import package
  -> native custom-symbol import and exact round-trip comparison
  -> winter/summer broker comparison and DST boundary diagnostics
  -> full-history coverage audit and isolated V13 research run
```

## Scope And Decisions

- **In scope**: configurable instruments, account/feed profiles, dates, annual/
  monthly/daily archive selection, resumable downloads, integrity checking,
  sanitization, deterministic merging, MT5 text export, MCP-assisted broker/
  custom tick and bar comparison, reproducible reports, and full-history
  operational acceptance. The operator creates custom symbols and imports the
  generated files through guided MT5 steps; the installed MCP supports the
  subsequent specification, tick and bar checks.
- **Confirmed operating model**: an on-demand, resumable Python CLI with reusable
  Python functions on Ubuntu 22.04 or 24.04; the existing MT5 terminal runs under
  Wine. Use the installed MT5 MCP for supported terminal reads and comparison
  orchestration. Native Windows remains a compatible import/export path, not
  the primary acceptance platform. Do not require a native Linux installation
  of the Windows `MetaTrader5` Python package.
- **Non-goals**: a web application, Django, a daemon, cloud deployment, automated
  VPN control, a new production MT5 importer, new MQL5 test infrastructure,
  automated trading, EA changes,
  broker-history replacement, strategy changes, V12 conversion, schema V14,
  model training changes, or live rollout.
- **Execution shape**: the Python CLI prepares versioned import files and
  reports, the operator performs guided native creation/import, and Codex uses
  the existing MCP readers to assist validation. The Python comparison commands
  also accept captured files independently of a running Codex session.
- **Fixed decisions**: raw archives are immutable; timestamps and prices are not
  adjusted to manufacture similarity; legitimate repeated ticks are preserved;
  missing periods are reported rather than synthesized; source and comparison
  evidence remain outside the strict V13 run directory.
- **Implementation discipline**: one writing session and one agent, the existing
  `unittest` style, existing dependency conventions, and one gated commit per
  sprint. Parallel HTTP requests and independent read-only checks are not agent
  delegation.

### User Decisions And Operational Prerequisites

The user answered the original three questions and accepted guided native
creation/import on 2026-09-05. Preserve these answers; do not reopen them as
missing requirements. No material workflow choice remains unanswered. Pin
operational profile values and verify native behavior within the named sprints.

| Item | Accepted requirement / remaining evidence | Affected work |
| --- | --- | --- |
| Target account/feed | Exness Pro demo and live profiles, kept separate. Current examples are bare `XAUUSD`, `EURUSD`, and `US30`; XAUUSD remains the initial history target. Explicitly configure future suffixes and exact broker symbols. Pin live/demo and private server/profile identity for each comparison. | Sprints 1, 4, 5 |
| Terminal environment | Ubuntu 22.04/24.04 with Wine is the primary target. Pin the actual Wine prefix, terminal/build, MCP roots and host/Windows path mapping before the pilot. | Sprints 1, 4 |
| Automation extent | Accepted: Python CLI, guided MT5 custom-symbol creation/import by the operator, and existing MCP-assisted specification/tick/bar reads and comparisons. No new importer or script-launch integration is included. | Sprints 1, 4, 5 |
| Similarity requirement | Accepted: exact clock/session mapping and measured quote/tick similarity against the broker; exact dataset-to-custom-symbol round trip. Every archive tick matching the account feed exactly is not required. | Sprint 5 |
| Numeric tolerances | Configure and freeze a named comparison profile using separate pilot data before scoring the winter/summer acceptance days. An unset profile produces `INCONCLUSIVE`, never an automatic pass. | Sprints 1, 5 |
| Storage and limits | Configurable local data root, initially `artifacts/exness_tick_history/`; measure disk expansion and throughput before scheduling the full backfill. | Sprints 2, 6 |

These values must be concrete before their dependent acceptance checks. Missing
broker access does not prevent the independent source/configuration tasks in
Sprint 1, but it prevents completing that sprint's native capability gate or
declaring broker equivalence. Preserve the user's answers across interruptions.

## Discovery Evidence And Official Resources

### Repository Facts

- The worktree was clean at discovery. The current Python interpreter and local
  virtual environment use Python 3.12.11.
- `tools/deterministic_signal_ml/` uses scripts, pinned requirements, DuckDB,
  Parquet, and standard-library `unittest`; its DuckDB pin is `1.5.4`.
- `services/utils/market_data_time.mqh` preserves broker timestamps and shifts
  only analysis timestamps. Its metals classification depends on an `XAU`,
  `XAG`, `XPT`, or `XPD` symbol prefix. A custom XAUUSD name must retain that
  prefix to exercise the existing classification correctly.
- `services/trading_signals/pivot_fractal_engine_state.mqh` consumes native
  previous completed bars through `CopyRates`. Valid tick files alone do not
  establish that the terminal has the required M1/M3/M10/H1 history.
- The existing accepted EA compile remains reusable while MQL5 source,
  includes, compiler, and acceptance requirements remain unchanged. The
  separate human chart-object/rendering deployment gate is still outstanding.

### Current MT5 MCP Capability Evidence

Read-only discovery on 2026-09-05 called the terminal MCP's
`get_workspace_info` before other terminal operations. The server responded
successfully; its available catalog contains 42 tools. Compiler metadata reports
build 6182 and no configured Python helper runtime. This is capability discovery,
not a new compile or verification of the selected trading account's identity.

| Operation | Current exposed capability | Plan consequence |
| --- | --- | --- |
| Workspace/preflight | `get_workspace_info` succeeds | Discover runtime schema/roots before reads; do not hardcode private paths |
| Existing symbol metadata | `get_marketwatch_symbols` succeeds for bare `XAUUSD` | Capture a reviewed specification and profile; suffix configuration remains explicit |
| Broker/custom ticks | `get_chart_ticks_history` exposes exact symbol/range/limit arguments | Use bounded reads with exhaustive interval ownership after precision/completeness checks |
| Broker/custom bars | `get_chart_history` supports M1/M3/M10/H1 and other named periods | Use for bar/input comparison after symbol creation/import |
| Clock context | `get_time_information` succeeds | Record context; workstation clock is not a historical broker-clock proof |
| Show an existing symbol | `add_marketwatch_symbol` | Visibility only; it does not create a custom symbol |
| Create custom symbol or import/replace ticks/bars | No exposed operation | The accepted workflow uses guided native MT5 creation/import by the operator |
| Launch an MQL5 script/program | No exposed operation | Creating a file or compiling it cannot substitute for launching an importer |

A bounded XAUUSD read for `2026-09-01T00:00:00Z` through the next second returned
10 records with `time_ms`, `bid`, and `ask`. `time_ms` is a string in
`YYYY.MM.DD HH:MM:SS.mmm` format, including nonzero milliseconds; it is not an
integer epoch and has no timezone marker. Parse it under the pinned broker
clock contract. The reader reported tick availability from `2026.01.01
00:00:00`; the M1 reader reported bar availability from `2021.10.27 00:00:00`.
These are server-reported availability bounds, not complete coverage audits.

The symbol reader reported `digits=3`, `point=0.001`, and `tick_size=0` for
XAUUSD. The zero tick size is unresolved metadata, not a usable price-grid
contract. Cross-check a native specification snapshot before export or
trade-tick-normalized comparison; do not silently substitute point size or
change the EA's strict specification checks. Keep the account/profile private.

No current tool accepts a Python expression or arbitrary MQL5 function call.
Do not invent custom-symbol methods, modify plugin caches, misuse outbound HTTP
or file-writing tools as a terminal mutation API, or automate a trading action
to work around missing import support. The accepted first release uses guided
native creation/import and adds no production MQL5 utility.

For the accepted workflow, Codex orchestrates the installed MCP readers and
passes validated, bounded captures to the local Python comparison commands.
The service's reusable comparison logic accepts those capture artifacts and
native exports; it does not implicitly depend on Codex running or embed global
MCP credentials/configuration. The actual capture transport and large-output
file handoff must be verified in Sprint 1, with raw data kept out of chat.

### Exness Evidence Observed During Planning

The user supplied screenshots of the official selection page and its download
links. Direct requests to `www.exness.com/tick-history/` returned HTTP 403 in
this environment; the archive host below was accessible without changing VPN
configuration. The user reports needing a USA VPN for downloads in their
browser. Reachability is an environment prerequisite, not a permanent promise.

| Official-page download target | Observed response | Size evidence |
| --- | --- | --- |
| `https://ticks.ex2archive.com/ticks/XAUUSD/2015/Exness_XAUUSD_2015.zip` | HEAD 200; bounded range GET 206 | 59,714,818 ZIP bytes; central directory reports 552,973,048 CSV bytes |
| `https://ticks.ex2archive.com/ticks/XAUUSD/2026/08/Exness_XAUUSD_2026_08.zip` | HEAD 200 | 61,502,938 ZIP bytes |
| `https://ticks.ex2archive.com/ticks/XAUUSD/2026/09/01/Exness_XAUUSD_2026_09_01.zip` | HEAD 200; bounded range GET 206 | 3,266,299 ZIP bytes; central directory reports 21,604,394 CSV bytes |

The annual and daily ZIP directory samples each contained one corresponding
CSV member. Their sampled header was:

```csv
"Exness","Symbol","Timestamp","Bid","Ask"
```

Sampled timestamps include `2015-08-10 00:00:00.000Z` and
`2026-09-01 00:00:00.064Z`. The sampled 2015 file begins on August 10 and
contains distinct quotes with equal timestamps. This is bounded source
inspection, not a complete earliest-date/coverage audit or a pipeline test.
The sampled modern quotes have three decimal places. The CSV does not contain
an account-type field, so the intended Pro mapping still requires explicit
page/broker evidence; the filename alone cannot establish it.

The discovered URL templates are concrete initial adapter inputs, not a
documented public API or a guarantee that every period/instrument exists:

```text
annual:  https://ticks.ex2archive.com/ticks/{symbol}/{YYYY}/Exness_{symbol}_{YYYY}.zip
monthly: https://ticks.ex2archive.com/ticks/{symbol}/{YYYY}/{MM}/Exness_{symbol}_{YYYY}_{MM}.zip
daily:   https://ticks.ex2archive.com/ticks/{symbol}/{YYYY}/{MM}/{DD}/Exness_{symbol}_{YYYY}_{MM}_{DD}.zip
```

### Official Documentation

Retrieved during planning unless explicitly qualified:

- Exness selection page, visible in user-provided screenshots; direct page
  request was blocked: <https://www.exness.com/tick-history/>.
- MT5 custom instruments and native import/export:
  <https://www.metatrader5.com/en/terminal/help/trading_advanced/custom_instruments>.
  This documents six tick-import fields, millisecond text timestamps, terminal-
  calculated tick flags, valid identical ticks, replacement of an imported time
  interval, and settings changes that erase custom history.
- MQL5 `CustomTicksReplace`, reference for platform ordering and replacement
  semantics, not an instruction to introduce an MQL5 importer:
  <https://www.mql5.com/en/docs/customsymbols/customticksreplace>.
- MQL5 custom-symbol naming and creation contract, including the 31-character
  limit: <https://www.mql5.com/en/docs/customsymbols/customsymbolcreate>.
- Official Python integration function inventory:
  <https://www.mql5.com/en/docs/python_metatrader5>.
  The published API inventory has history readers but no custom-symbol creation
  or custom-tick writer. Do not design around nonexistent Python methods.
- Official Python tick-range retrieval, relevant if an existing verified reader
  is used during validation:
  <https://www.mql5.com/en/docs/python_metatrader5/mt5copyticksrange_py>.
  It documents explicit UTC datetime construction; never use host-local naive
  datetime conversion for tick epochs.
- DuckDB official source documentation retrieved through Context7:
  <https://github.com/duckdb/duckdb-web/blob/main/docs/current/guides/performance/how_to_tune_workloads.md>
  and
  <https://github.com/duckdb/duckdb-web/blob/main/docs/current/configuration/pragmas.md>.
  Disk spilling supports larger-than-memory workloads, but `memory_limit`
  governs the buffer manager rather than total process RSS. Use explicit sort
  keys and measured resource limits. Do not adopt newer DuckDB syntax without
  checking the repository's pinned `1.5.4` version.

Recheck relevant documentation when implementing a changed external contract.
No full archive, broker export, or terminal mutation was performed for planning.

## Named Implementation Resources

### Existing Project Contracts

- `AGENTS.md`: source ownership, research/broker separation, validation,
  immutable history and sprint commit rules.
- `docs/architecture/market-data-broker-executor.md`: broker-native bars,
  pivot identity, include pipeline and execution boundary.
- `docs/environment/mt5-agentic-workflows.md`: Windows/Wine paths, existing
  Python runner, compile policy, documentation gate and private artifact rules.
- `docs/workflows/pivot-fractal-statistics-flow.md` and
  `docs/workflows/pivot-fractal-offline-research-boundaries.md`: strict V13
  intake, evidence grains, causal time, and offline research ownership.
- `docs/research/pivot-fractal-v13-producer-handoff.md` and
  `docs/research/pivot-fractal-v13-producer-acceptance-2026-08-31.md`: retained
  accepted baseline; link to these without rewriting their historical evidence.

### New Python Package

Use `python -m tools.exness_tick_history`; no new packaging framework or web
service is required. The paths below are proposed files to create.

| File | Responsibility |
| --- | --- |
| `tools/exness_tick_history/__init__.py` | Package boundary |
| `tools/exness_tick_history/__main__.py` | Thin module entrypoint |
| `tools/exness_tick_history/cli.py` | Commands, exit statuses, bounded summaries |
| `tools/exness_tick_history/config.py` | Strict TOML configuration and feed/date/limit validation |
| `tools/exness_tick_history/archive.py` | Verified URL templates, archive inventory, interval ownership |
| `tools/exness_tick_history/download.py` | Streaming HTTP, retries, resume, integrity and atomic publication |
| `tools/exness_tick_history/storage.py` | Local manifest/ledger, locks, immutable artifact identities |
| `tools/exness_tick_history/sanitize.py` | ZIP/CSV validation, exact quote parsing, ordered Parquet partitions |
| `tools/exness_tick_history/mt5_export.py` | Six-field tick files, import manifest, conditional native M1 support |
| `tools/exness_tick_history/compare.py` | Native export intake, exact round trip, broker comparison metrics |
| `tools/exness_tick_history/report.py` | Coverage, quality, comparison, and research provenance reports |
| `tools/exness_tick_history/requirements.txt` | Only the required DuckDB dependency, aligned with the existing pin |
| `tools/exness_tick_history/profiles/xauusd_pro.example.toml` | Public example; no account identifiers, credentials, or private paths |
| `tools/exness_tick_history/README.md` | CLI contract, setup, examples, failure recovery |

Reuse Python's `argparse`, `tomllib`, `csv`, `decimal`, `datetime`, `zoneinfo`
where appropriate, `hashlib`, `zipfile`, `sqlite3`, `urllib`, and bounded worker
threads. Prefer these and DuckDB over adding pandas, an HTTP framework, a task
queue, or separate database services. Do not import the research trainer just
to reuse its dependency environment.

### Tests And Documentation

- Add focused tests under `tools/exness_tick_history/tests/`:
  `test_config.py`, `test_archive.py`, `test_download.py`, `test_sanitize.py`,
  `test_mt5_export.py`, `test_compare.py`, and `test_pipeline.py`.
- Cover bare and explicitly suffixed broker-symbol resolution, profile isolation
  across Pro demo/live servers, MCP `time_ms` string parsing, and rejection of
  incomplete/zero-valued symbol metadata in the relevant existing test files.
- Use tiny synthetic or manually authored CSV/ZIP examples through the existing
  `unittest` pattern and temporary directories. Do not commit downloaded market
  data, private terminal exports, new MQL5 tests, or new CI infrastructure.
- Create `docs/workflows/exness-tick-history.md` for the operator sequence and
  `docs/research/exness-tick-history-acceptance.md` for concise acceptance facts.
- Update `README.md`, `docs/environment/mt5-agentic-workflows.md`, and the active
  statistics workflow only to link and describe this input-preparation boundary.
  Preserve archived plans and accepted V13 evidence.
- Add only `/artifacts/exness_tick_history/` to `.gitignore` if this default root
  is used. Keep its private contents and all `.ex5` files untracked.

### Local Artifact Layout

The data root is configurable and may be outside the repository. Within it:

```text
ledger.sqlite
locks/
archives/<archive_sha256>/<original_filename>.zip
runs/<download_run_id>/inventory.json
runs/<download_run_id>/events.jsonl
datasets/<dataset_id>/manifest.json
datasets/<dataset_id>/quality.json
datasets/<dataset_id>/date=YYYY-MM-DD/ticks.parquet
quarantine/<dataset_id>/rejected_rows.jsonl
exports/<export_id>/import-manifest.json
exports/<export_id>/ticks-<part>.tsv
references/<profile_id>/<capture_id>/
comparisons/<comparison_id>/report.json
comparisons/<comparison_id>/report.md
research/<research_id>/input-provenance.json
```

Dataset/export IDs identify immutable inputs and transform versions. Runtime
timestamps and machine paths live in separate run evidence so that logical
data hashes remain deterministic. One process owns a data-root ledger; bounded
download threads report results to that owner. Never break another process's
lock automatically or share a writing worktree with a second session.

## Data And Processing Contract

### Selection, Availability, And Downloading

1. Config separates `archive_symbol`, intended `account_type`, exact
   `broker_symbol`, and `custom_symbol`. The accepted default broker suffix is
   empty. Allow an explicit future `broker_suffix` with a base symbol, or an
   exact broker-symbol override; reject conflicting combinations. Keep archive
   identity independent of the broker suffix and verify its feed mapping.
   Never strip suffixes heuristically, silently replace Pro with Standard/Raw/
   Zero, or concatenate different instruments, accounts, demo/live feeds, or
   servers. The displayed symbol list does not establish archive availability.
2. Default `start` is `2015-01-01`; default end resolves once per run to the end
   of the latest verified published complete day. Store the resolved exclusive
   UTC cutoff. Explicit start/end dates use documented half-open intervals.
   A day/month/year selection expands into the same interval representation.
3. Discover the page/catalog when accessible, otherwise use the verified URL
   adapter and bounded candidate probes. Retain the source of availability
   evidence. Do not invent a catalog API or treat dropdown years as data proof.
4. Prefer completed annual archives, then completed monthly archives, then
   daily archives for remaining/current periods. Annual, monthly, and daily
   modes are explicit overrides. Download larger containers only when necessary
   for a selected subrange and report the extra bytes before fetching them.
5. Assign one authoritative source interval to every retained tick. Resolve
   annual/monthly/day overlap through this ownership map before merging;
   fallback files fill explicit intervals, not a blanket concatenation. Detect
   conflicting overlapping source revisions and require a new version rather
   than hiding discrepancies through de-duplication.
6. Record expected/requested coverage, observed first/last timestamps, missing
   intervals, and publication cutoff separately. Distinguish access denial,
   transient failure, confirmed unavailable history, not-yet-published data,
   valid no-tick intervals, and unknown coverage. HTTP 403/404 or an empty
   response alone cannot establish a market closure or complete history.
7. Start with two download workers and configurable bounded retries/timeouts.
   Honor `Retry-After`; classify 429/5xx/timeouts separately from 403/404. A
   network check tests page and archive hosts independently and reports whether
   the operator's existing network/VPN can reach the archive. Never install,
   switch, or control a VPN automatically.
8. Stream to an owned `.part` file. Resume only when the object validator,
   returned byte range, and total size agree; restart the owned partial file
   safely when the server ignores Range or the source has changed. Finish with
   length, ZIP structure/CRC, and locally computed SHA-256 verification, then
   publish atomically on the same filesystem. ETag is not a content checksum.
9. Keep completed bytes immutable even if Exness later republishes a URL. A
   changed checksum creates a new source version and invalidates dependent
   derived acceptance; it does not overwrite accepted evidence.

### Sanitization And Merge

1. Version the observed five-column source contract. Check vendor, exact
   symbol, header, encoding, timestamp grammar, timezone marker, field count,
   and numeric grammar. Any newly encountered format requires an explicit
   adapter revision; no loose automatic column guessing.
2. Parse `Z` timestamps as UTC using integer millisecond arithmetic. Keep
   original archive/member/row provenance and report timestamp precision and
   its observed distribution by period. If a later source has finer-than-ms
   precision, retain that evidence and fail MT5 export until its lossy mapping
   is explicitly resolved; do not silently truncate timestamps.
3. Use exact decimal quote values and an explicit supported scale, such as
   `DECIMAL(38,12)` after range/precision checks. Record observed source digits
   separately from target symbol digits/tick size. Do not round old prices to
   today's broker specification to conceal an incompatibility.
4. Reject/quarantine malformed timestamps, non-finite or non-positive quotes,
   wrong symbols, and crossed markets (`Ask < Bid`). Equal Bid/Ask is allowed
   and counted. Detect large jumps/spreads as quality flags without clipping,
   smoothing, shifting, reflecting, or deleting valid market observations.
5. Preserve repeated quote values and every legitimate repeated timestamp,
   including byte-identical rows within a selected source stream. Remove only
   a proven repeated ingestion of the same source row or an archive overlap
   excluded by interval ownership; each exclusion has an auditable reason.
6. Record timestamp regressions. Sort by UTC time and explicit source sequence
   within a unique authoritative stream; preserve input order for ties.
   Different source streams with unresolved same-time ordering are ambiguous
   evidence, not permission to invent exchange order. Never rely on SQL/file
   scan order or an unstable timestamp-only sort.
7. Stream ZIP members, enforce file-count/uncompressed-size/expansion limits,
   reject encrypted or unsafe members, and do not use unchecked `extractall`.
   Keep archive paths and user-controlled identifiers confined to the selected
   data root; refuse traversal and unsafe symlink destinations.
8. Materialize bounded UTC-date partitions and use DuckDB disk spilling only
   for the necessary sorting/merging. Configure memory, thread, temporary-disk,
   and batch limits. Do not load a year or the full history into a DataFrame.
   Final CSV output uses explicit ordering, regardless of Parquet scan order.
9. Report a row conservation equation: selected source rows equal retained
   rows plus individually classified exclusions/quarantine. Quarantine or
   ambiguous coverage prevents a clean accepted dataset by default; a later
   reviewed subset must have a different ID and explicit exclusions.
10. Never synthesize ticks, interpolate prices, forward-fill missing periods,
    resample to one tick per second, or generate bars for minutes with no ticks.

The canonical tick registry is independent of V13: `time_utc_msc BIGINT`,
`bid/ask DECIMAL(38,12)` after explicit precision checks, `source_id VARCHAR`,
`source_member VARCHAR`, `source_row_number BIGINT`, and
`sequence_in_partition BIGINT`. Symbol/feed identity, schema/transform version,
source hashes and time/precision policies live in the dataset manifest. Values
are parsed exactly before reaching DuckDB; excess precision or decimal range
cannot be silently rounded by a database cast. The raw archive remains the
authoritative record of original lexical formatting.

### Time, Custom Symbols, And MT5 Export

- UTC source time, broker chart/epoch convention, and EA analysis time are
  separate contracts. Verify the selected terminal's actual mapping from
  timestamped broker ticks and bars. The likely zero-offset case is a hypothesis
  until measured; do not apply a generic UTC+2/+3 or the EA's winter -60 minute
  analysis adjustment to imports.
- A broker-clock mapping must be explicit, reversible for the accepted data,
  versioned, and valid over the requested dates. Unknown historical clock
  regimes or ambiguous/non-monotonic DST mappings block the affected export.
  Store original UTC values alongside mapping metadata; never overwrite them.
- Parse the currently observed MCP `time_ms` string with its exact documented-
  in-this-plan grammar and separately pinned clock convention. Do not treat
  the field name as evidence that it is an epoch, infer a timezone from Wine or
  Ubuntu, or silently reduce precision when normalizing captured responses.
- Clone the selected broker symbol's relevant specification before importing:
  digits, point, tick size/value, chart mode, contract size, currencies,
  calculation mode, lot constraints, margin settings, sessions, and relevant
  tester properties. Capture the current snapshot's effective date and hash;
  it is not evidence of unchanged broker conditions since 2015.
- Use a fresh name such as `XAUUSD_EXN_PRO_<short_id>` within MT5's 31-character
  name limit, retaining `XAU` at the start. Verify no broker or custom name
  collision. Never mutate the live broker symbol or reuse another run's custom
  symbol without its explicit ownership and history manifest.
- Freeze all specification fields that can erase history before import.
  Changed specifications or transforms produce a new custom symbol/version.
- Emit the officially documented tab-separated six-field format:

  ```text
  <DATE> <TIME> <BID> <ASK> <LAST> <VOLUME>
  2026.09.01 00:00:00.064 4452.259 4452.441 0 0
  ```

  The actual delimiter is a tab. Use decimal dots and exact millisecond text;
  zero Last/Volume means these quote-only facts were not supplied. Do not
  fabricate trade volume or write tick flags; the terminal calculates flags.
- The import manifest specifies encoding, separator, header row skip, `Shift=0`
  after the explicit export mapping, expected row count, ordered quote hash,
  timestamp bounds, symbol/specification hash, and non-overlapping chunk spans.
  Configurable chunk limits never split a group of equal timestamps.
- A single merged file is optional and streamed. Default manageable chunks
  still represent one ordered logical dataset. Importing an interval replaces
  existing custom history in that interval, including holes; create/version
  the destination and verify every chunk instead of treating import as append.
- Verify M1 and derived M3/M10/H1 history on the target terminal. If native tick
  import does not build the needed M1 history, provide a companion M1 export
  derived solely from the same quotes and the verified chart/volume convention.
  Validate it against native bars; do not assume bars exist or invent empty
  minutes. This is a required Sprint 1 capability finding and Sprint 4 gate.

### Validation And Similarity Meaning

Keep three results distinct:

| Result | Required meaning |
| --- | --- |
| `DATA_INTEGRITY` | All requested source intervals accounted for, archives and row conservation verified, transform deterministic, unresolved defects disclosed |
| `MT5_ROUND_TRIP` | Exported and native re-exported custom ticks match exactly in ordered time/Bid/Ask multiplicity and precision; required bars/specification verified |
| `BROKER_COMPARISON` | Correct reference feed, verified clock/session alignment, and every configured similarity threshold passes independently for winter and summer |

Use `PASS`, `FAIL`, and `INCONCLUSIVE` per result. Missing data, an incomplete
native export, an unconfigured tolerance, or an ambiguous feed/clock produces
`INCONCLUSIVE`; a demonstrated mismatch produces `FAIL`. No aggregate score
may hide a failed gate. Exact archive-to-broker equality may be reported if
observed, but it is a separate, stronger claim than research suitability.

Default seasonal candidates are 2026-01-14 and 2026-07-15, subject to verified
complete availability on both feeds and normal trading sessions. Select and
freeze replacements by a documented deterministic rule if necessary. Use whole
broker days `[00:00, next 00:00)`, convert them explicitly to UTC, and fetch the
adjacent source dates when a day crosses a UTC partition. Include enough real
prior history for complete H1/M10/Micro indicator warm-up; score only the
selected day. Record why each day was selected rather than choosing the day
with the best match.

Measure at least:

- Exact timestamp/quote sequence match rate and duplicate multiplicities.
- Bidirectional, one-to-one, order-preserving quote matches within a configured
  maximum time delta, with unmatched ticks reported on both sides. Nearest
  matching cannot reuse one broker tick for many archive ticks.
- Signed time deltas and diagnostic clock offsets, including +/-1 hour; an
  alternative shift is a diagnostic, never an automatic data correction.
- Bid/Ask/spread errors in price units and the captured trade-tick unit;
  medians, p95/p99, maxima, and support counts, including unmatched observations.
- Tick counts by minute/hour, active-minute coverage, first/last ticks,
  session/maintenance gaps, and UTC versus broker-day boundaries.
- M1 and native M3/M10/H1 Bid OHLC/bar-open comparisons, with missing bars
  explicit. Compare pivot inputs derived from completed bars, since those
  prices and boundaries directly affect this EA's signal statistics.

Recommended policy: require zero unexplained clock offset, no unexplained
session-boundary displacement, and 100% exact import round trip. For broker
price/tick similarity, use the following proposed starting profile for the
separate modern-data pilot. These are conservative engineering targets, not
verified Exness guarantees or accepted performance measurements:

| Profile field | Proposed pilot target |
| --- | --- |
| `max_match_delta_ms` | 500 |
| `min_matched_fraction_each_feed` | 0.95, measured independently on each feed |
| `min_active_minute_jaccard` | 0.999, intersection/union of minutes with quotes |
| `max_p99_bid_error_ticks` / `max_p99_ask_error_ticks` | 5 / 5 |
| `max_p99_spread_error_ticks` | 5 |
| `max_p99_m1_ohlc_error_ticks` | 5 for each Bid OHLC field on matched bars |
| `max_unexplained_clock_offset_seconds` | 0 |

Absolute maxima, quantiles by hour, first/last/session boundary differences,
and missing-bar counts remain visible even when a percentile target passes.
Sparse or coarse historical data needs its own documented profile; it cannot
inherit a modern 500 ms assumption without evidence. Pilot outcomes may support
a justified profile revision before acceptance dates are scored. Record the
final numeric profile, rationale and hash before held-out seasonal acceptance;
never increase its limits after an acceptance failure merely to produce a pass.
The example profile labels these targets `PROPOSED`; broker `PASS` requires
the pinned operational profile, not an implicit use of unspecified tolerances.

Add first/last trading-day diagnostics around relevant spring/autumn DST
changes and the US/UK transition mismatch weeks. Exness server-clock changes,
instrument session changes, and the EA's export-only analysis calendar are
different hypotheses. Do not infer any of them from the workstation timezone.
Two accepted days establish sample-level evidence for this feed and period;
they cannot certify every year, historical contract specification, slippage,
commission, fill, or real trading result.

## Proposed CLI And Validation Commands

All commands in this plan are implementation targets, not commands already
implemented or tests claimed to have passed. Commands run from the repository
root with the existing `.venv` and a configured, ignored data root.

```bash
.venv/bin/python -m tools.exness_tick_history --help
.venv/bin/python -m tools.exness_tick_history --config tools/exness_tick_history/profiles/xauusd_pro.example.toml inspect-config
.venv/bin/python -m tools.exness_tick_history --config tools/exness_tick_history/profiles/xauusd_pro.example.toml inventory --start 2015-01-01 --end latest-published --granularity auto
.venv/bin/python -m tools.exness_tick_history --config tools/exness_tick_history/profiles/xauusd_pro.example.toml download --inventory <inventory_id> --resume
.venv/bin/python -m tools.exness_tick_history --config tools/exness_tick_history/profiles/xauusd_pro.example.toml build --inventory <inventory_id> --dataset-id <dataset_id>
.venv/bin/python -m tools.exness_tick_history --config <local_profile.toml> export-mt5 --dataset-id <dataset_id> --export-id <export_id>
.venv/bin/python -m tools.exness_tick_history --config <local_profile.toml> compare-roundtrip --export-id <export_id> --native-export <custom_ticks.tsv>
.venv/bin/python -m tools.exness_tick_history --config <local_profile.toml> compare-broker --dataset-id <dataset_id> --reference <reference_manifest.json> --comparison-id <comparison_id>
.venv/bin/python -m tools.exness_tick_history --config <local_profile.toml> audit --dataset-id <dataset_id>
.venv/bin/python -m unittest discover -s tools/exness_tick_history/tests -p 'test_*.py'
```

`inspect-config` performs no network or terminal operations. `inventory` is
bounded network discovery and writes only its local manifest; it does not
download the full archive bodies. `download`, `build`, and export require their
explicit command. Network tests are opt-in; normal tests use deterministic
local fixtures and the existing unittest runner.

## Sprint 1: Freeze The Source, Feed, And Terminal Contract

**Goal**: a runnable configuration/inventory inspector and an evidenced pilot
contract that prevent the wrong feed, timezone, or import assumptions from
entering the pipeline.

**Dependencies**: separately authorized plan execution, repository baseline,
archive reachability, and operator access to the chosen reference terminal for
the native capability check.

**Tracked scope**: package entrypoints, `config.py`, initial `archive.py`,
example profile, requirements, `README.md`, `test_config.py`, `test_archive.py`,
the new workflow document, and the precise artifact ignore rule.

**Commit**: `feat(exness): define tick history source and feed contracts`

### Task 1.1: Package And Configuration Boundary

- **Location**: package entrypoints, `config.py`, example TOML and requirements.
- **Work**: implement strict profile parsing and the `inspect-config` command;
  validate date semantics, base/suffix/exact symbol mappings, schema versions,
  data roots, limits, and optional comparison thresholds. Keep Pro demo/live
  server profiles distinct and map Ubuntu paths to the selected Wine terminal
  explicitly. Use the existing Python/DuckDB version conventions. Make
  unresolved operational feed fields explicit.
- **Acceptance**: invalid ranges, unsafe identifiers, wrong types, incompatible
  mappings, and unknown options fail with useful errors before any I/O.
- **Validation**: `test_config.py`; run the documented `--help` and
  `inspect-config` commands, plus invalid configuration examples.
- **Rollback**: remove this package increment via the sprint revert; preserve
  independently owned files and local evidence.

### Task 1.2: Archive Discovery And Source Contract Pilot

- **Location**: initial `archive.py`, `test_archive.py`, workflow source-contract
  section; ignored pilot evidence.
- **Dependencies**: Task 1.1.
- **Work**: verify all three observed URL layouts with bounded probes; inspect
  small, complete pilot archives and headers; verify UTC grammar, source-symbol
  mapping, member structure, availability semantics, and earliest-file caveat.
  Record response status, size, checksum, selected period, and evidence source.
  Handle a blocked page and an accessible archive host independently.
- **Acceptance**: no invented endpoint, unsupported feed mapping, or assumption
  that all symbols have January 2015 history. A source-contract failure leaves
  an explicit blocker rather than falling back to another account type.
- **Validation**: `test_archive.py`; bounded inventory/pilot commands for one
  annual, one monthly, and one daily candidate; inspect an unavailable period
  and a simulated denied response. These are discovery checks, not a backfill.
- **Rollback**: retain raw pilot evidence; no terminal or broker history is
  changed by this task.

### Task 1.3: Pin Broker, Native Import, And Comparison Prerequisites

- **Location**: workflow, example-profile field definitions, ignored local
  broker specification/reference profile and pilot report.
- **Dependencies**: Tasks 1.1-1.2; operator supplies target terminal/feed facts.
- **Work**: pin live/demo, exact symbol, private server identity, terminal/build,
  current specification and time mapping. Verify Ubuntu 22.04/24.04 plus Wine
  path handling, existing MCP reachability and current tool schemas. Resolve
  the observed zero `tick_size` against a native specification before treating
  the metadata as complete. Guide the operator through a tiny native
  creation/import/export capability check on a disposable owned custom symbol.
  Establish whether tick import builds usable M1 bars, whether equal-time ticks
  survive, and the exact capture/export format. Verify a bounded MCP-to-file
  handoff without placing raw tick data in chat. Choose independent pilot and
  held-out seasonal dates and define the numeric comparison profile before
  scoring the latter.
- **Acceptance**: the M1 path and native-export completeness/precision are
  known; Pro mapping is evidenced or explicitly unresolved; no live symbol,
  account setting, order, or existing custom history is modified.
- **Validation**: record the selected import procedure, small row counts,
  timestamp multiplicities, copied specification, and bar availability. Use the
  existing terminal MCP for supported checks: discover its schema and call
  `get_workspace_info` first; check precision, complete interval coverage and
  limits before relying on its output. Confirm that Market Watch visibility
  and file creation operations are not mistaken for symbol creation/import.
  Keep private data out of tracked evidence.
- **Rollback**: return to the previously selected symbol; leave the disposable
  symbol isolated until its owner elects to remove it. No automated cleanup of
  existing terminal history.

**Sprint acceptance**: configuration commands work, source evidence is pinned,
and the native import/feed/time contract has enough evidence for the next
increments. Do not claim equivalence from this pilot.

**Rollback point**: record the actual pre-sprint HEAD as `S1_BASE_SHA`; the
planning baseline is informational and must not replace that execution check.

**Gate**: complete Tasks 1.1-1.3, record actual validation and residual risks,
perform the common review gate, create exactly the proposed Sprint 1 commit,
record its SHA and `S1_BASE_SHA`, then and only then start Sprint 2.

## Sprint 2: Resumable Full-Range Archive Acquisition

**Goal**: a runnable `inventory`/`download` workflow that can account for the
requested history and resume interrupted downloads without duplication or
silent missing periods.

**Dependencies**: Sprint 1 gate.

**Tracked scope**: `archive.py`, `download.py`, `storage.py`, CLI, configuration,
`test_archive.py`, `test_download.py`, and package/workflow documentation.

**Commit**: `feat(exness): add resumable archive inventory and downloads`

### Task 2.1: Coverage And Ownership Ledger

- **Location**: `archive.py`, `storage.py`, `test_archive.py`.
- **Work**: implement run cutoff freezing, bounded candidate discovery,
  annual/monthly/daily selection, explicit per-interval source ownership,
  immutable source versions, resumable ledger transitions and data-root locks.
- **Acceptance**: auto mode avoids redundant coverage; explicit ranges and
  granularity overrides work; partial current periods, earlier unavailable
  history and uncertain gaps remain visible. A second writer fails safely.
- **Validation**: fixtures spanning a leap day, December/January, partial
  first/last periods, old/republished annual archives, and daily/monthly overlap;
  interrupted-ledger/restart and lock-contention tests.
- **Rollback**: never downgrade the ledger in place. Retain the previous ledger
  snapshot and source version; a changed ledger format uses an explicit version
  and tested recovery, with atomic migration if one is necessary.

### Task 2.2: Bounded Download And Archive Integrity

- **Location**: `download.py`, CLI/config limit fields, `test_download.py`.
- **Dependencies**: Task 2.1.
- **Work**: streaming I/O, bounded HTTP concurrency, backoff, proxy/network
  diagnostics, byte-range resume validation, source validators, ZIP/CRC and
  SHA-256 checks, disk preflight, cancellation and atomic completed objects.
- **Acceptance**: a failed, truncated, changed, HTML-disguised-as-ZIP, or denied
  download can never be marked complete. Resume cannot append a full 200
  response to a partial file. Existing completed archive bytes remain intact.
- **Validation**: standard-library mock/local HTTP fixtures for 200/206, ignored
  ranges, stale ETags, bad Content-Range/length, truncated ZIP, 403/404/429/5xx,
  Retry-After, low disk, and interruption immediately before publication.
- **Rollback**: preserve complete immutable archives; quarantine only this run's
  incomplete objects and resume with a new run ID if the ledger is inconsistent.

### Task 2.3: Demonstrate An Interrupted Mixed-Granularity Pilot

- **Location**: package README/workflow and ignored run manifests.
- **Dependencies**: Tasks 2.1-2.2.
- **Work**: download a bounded pilot that exercises selected old-year coverage
  and recent daily/monthly coverage, interrupt and resume it, then repeat the
  command without changing inputs. Estimate remaining backfill bytes without
  launching the full-history run yet.
- **Acceptance**: repeated execution fetches no already verified completed
  archive body; every candidate has an explicit state and each selected source
  interval has one owner. Network failure leaves a truthful incomplete run.
- **Validation**: documented `inventory` and `download --resume` commands,
  retained counts/checksums, network-byte totals, lock ownership and disk usage.
- **Rollback**: keep evidence and completed sources; revert this sprint's code
  if necessary and restart from the previous compatible manifest version.

**Rollback point**: record `S2_BASE_SHA`, normally the Sprint 1 commit.

**Gate**: finish all tasks and focused download/inventory tests, record the
pilot evidence and common review gate, create exactly the Sprint 2 commit and
record both SHAs before Sprint 3.

## Sprint 3: Deterministic Sanitized Tick Datasets

**Goal**: `build` produces an auditable, ordered dataset from verified archives
with exact quote values, conserved rows, and bounded resource consumption.

**Dependencies**: Sprint 2 gate.

**Tracked scope**: `sanitize.py`, dataset portions of `storage.py`, `report.py`,
CLI/config, `test_sanitize.py`, `test_pipeline.py`, and documentation.

**Commit**: `feat(exness): build deterministic sanitized tick datasets`

### Task 3.1: Strict Parsing, Provenance, And Quarantine

- **Location**: `sanitize.py`, `test_sanitize.py`.
- **Work**: implement the frozen CSV grammar, integer UTC timestamps, exact
  decimals, source row identity, ZIP member safeguards, semantic quote checks,
  and reason-coded quality/quarantine output.
- **Acceptance**: wrong feed/symbol, invalid fields and unsupported precision
  fail clearly; valid zero spread and repeated equal-time ticks survive.
  Outliers are flagged without altering prices. Row accounting is exact.
- **Validation**: tiny authored fixtures for BOM/encoding/header drift, wrong
  symbol, timestamp boundaries, invalid/negative/NaN quotes, decimal precision,
  crossed/zero spread, legitimate duplicates, ZIP traversal/bombs/encryption,
  and source row identifiers across archive members.
- **Rollback**: discard no raw source. A corrected sanitizer produces a new
  dataset ID; retain previous quality and rejection evidence.

### Task 3.2: Ordered Merge And Atomic Partitions

- **Location**: `sanitize.py`, `storage.py`, `test_pipeline.py`.
- **Dependencies**: Task 3.1.
- **Work**: apply source interval ownership, stable tie ordering, explicit
  UTC-date partitions, bounded sorting/spill, partition manifests and atomic
  publication. Record canonical logical hashes separately from volatile run
  metadata and storage-format metadata.
- **Acceptance**: changed worker counts, source discovery order, or restart
  cannot change ordered logical ticks; same-time groups survive partition/chunk
  edges. No accepted partition points to partial output.
- **Validation**: annual/month/day overlap and conflict fixtures, unordered
  discovery, timestamp regressions, tied rows, restart at partition commit, and
  two builds with different worker/batch limits compared by ordered hashes.
- **Rollback**: preserve the prior dataset manifest and partitions; stop readers
  from selecting the incomplete new dataset, then regenerate under a new ID.

### Task 3.3: Coverage, Quality, And Resource Audit

- **Location**: `report.py`, CLI `audit`, relevant tests and workflow.
- **Dependencies**: Tasks 3.1-3.2.
- **Work**: report actual/requested spans, missing and unknown coverage,
  timestamp precision, duplicates, regressions, spread/jump diagnostics,
  retention/exclusion conservation, throughput, peak RSS and temporary disk.
- **Acceptance**: no clean dataset status when required sources, ordering, or
  quarantine remain unresolved. Resource use fits the configured measured
  budget; no whole-history materialization is used.
- **Validation**: report/row-count assertions and a bounded real pilot with
  recorded inputs, elapsed time, peak RSS and disk. Test a constrained-memory
  dataset larger than the chosen in-memory buffer and an exhausted spill disk.
- **Rollback**: mark the new dataset unusable in its external selection record;
  do not rewrite immutable manifests, delete raw evidence, or edit accepted
  historical artifacts to repair a report.

**Rollback point**: record `S3_BASE_SHA`, normally the Sprint 2 commit.

**Gate**: finish all tasks, pass sanitizer and pipeline tests, reconcile pilot
rows and ordered hashes, perform the common review gate, and create exactly
the Sprint 3 commit with recorded rollback SHA before Sprint 4.

## Sprint 4: MT5 Import Package And Exact Round Trip

The accepted workflow uses guided MT5 symbol creation/import by the operator.
The service prepares the files and settings manifest; the existing MCP readers
and local comparison commands verify the imported result. No new MQL5 importer
or script-launch integration is part of this sprint.

**Goal**: import the sanitized pilot into a fresh custom symbol and demonstrate
that MT5 preserves its quotes, timestamp precision, multiplicity and required
bar history.

**Dependencies**: Sprint 3 gate; Sprint 1 terminal/import/specification contract;
operator access to the Wine terminal for the accepted guided import steps.

**Tracked scope**: `mt5_export.py`, native-export intake and exact comparison in
`compare.py`, CLI, `test_mt5_export.py`, initial `test_compare.py`, and workflow.

**Commit**: `feat(exness): export validated MT5 custom symbol history`

### Task 4.1: Deterministic MT5 Files And Import Manifest

- **Location**: `mt5_export.py`, `test_mt5_export.py`.
- **Work**: implement the official six-field format, precise formatting,
  explicit clock mapping, trade-tick/digit compatibility validation, ordered
  chunks and import manifest. Implement the companion M1 path only if required
  by the Sprint 1 finding, using the verified native bar convention.
- **Acceptance**: no silent timestamp shift or price rounding; invalid geometry
  of the destination specification blocks export. All required periods and
  equal-time groups have deterministic, non-overlapping import ownership.
- **Validation**: golden text format tests, source/export numeric round trips,
  locale independence, chunk boundaries, historical spec incompatibility,
  timezone boundaries, and M1 derivation tests when that path is needed.
- **Rollback**: keep prior exports immutable; corrected format/mapping/spec
  creates a new export ID and custom-symbol destination.

### Task 4.2: Guided Custom-Symbol Creation, Import And Re-Export

- **Location**: workflow, ignored symbol specification and native export files.
- **Dependencies**: Task 4.1.
- **Work**: provide exact guided steps for the operator to open MT5's Symbols
  dialog, create an owned versioned custom symbol with a retained XAU prefix,
  copy and freeze the broker specification, select the Ticks import tab, and
  import the generated chunks in manifest order with the declared separator,
  header skip and `Shift=0`. Include the companion M1 import only when the
  Sprint 1 finding requires it. Use the existing MCP readers for supported
  post-import checks of ticks and M1/M3/M10/H1 history, and obtain the complete
  native re-export required by the exact round-trip comparison. Record build,
  counts, settings and completed import chunks.
- **Acceptance**: the operator can reproduce the process without editing raw
  tick files or broker history. Partial imports cannot be selected as accepted
  research input. All warm-up and scored bars are available and causal.
- **Validation**: guided native UI actions, MCP-supported reads, and recorded
  before/after metadata; verify first/last ticks, equal-time multiplicities,
  gaps, and native timeframe bars.
  A truncated reader/UI export must be split into exhaustive non-overlapping
  intervals; preserve all ticks at a shared millisecond boundary.
- **Rollback**: select the prior accepted custom symbol. Retain the new one as
  unaccepted evidence; do not alter its specification in place to repair data.

### Task 4.3: Exact Ordered Round-Trip Gate

- **Location**: `compare.py`, `test_compare.py`, CLI `compare-roundtrip`.
- **Dependencies**: Task 4.2 and native-export parser contract.
- **Work**: compare canonical time/Bid/Ask values and multiplicities in order,
  with native-calculated flags kept separate. Check specification hashes and
  required bar coverage. Report the first bounded mismatch and full counts.
- **Acceptance**: any lost, added, changed, reordered same-time, or truncated
  tick fails exact round-trip acceptance; timezone or number-format parsing
  cannot hide a mismatch.
- **Validation**: exact-match fixture plus one-row deletion, duplication,
  same-time reversal, 1 ms/1 tick perturbation, wrong spec, and truncated export
  fixtures; run `compare-roundtrip` on the native pilot export.
- **Rollback**: quarantine the failed export/custom-symbol version for use;
  preserve evidence and rebuild a new version from immutable canonical data.

**Rollback point**: record `S4_BASE_SHA`, normally the Sprint 3 commit; also
record the previous accepted custom-symbol/export ID, or `none` for first use.

**Gate**: complete all tasks, require exact native round-trip and bar evidence,
record actual checks and the common review gate, and create exactly the Sprint
4 commit with code and data rollback references before Sprint 5. No new MQL5
source or compile is planned for this increment.

## Sprint 5: Winter/Summer Broker Validation

**Goal**: produce an independently interpretable seasonal report that verifies
the clock mapping and quantifies whether the imported feed meets the frozen
broker research requirements.

**Dependencies**: Sprint 4 gate, explicit feed identity, complete reference
exports, predeclared dates and numeric comparison profile.

**Tracked scope**: broker logic in `compare.py`, `report.py`, CLI/config,
`test_compare.py`, `test_pipeline.py`, workflow and acceptance document.

**Commit**: `feat(exness): validate seasonal broker tick and bar parity`

### Task 5.1: Broker Reference Capture And Completeness

- **Location**: native-export intake in `compare.py`, workflow; private
  reference manifests and files under the service data root.
- **Work**: use the existing MT5 MCP readers for bounded captures of broker and
  imported custom-symbol ticks/bars, after verifying their all-quote semantics
  and complete capture-to-file handoff. Use native export when a reader cannot
  provide sufficient precision or complete coverage. Capture
  `COPY_TICKS_ALL`-equivalent quote history and required bars for each full
  selected broker day plus warm-up/adjacent boundaries.
  Pin symbol, private server identity, live/demo, terminal/build, timezone,
  capture time, specification, requested range and observed coverage.
- **Acceptance**: missing broker history, export limits, wrong server/feed,
  mixed clock formats or second-only exports cannot masquerade as equivalent
  complete millisecond history. Empty market intervals have explicit evidence.
- **Validation**: parser and completeness fixtures, including the observed
  `time_ms` string format; inspect native day totals and interval boundary
  exports. Avoid the MCP reader's default record limit by verified exhaustive
  interval subdivision. A limit-sized response is potentially truncated; split
  further or use a complete export, never advance beyond the last returned tick
  and lose other ticks with the same timestamp. Mark a capture inconclusive if
  complete millisecond/equal-time preservation cannot be established.
- **Rollback**: leave reference captures immutable; recapture to a new ID when
  a correction is needed.

### Task 5.2: Clock, Quote, Session And Bar Comparison

- **Location**: `compare.py`, `report.py`, `test_compare.py`.
- **Dependencies**: Task 5.1.
- **Work**: implement the defined one-to-one matching, bidirectional unmatched
  accounting, signed lag diagnostics, quote/spread error distributions,
  minute/hour activity, session boundaries, native OHLC and pivot-input checks.
  Evaluate every threshold independently and distinguish fail from inconclusive.
- **Acceptance**: a deliberately shifted hour, wrong feed, missing segment,
  reversed tied tick group, or systematically altered spread cannot pass through
  a high aggregate correlation. Unset limits cannot produce `PASS`.
- **Validation**: deterministic reference fixtures for exact equality and each
  defect, US/UK transition mismatch periods, whole-day UTC conversion, unchanged
  quotes, sparse periods, ambiguity, no-data cases and one-to-one match support.
- **Rollback**: invalidate the comparison selection after any comparator or
  threshold change; keep the previous report and rerun under a new ID.

### Task 5.3: Held-Out Seasonal And Transition Acceptance

- **Location**: workflow, acceptance document, ignored comparison artifacts.
- **Dependencies**: Tasks 5.1-5.2; frozen profile from Sprint 1.
- **Work**: run the winter and summer comparisons independently. Add targeted
  pre/post-DST trading-day diagnostics for relevant US/UK boundaries. Explain
  any difference between broker-time alignment and analysis-session labeling.
- **Acceptance**: both seasonal reports pass the predeclared mandatory gates,
  or record a truthful fail/inconclusive blocker. Transition anomalies block
  the affected clock/session claim. No threshold tuning or favorable date
  replacement is permitted after seeing an acceptance failure.
- **Validation**: documented `compare-broker` invocations; record date/range,
  data/spec/profile hashes, metrics, supports, missing periods, result states,
  and operator review. Keep account identifiers and raw ticks private.
- **Rollback**: retain the old accepted dataset/custom symbol, or no accepted
  selection for first use. Fix the diagnosed source/mapping defect in a new
  version and rerun every dependent gate.

**Rollback point**: record `S5_BASE_SHA`, normally the Sprint 4 commit, plus
the prior comparison and threshold-profile IDs.

**Gate**: finish all tasks, pass comparison defect tests and required seasonal
checks, record residual historical limitations and the common review gate,
then create exactly the Sprint 5 commit and record rollback before Sprint 6.
Insufficient broker history is a blocked acceptance gate, not a passing test.

## Sprint 6: Full History And V13 Research Handoff

**Goal**: complete the selected available history, demonstrate manageable
resource use and recovery, and run the unchanged EA against the accepted custom
input with strict V13 outputs and explicit data provenance.

**Dependencies**: Sprint 5 gate, measured disk/time budget, archive access and
the existing operator-owned Strategy Tester environment.

**Tracked scope**: final CLI/report reliability adjustments as justified by
evidence, `test_pipeline.py`, package README, workflow/acceptance documents,
root README and links in the existing environment/statistics documentation.

**Commit**: `feat(exness): complete full-history research workflow and handoff`

### Task 6.1: Full Backfill And Reproducibility Audit

- **Location**: service commands and ignored full-history manifests/artifacts.
- **Work**: use measured archive expansion, output, spill, and MT5 storage
  requirements to check the configured disk budget; inventory 2015 through the
  frozen latest complete publication cutoff; download, sanitize, merge and
  export the full selected history. Resume after one controlled interruption.
- **Acceptance**: every requested interval has a supported coverage status;
  every available selected archive is accounted for; actual earliest/latest
  ticks and unknown/unavailable periods are explicit. A source archive beginning
  after January 2015 is not represented as complete January coverage. No
  hidden gap, quarantine, or ambiguous ordering receives an accepted status.
- **Validation**: `inventory`, `download --resume`, `build`, `audit`, and
  `export-mt5`; record logical counts/hashes, peak RSS, disk high-water, elapsed
  time and observed throughput. Rerun unchanged work to demonstrate reuse of
  verified archives/partitions, not another unnecessary full download.
- **Rollback**: continue selecting the previous accepted dataset; retain all
  complete new raw files and isolate the unfinished derived version. Recovery
  must not depend on downloading a republished URL with identical bytes.

### Task 6.2: Full Custom History And Bounded V13 Tester Smoke

- **Location**: existing `HFT_Grid_AI.mq5` binary, native terminal, existing V13
  Python commands, and service research provenance sidecar.
- **Dependencies**: Task 6.1.
- **Work**: import the full export manifest into a fresh versioned custom
  symbol, verify full native tick round trip in bounded chunks and required
  bar coverage, then run a bounded human Strategy Tester pass using `Every tick
  based on real ticks`, configured H1/M10/M3 defaults, and `EXNESS_SESSION`.
  Include real warm-up bars. Record EA/binary hash, tester build/settings,
  input dataset/export/custom-symbol/spec hashes and resulting V13 run ID.
- **Acceptance**: the tester consumes imported real ticks without an unnoticed
  modeled-tick fallback; quote-derived completed bars are available; the
  unchanged producer emits strict V13 and remains within its accepted ownership
  boundaries. Data preparation never calls the broker execution path.
- **Validation**: native tick/bar counts and ordered hashes, tester report/
  journal inspected for data substitution and history issues, then:

  ```bash
  .venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root <PivotFractalV13/runs> --run-id <custom_run_id> --validate-only
  .venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root <PivotFractalV13/runs> --run-id <custom_run_id> --dataset-id <research_dataset_id>
  .venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py --dataset-id <research_dataset_id> --audit-id <audit_id> --minimum-group-support 30
  ```

  A bounded run may have insufficient statistical support; record that limit
  instead of weakening the support floor. Store input provenance outside the
  twelve-file V13 run folder, and keep broker/custom research cohorts separate.
  Reuse the accepted compile unless its inputs changed; if a compile becomes
  required, call MetaEditor `get_workspace_info` before `compile_file`, require
  `0 errors, 0 warnings`, and verify regenerated `.ex5` metadata using the
  documented runner only if MCP cannot execute.
- **Rollback**: stop only the owned tester run, select the prior custom symbol
  and dataset, and leave prior V13 runs immutable. No live rollout or chart-
  rendering acceptance claim follows from this data-validation smoke.

### Task 6.3: Operational Runbook And Final Handoff

- **Location**: package README, workflow, acceptance document, and concise
  links in root/environment/statistics documentation.
- **Dependencies**: Tasks 6.1-6.2.
- **Work**: document initial setup, exact symbol/account selection, dates and
  granularity overrides, partial-publication handling, resume, VPN/network
  diagnostics, storage planning, safe custom-symbol versioning, seasonal
  revalidation, data/threshold changes, and recovery from interrupted imports.
  Provide commands to extend the history later while preserving prior versions.
- **Acceptance**: another operator can reproduce the accepted pipeline and
  distinguish integrity, import equality, broker similarity, historical
  limitations, and unrun checks. No source credential, dataset or private
  account fact appears in the tracked handoff.
- **Validation**: all focused service tests, the existing V13 contract suite
  once for final integration, doc links and identifiers, source/include scope,
  ignored-artifact checks, and `git diff --check`. Check install/setup in a
  clean temporary virtual environment without changing the project environment
  unnecessarily.
- **Rollback**: revert only the sprint's reviewed tracked changes; preserve
  operator-owned raw data, accepted reports, and historical handoffs.

**Rollback point**: record `S6_BASE_SHA`, normally the Sprint 5 commit; record
the final previous/current dataset, export, custom-symbol, comparison, and V13
run identifiers and the measured reconstruction requirements.

**Gate**: finish all tasks and required integration/operator checks, report
unrun or statistically unsupported checks accurately, complete the common
review gate, create exactly the Sprint 6 commit, record rollback, and only then
mark implementation complete. Unresolved required integrity/import/seasonal
gates prevent completion; a documented offline statistical-support limitation
does not become a deployment or model-readiness claim.

## Testing Strategy And Common Sprint Review Gate

Use the existing Python test style and project instructions. Tests validate
observable conservation, ordering, recovery and comparison defects; do not add
tests that merely mirror implementation or add new MQL5/CI infrastructure.

| Layer | Required evidence |
| --- | --- |
| Unit | strict config/schema parsing, dates/UTC, exact decimal values, duplicate multiplicity, deterministic tie order, interval ownership and comparison formulas |
| Integration | HTTP status/range/retry cases, archive corruption, ledger locks/restart, disk limits, atomic partitions and immutable source changes |
| Native MT5 | symbol specification, six-field import, zero UI shift, millisecond/equal-time preservation, complete re-export and required timeframe history |
| Scientific validity | seasonal tests chosen in advance, frozen tolerances, one-to-one support, missingness, session/DST diagnostics and retrospective limits |
| Operational | full-history disk/RSS/throughput measurement, controlled interruption and resume, repeat-run reuse, partial import recovery |
| Security/privacy | path and ZIP confinement, bounded expansion, verified TLS, controlled redirects/hosts, secret-redacted proxy/errors, no account/trading mutations |
| Research regression | unchanged V13 source/schema; final existing contract suite and strict validate/build/audit of an isolated custom-symbol run |
| Accessibility | no new user interface; clear CLI messages, stable exit statuses and readable native-import instructions |

Run the narrowest tests for a task and the combined affected suite for its
sprint. Reuse evidence while inputs remain unchanged. For every sprint:

```bash
.venv/bin/python -m compileall -q tools/exness_tick_history
.venv/bin/python -m unittest discover -s tools/exness_tick_history/tests -p 'test_*.py'
git diff --check
git diff --name-only
git check-ignore artifacts/exness_tick_history/probe.json .codex-artifacts/probe.txt .codex-hook-state/probe.json
rg -n 'OrderSend|TRADE_ACTION_|order_send|trade_send_|CustomTicks|CustomSymbol' tools/exness_tick_history
rg -n '^#include' HFT_Grid_AI.mq5 services/trading_tools.mqh services/trading_management.mqh services/trading_signals.mqh services/frontend.mqh
```

Review identifier matches in context; documentation may mention prohibited
operations to describe the boundary. Confirm the new service has no executable
trade/account mutation or hidden EA include, and trace the existing aggregators
without changing them. Confirm changed paths stay within the sprint's reviewed
scope. Use RTK wrappers for noisy status/diff/test output when available; retain
exact diagnostics only when needed.

At final integration, or earlier if an existing research input changes:

```bash
.venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'
```

Record commands, actual exit statuses, input hashes, bounded diagnostics and
evidence locations. Planning discovery is not implementation validation. Do not
claim a compile, native import, broker comparison, full backfill or tester run
passed unless it was actually performed against the stated inputs.

## Risks And Mitigations

| Risk | Impact | Mitigation / validation signal |
| --- | --- | --- |
| Regional 403 or VPN-dependent access | Incomplete download mistaken for no history | Separate page/CDN probes; explicit access-denied state; user-managed network prerequisite; resumable transfers |
| Public archive layout or symbol mapping changes | Wrong feed or missing objects | Version observed adapter, inspect actual header/symbol, pin account mapping; no silent fallback |
| 2015 selector mistaken for January coverage | Biased historical statistics | Actual per-file/day spans and source gaps; complete coverage audit before acceptance |
| Annual/monthly/day overlap or republishing | Duplicate, conflicting, or irreproducible ticks | One owner per interval, source hashes, immutable revisions and logical row conservation |
| Historical effective timestamp resolution differs | False fine-grained sequencing claims | Per-period precision diagnostics; preserve order/ties; distinguish observed sequence from exchange sequence |
| Wrong DST/time conversion | Different H1/M10 pivots and sessions | Keep UTC, broker and analysis time distinct; measured mapping, seasonal and transition tests |
| Overaggressive sanitization | Altered first-touch and spread statistics | No smoothing/resampling; preserve valid duplicates; explicit quarantine and excluded-row accounting |
| MT5 settings/import replaces history | Lost or mixed custom history | Freeze spec first, fresh owned version, manifest chunk spans and exact round trip |
| Tick import lacks usable bar history | EA reads absent or inconsistent pivot/indicator inputs | Early native capability check, conditional M1 companion, native M3/M10/H1 validation |
| Modern contract settings applied to old prices | Incorrect price-grid checks, margin or P&L claims | Version specification and scope historical limitations; no silent rounding or all-era broker simulation claim |
| Truncated broker reference or wrong live/demo feed | Misleading similarity | Exact profile capture, complete interval export, millisecond/tie checks, inconclusive on missing evidence |
| MCP read tools mistaken for creation/import support | An automation promise cannot be executed | Use the accepted guided native creation/import steps; restrict MCP orchestration to its verified supported operations |
| MCP specification contains a zero tick size | Invalid export grid and misleading price-error units | Verify the native specification; no automatic substitution of point size or relaxation of EA checks |
| Wine paths or MCP capture precision misinterpreted | Wrong files or shifted/truncated broker data | Explicit Ubuntu/Wine path mapping, runtime roots, typed capture adapters and exact round-trip checks |
| Similar prices hide missing/reordered events | Biased signal frequency/first touches | One-to-one matching, bidirectional support, clock/session/bar gates and defect-injection tests |
| Small seasonal sample overgeneralized | Unsupported historical/execution conclusions | Restrict claim to sampled feed/dates; full-history integrity audit remains a separate requirement |
| Large decompression/sort/MT5 storage expansion | OOM, full disk, incomplete import | Pilot-based estimates, streamed partitions, measured RSS/spill/disk, stop safely before publication |
| Secret leakage through profiles/logs | Private terminal/network data exposed | Ignored local profiles, server alias/hash in tracked reports, redact proxy/auth data and errors |
| Tester substitutes generated ticks | Statistics no longer reflect imported archive | Inspect real-tick report/journal and input counts; block affected acceptance |

## Rollback And Execution Order

All user workflow choices are accepted and recorded, including guided native
creation/import with MCP-assisted comparison. This plan is finalized.
Execution begins only after the user separately authorizes the saved plan.
An instruction to execute it authorizes its scoped implementation and six
sprint commit gates; it does not authorize live rollout, account/trading
changes, automated VPN configuration, or a different automation architecture.

At that handoff, resolve and read `references/execution-state.md` relative to
the installed planner skill. Initialize active-plan state in ignored
`.codex-hook-state/` before Sprint 1. Do not initialize that state during this
planning turn. On continuation, inspect existing state and accepted decisions
instead of restarting work or repeating an already satisfied authorization.

For each sprint, in order:

1. Inspect branch/worktree, user edits, current state and previous gate. Record
   the actual pre-sprint HEAD and prior accepted artifact IDs.
2. Implement only that sprint; keep independent reads/download workers bounded.
   Do not delegate without explicit authorization.
3. Complete tasks, required tests/operator checks, include/reference and safety
   review, and `git diff --check`; retain truthful failures and unrun gates.
4. Stage only reviewed paths and create exactly one sprint-specific commit with
   the proposed message. No amendment, unrelated staging, or auto-generated
   data in commits.
5. Record the resulting commit SHA, its parent rollback SHA, artifact rollback
   IDs, validation inputs/results and residual risks in execution state and the
   concise handoff. Only then advance to the next sprint.

The parent SHA is the source rollback point; it does not restore externally
imported history. Restore code with a reviewed revert of the affected sprint
commits in reverse dependency order. Do not use destructive resets. Keep raw
ZIPs, accepted datasets and reports immutable. Select the prior accepted
dataset/export/custom symbol instead of deleting or rewriting terminal data.
For a first-time failed import, the rollback selection is `none` until a new
version passes; there is no implicit permission to overwrite a broker symbol.

If raw source, sanitizer, clock mapping, destination specification, native
import behavior, comparator or thresholds change, invalidate the corresponding
selection and rerun its dependent gates against new versioned artifacts. Do
not delete retained handoffs or recast old failed runs as successful ones.

## Completion Checklist

- [x] Original user choices for Ubuntu/Wine, Pro symbol/suffix support, CLI/MCP
  assistance, and comparison policy are recorded.
- [x] Guided native creation/import is accepted, with MCP-assisted comparison;
  the corresponding sprint tasks and gates are finalized.
- [ ] Per-run target-feed/terminal/specification prerequisites are verified.
- [ ] All six sprints pass their required gates in order.
- [ ] Exactly one implementation commit exists for each sprint, with its
  parent rollback SHA and external artifact rollback references recorded.
- [ ] Full requested available coverage is accounted for; earlier unavailable,
  unpublished, missing, and unknown intervals are distinguishable.
- [ ] Source archives and all derived artifacts have reproducible provenance;
  no valid duplicate or equal-time order is silently lost.
- [ ] Native custom-symbol tick round trip is exact and required bars exist.
- [ ] Winter and summer broker comparison gates pass their predeclared
  requirements; relevant transition diagnostics and limits are documented.
- [ ] Full-history resource/restart checks and bounded real-tick V13 research
  handoff are complete, with honest statistical-support limitations.
- [ ] Raw data, logs, credentials, private account details and `.ex5` output
  remain untracked; no existing accepted evidence was rewritten.
- [ ] The EA, broker safety kernel, twelve-file V13 contract and outstanding
  deployment-oriented human rendering gate retain their existing boundaries.

No implementation, native import, full backfill, tester run, or sprint commit
is performed by saving this plan.

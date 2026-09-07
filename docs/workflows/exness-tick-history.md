# Exness Tick History Workflow

The [service](../../tools/exness_tick_history/README.md) prepares independent
historical research inputs. It does not participate in the EA's include
pipeline, broker execution or strict twelve-file V13 output contract. The
[six-sprint implementation plan](../plans/archive/exness-tick-history-2026-09-07/README.md)
is complete and archived. The [current handoff](../research/exness-tick-history-handoff-2026-09-07.md)
records passing winter/summer custom imports and retained captures. Formal
broker equivalence remains `INCONCLUSIVE`; registered-export acceptance,
full-history operation and tester evidence remain pending.

## Source And Profile Contract

Verified adapter: `https://ticks.ex2archive.com/ticks/` with annual, monthly and
daily `Exness_<symbol>_<period>.zip` objects. Version 1 accepts exactly one
matching CSV with header `Exness,Symbol,Timestamp,Bid,Ask`, vendor `exness`,
explicit symbol and UTC millisecond timestamps ending in `Z`. Preserve raw ZIPs,
valid repeated rows and equal-time order. Availability probes do not prove
coverage. The inspected 2015 annual sample begins on August 10.

Use isolated Pro demo/live profile IDs. Current broker symbols are bare;
future suffixes are explicit. Pin a private opaque server alias, exact broker
symbol and evidence of archive/feed mapping before comparison. Keep private
profiles, raw data and terminal captures under `artifacts/exness_tick_history/`
or a dedicated external data root. Shared roots allow one writer at a time.

## Native Verification Contract

The existing `XAUUSD_EXN_PRO_W1` and `XAUUSD_EXN_PRO_S1` diagnostic ranges pass
exact tick and native M1/M3/M10/H1 OHLC/tick-volume audits, including warm-up.
MT5 generated these bars from ticks; no separate bar import or chart opening
is needed to verify these ranges. The winter import starts on January 12 at
20:00 and contains 922,664 ticks; summer contains 947,513 ticks. See the handoff
for complete intervals and report hashes. These diagnostics do not replace
registered `export-mt5`/`compare-roundtrip` evidence or broker acceptance.

For each future registered package:

1. Verify the selected Wine prefix, terminal/build, host-to-Windows mapping,
   account mode and exact broker symbol. Discover MCP schemas and call its
   `get_workspace_info` before terminal operations.
2. Capture the native symbol specification. The initial MCP snapshot reported
   `digits=3`, `point=0.001`, **tick size zero**. Resolve the actual trade tick
   from the native specification; zero is invalid and must block export.
3. Pin a reversible historical UTC-to-broker clock mapping. Source UTC, broker
   chart time and the EA's export-only analysis time are separate. Do not apply
   the EA's winter analysis adjustment to imported ticks.
4. Create a fresh custom name retaining `XAU` and at most 31 characters, copy
   and freeze the broker specification, and import the small pilot with tabs,
   one header row skipped and Shift=0. Current MCP readers cannot create or
   import a custom symbol; the operator performs the native UI steps.
5. Re-export all pilot ticks, preserving milliseconds and equal-time groups.
   Check M1, M3, M10 and H1 bars. Tick-generated bars pass for the two prepared
   seasonal ranges; verify native bar availability and equality for each new
   package before acceptance.
6. Pin numeric comparison limits from a separate pilot before formal scoring
   of the fixed seasonal days, 2026-01-14 and 2026-07-15. Their inspected
   diagnostics cannot be used to tune limits; defaults remain proposals.
   Incomplete captures or unverified feed/clock yield
   `INCONCLUSIVE`, never broker acceptance.

The prepared native pilot and raw evidence remain in ignored
`.codex-artifacts/exness-sprint1/`. It contains 1,831 ticks in five minutes and
nine adjacent equal-time rows. The later five-minute native verification is
retained in `.codex-artifacts/exness-native-probe-20260906/`; final seasonal
captures and audits are in `.codex-artifacts/exness-seasonal-native-20260906/`.

## Guided Native Import And Evidence

After the native specification and clock evidence are recorded, prepare an
export using the service README commands. In MT5, open Market Watch -> Symbols
(Ctrl+U), select the exact broker symbol, and create a custom symbol copying its
properties. Use the package's fresh `custom_symbol` name and freeze the complete
specification before importing. Confirm the name is still unused at creation.
Changing properties such as digits, point or chart mode afterward can erase
history. Never select the broker symbol as the import destination.

Open the custom symbol's Ticks tab and import each manifest chunk in order.
Set tab separator, skip the one header row, verify the six preview columns and
use Shift=0. Skip zero columns: row skipping and column skipping are distinct
controls. Record each filename/hash/count in an operator-owned import log.
Import replaces the covered interval, including holes; a partial import is not
accepted history. Recovery uses the same owned version and exact chunk files
only after confirming which intervals were replaced, or a fresh custom symbol.

Re-export the entire imported interval from the native Ticks tab. If the UI or
reader limits rows, capture exhaustive disjoint intervals without splitting an
equal-millisecond group. Export native M1/M3/M10/H1 bars for the same imported
coverage. Expected bar format is tab-separated
`<DATE> <TIME> <OPEN> <HIGH> <LOW> <CLOSE> <TICKVOL> <VOL> <SPREAD>`;
bar dates are dotted and times are `HH:MM:SS`. Tick times require milliseconds.
If tick import does not produce native M1 bars, this gate remains pending. A
companion M1 path must use the observed native convention before acceptance;
the current implementation does not invent a bar-import convention. Both
validated seasonal ranges already have native bars generated from ticks.

Create a private evidence JSON beside the native files:

```json
{
  "schema_version": 1,
  "operator_verified": true,
  "complete": true,
  "export_manifest_sha256": "from-import-manifest",
  "native_specification_sha256": "hash-of-verified-frozen-specification",
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

The booleans attest completed native operations, never preparation alone.
`compare-roundtrip` checks ordered time/Bid/Ask multiplicity, file/spec hashes,
and exact quote-derived Bid OHLC against every native timeframe. It reports
bounded mismatches. Missing native evidence is `INCONCLUSIVE`; a demonstrated
tick, specification or bar mismatch is `FAIL`.

## Seasonal Broker Captures

Capture terminal evidence once and replay the analysis with the service's
[`freeze-capture` and `audit-capture` commands](../../tools/exness_tick_history/README.md#capture-once-audit-offline).
Save raw MCP JSON responses without reserializing numeric prices; record each
actual request interval, returned count and reader limit. Freeze hashes before
analysis. The offline audit checks complete tick order and native Bid OHLC/tick
volumes at M1/M3/M10/H1 in one pass, with explicit failure/incomplete results.
Reuse these raw responses in `compare-broker` with `format=mcp_json`; its
verified feed/specification/clock and pinned threshold requirements remain in
force. Reacquire only missing, corrupt or potentially truncated evidence, or a
deliberately changed capture. A frozen diagnostic audit does not fabricate a
registered MT5 export or operator attestation.

The complete seasonal custom captures and broker tick days are already retained.
Reuse their manifests and reports from the handoff. Native broker January M1
was unavailable through MCP with the 100,000-bar chart limit; broker-tick-derived
M1 diagnostics do not close that native-bar gate. Last observed custom tick
values differ (winter `0.1`, summer `1`), and the broker reader reports zero
tick size/value. Resolve the native specifications before P&L/specification
parity or formal broker acceptance. Do not change existing properties blindly;
some edits erase imported history.

Start with the public `profiles/reference.example.json`, copied into an ignored
reference directory. Its booleans and placeholder hashes deliberately prevent
acceptance. Embed the verified `clock` and `specification` objects, set the exact
profile hash and actual terminal build/capture time, and freeze a day and reason
before scoring. The example broker wall-time interval is January 14, 2026;
the clock object maps that entire day to UTC explicitly. Fetch adjacent UTC
source partitions when the mapping crosses a date boundary.

Pin the private TOML comparison table from a separate pilot:

```toml
# Keep every numeric threshold explicitly set in this table as well.
status = "PINNED"
name = "xauusd-pro-modern-v1"
pinned_at_utc = "2026-09-05T00:00:00.000Z" # replace with the actual pin time
pilot_dates = ["2026-08-25"]               # replace with the reviewed pilot
rationale = "Record the evidence supporting each frozen limit"
```

`inspect-config` prints the feed and comparison profile hashes. Keep Pro demo
and live references separate. Do not reuse an acceptance date as a calibration
pilot or raise thresholds after inspecting a failed acceptance result.

Use native all-quote tick exports for complete days. MCP assistance requires
runtime discovery and workspace preflight. Capture the actual numeric JSON
lexemes to files; retain the raw response with `format=mcp_json`, or normalize
`history` rows to JSONL with `time_ms`, `bid` and `ask` without float conversion.
The timestamp is exactly `YYYY.MM.DD HH:MM:SS.mmm`, interpreted under
the verified broker clock. Do not reinterpret its name as an integer epoch or
discard its milliseconds. Keep account/community fields out of the capture.

Each tick entry declares a disjoint `[start_broker_msc, end_broker_msc)` interval,
file SHA-256, actual row count, format and completeness. For `mcp_jsonl` and
`mcp_json`, also
record the positive reader `limit` and
`millisecond_and_all_quotes_verified=true` only after checking those semantics.
A response with `rows >= limit` is potentially truncated. Bisect the requested
time interval and recapture both halves; never advance to the last returned
tick, which can lose other ticks at that millisecond. The reusable
`split_capture_interval` implements this rule. If a one-millisecond interval
still reaches the limit, use a complete native export. Empty captures need an
`empty_interval_evidence` explanation; empty data alone cannot prove closure.

Capture native M1/M3/M10/H1 bars with at least 26 real completed prior bars per
period, plus the scored day. Include the corresponding real source warm-up
within the dataset (the comparator examines at most seven prior UTC days).
Do not fill missing minutes. Native bar opens, OHLC and completed-bar PP/S1..S3/
R1..R3 input differences are independent evidence. Warm-up diagnostics are
reported separately from the scored day's errors.

Run `compare-broker` with the exact dataset's successful round-trip report.
It writes detailed metrics, row supports, all threshold gates, hashes and a
readable report. Diagnostics at -1/0/+1 hour never adjust data. The default
2026 winter/summer candidates are January 14 and July 15. `seasonal-schedule`
also lists Friday/Monday captures around US and UK transitions and their
mismatch weeks. Future autumn dates remain pending; seasonal sample acceptance
and broader clock-regime acceptance are separate report fields. The initial
release's aggregate uses this deterministic schedule. A justified replacement
day must be frozen and reviewed explicitly; it is not silently substituted by
the aggregate command.

## Full-History Operation And Recovery

The implementation inventory frozen on September 6 UTC requests 2015 through
the latest published candidate day, September 4, 2026. Inventory ID:
`inv-6e244609e216802ca3d09123`. It selects 11 annual, eight monthly and four
daily candidates, totaling 2,993,886,749 compressed bytes. All 23 HEAD probes
were available. At the Sprint 6 checkpoint, three bounded-pilot bodies had been
downloaded and verified; subsequent January/July source downloads support the
seasonal samples. This inventory snapshot is not a current download count or
proof of earliest/full coverage, which still requires the source build/audit.

The conservative storage plan estimates 146,437,977,528 bytes for the complete
workflow versus 120,363,225,088 bytes free at measurement. It uses measured
maximum ZIP expansion 9.2602, pilot Parquet size and explicit allowances of
160 text bytes and 128 MT5-history bytes per tick. Native storage is unmeasured;
this is a planning estimate, not proof that MT5 requires those exact bytes.
Measure the native pilot and/or provision a larger dedicated data root before
the full download/build/export/import workflow. The full backfill remains
pending; no partial pilot is labeled as the complete 2015-present history.

```bash
.venv/bin/python -m tools.exness_tick_history inventory --start 2015-01-01 --end latest-published
.venv/bin/python -m tools.exness_tick_history storage-plan --inventory <full_inventory_id> --pilot-dataset <pilot_dataset_id>
.venv/bin/python -m tools.exness_tick_history download --inventory <full_inventory_id> --resume
.venv/bin/python -m tools.exness_tick_history build --inventory <full_inventory_id> --dataset-id <new_full_dataset_id>
.venv/bin/python -m tools.exness_tick_history audit --dataset-id <new_full_dataset_id>
```

Run from the repo root and include `--config <private_profile.toml>` before each
command once feed and terminal evidence are pinned. A changed feed identity
requires a new inventory/dataset; the ledger can still reuse the same immutable
raw archive bytes. Preserve the pilot and accepted versions. A later history
extension uses new inventory, dataset, export and custom-symbol IDs.

Ctrl-C retains owned partial downloads and build checkpoints. Retry with
`download --resume` or the same build inputs/ID; conflicting immutable inputs
require a new ID. Without `--resume`, only the request's disposable partial ZIP
restarts. Do not remove an active writer lock, overwrite accepted ZIPs or edit
ledger checksums to hide corruption. Restore matching raw bytes from retained
backup or start an isolated corrected version.

## Operator Validation Queue

Implementation and the two sampled diagnostic native-import audits are
complete. Continue with the remaining operational gates:

1. Pin the actual Pro demo/live profile, server alias, feed mapping and terminal
   path/build; verify the nonzero trade tick and native sessions/specification.
2. Verify the historical UTC/broker clock from real tick/bar evidence; keep the
   EA's export-only analysis calendar separate. Existing diagnostics support
   Shift=0 for both sampled days; broader clock evidence remains outstanding.
3. Complete verified registered-export and `compare-roundtrip` evidence after
   the specification/clock prerequisites. The W1/S1 diagnostic imports already
   preserve milliseconds, tied ticks and native bars exactly; do not recreate
   them merely to repeat that passing audit or invent registered export IDs.
4. Calibrate and pin the numeric profile using the independent pilot. Freeze
   complete references before formal scoring, reusing existing captures and
   obtaining missing native broker January M1 bars. Do not calibrate on the
   winter/summer dates whose diagnostics have already been inspected.
5. Run the independent seasonal comparisons. Retain failures and missing-history
   evidence; a replacement day requires a documented predeclared rule.
6. Refine the full-workflow storage estimate, provision capacity, then complete
   the full available source backfill, quality audit and native import/round trip.
7. Run the unchanged EA in the operator-owned Strategy Tester using **Every tick
   based on real ticks**, `EXNESS_SESSION`, H1/M10/M3, real warm-up and an isolated
   custom-symbol run ID. Inspect the tester report/journal for modeled-tick
   substitution and history errors. No live chart deployment follows.
8. Use the existing strict V13 validator, builder and audit from the
   [statistics workflow](pivot-fractal-statistics-flow.md). Preserve its support
   floor of 30 even when a bounded run has insufficient statistical support.
9. Write the service's `research-provenance` sidecar outside V13, linking the
   actual source/binary, dataset/export, symbol/spec/clock and tester evidence.

If compilation becomes necessary for the tester's actual source/toolchain,
follow the [environment preflight/compile policy](../environment/mt5-agentic-workflows.md).
No MQL5 source/include changed during this implementation batch and no new
compile or Strategy Tester run is claimed. The passing seasonal native audits
are scoped to the handoff's exact diagnostic ranges. The earlier V13 human
chart-object/rendering gate also remains independent and outstanding.

## Validation And Rollback

Each sprint runs focused Python tests, compileall, identifier/include and
broker-boundary review, and `git diff --check`. Code rollback uses the recorded
parent commit; preserve immutable raw data and version derived corrections.
No MQL5 source change is planned, so the existing compile evidence is reused.
See the [historical sprint evidence](../research/exness-tick-history-acceptance.md)
and [current handoff](../research/exness-tick-history-handoff-2026-09-07.md).

# Exness Tick History Workflow

The [service](../../tools/exness_tick_history/README.md) prepares independent
historical research inputs. It does not participate in the EA's include
pipeline, broker execution or strict twelve-file V13 output contract. The
[saved plan](../../exness-tick-history-plan.md) defines six sequential commits.
The user deferred native import, specification and broker acceptance until the
implementation batch is complete; these checks remain `PENDING_OPERATOR`.

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

## Native Checks To Complete After Implementation

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
   Check M1, M3, M10 and H1 bars. Whether a companion M1 import is required
   remains unknown; no bar availability claim follows from a tick file alone.
6. Pin numeric comparison limits from a separate pilot before scoring the
   held-out winter/summer candidates, 2026-01-14 and 2026-07-15. Default limits
   are proposals. Incomplete captures or unverified feed/clock yield
   `INCONCLUSIVE`, never broker acceptance.

The prepared native pilot and raw evidence remain in ignored
`.codex-artifacts/exness-sprint1/`. It contains 1,831 ticks in five minutes and
nine adjacent equal-time rows. No native import is confirmed.

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
use Shift=0. Record each filename/hash/count in an operator-owned import log.
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
the current implementation does not invent a bar-import convention.

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
lexemes to files; normalize the `history` rows to JSONL with `time_ms`, `bid`
and `ask`. The timestamp is exactly `YYYY.MM.DD HH:MM:SS.mmm`, interpreted under
the verified broker clock. Do not reinterpret its name as an integer epoch or
discard its milliseconds. Keep account/community fields out of the capture.

Each tick entry declares a disjoint `[start_broker_msc, end_broker_msc)` interval,
file SHA-256, actual row count, format and completeness. For `mcp_jsonl`, also
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

## Validation And Rollback

Each sprint runs focused Python tests, compileall, identifier/include and
broker-boundary review, and `git diff --check`. Code rollback uses the recorded
parent commit; preserve immutable raw data and version derived corrections.
No MQL5 source change is planned, so the existing compile evidence is reused.
See the [acceptance record](../research/exness-tick-history-acceptance.md).

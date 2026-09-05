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

## Validation And Rollback

Each sprint runs focused Python tests, compileall, identifier/include and
broker-boundary review, and `git diff --check`. Code rollback uses the recorded
parent commit; preserve immutable raw data and version derived corrections.
No MQL5 source change is planned, so the existing compile evidence is reused.
See the [acceptance record](../research/exness-tick-history-acceptance.md).

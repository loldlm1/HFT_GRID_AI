# Pivot Trial Matrix V11 Acceptance Preparation - 2026-08-07

## Status And Boundary

**Status**: The initial, Sprint 12, Sprint 14, and Sprint 16 MetaEditor compiles
passed, but four human real-tick runs exposed distinct strict V11 defects.
Sprint 11 fixed finalized-origin reconciliation and Sprint 13 fixed
accepted-send boundary parity. Sprint 15 now retains the third run's expected
gap-through structural denial as four explicit geometry-ineligible cells and
passes the complete non-compiler gate. The fourth run passes deterministic
time, broker, and matrix audits but exposes closed-session parity observation,
broker-terminal parity cleanup, run-completion ambiguity, and quadratic strict
validation. Corrective Sprints 17-19 are active; archive and hook cleanup remain
pending.

This protocol validates strict schema V11, the virtual SL/TP trial matrix,
bounded volatility re-entries, the unchanged one-order broker lane, and
broker-parity calibration. It does not create an automated Strategy Tester
harness, approve an MT5 runtime model, or authorize live rollout.

Raw TSV files are evidence. Do not edit them to satisfy validation. Preserve a
failed run and its artifacts when any gate fails.

## Frozen Candidate

- Branch: `bot/pivot_points_fractal`.
- Source candidate before acceptance-only documentation:
  `b3ebc59f463d72d1c378c3575ee6115876691ac5`.
- Sprint 8 rollback point: `9b55b5ddd70777df7da23c63e3f360d8280c96c2`.
- Entrypoint: `HFT_Grid_AI.mq5`.
- Initial compile mode used in Sprint 10: real `/compile`, not `/s`.
- Sprints 1-9 add no MQL5 test harness, test EA/script, CI module, or automated
  Strategy Tester orchestration.

### Precompile Binary Evidence

MetaEditor was intentionally not invoked for this V11 candidate before Sprint
10. The existing binary and compile log predate the V11 source commits:

| Artifact | Size | Modified | SHA-256 |
| --- | ---: | --- | --- |
| `HFT_Grid_AI.ex5` | 163,068 bytes | `2026-08-06 21:32:25.797037875 -0400` | `f080092b463e6ddd648407b7d8d955d841e75ca90be4464cd3e16c45c870dec8` |
| `logs/compile/agentic-build.log` | 20,834 bytes | `2026-08-06 20:50:14.605711269 -0400` | `b62a593f578bd09465ff307caf01c5748bffc0db1498f25c4c5e192dc83d9b32` |

Sprint 10 verified these precompile values before invoking MetaEditor and
recorded the regenerated binary metadata and parsed `0 errors, 0 warnings`
result. Because runtime acceptance exposed a source defect, Sprint 12 must
compile the corrected source again before renewed human evidence.

### Sprint 10 Compile Evidence

The frozen precompile hashes above were verified unchanged immediately before
the initial acceptance compile. The real `/compile` command completed with the
following evidence:

| Artifact/result | Evidence |
| --- | --- |
| MetaEditor result | `0 errors, 0 warnings, 10804 ms elapsed, cpu='X64 Regular'` |
| Compile helper result | `PASS` |
| Wine process return code | `1`; retained as a wrapper discrepancy because the parsed MetaEditor result is clean |
| `HFT_Grid_AI.ex5` | 234,334 bytes; modified `2026-08-07 11:44:19.120503799 -0400`; SHA-256 `5773fd16cca6d4fd487c0354b206dde259f9a05ce843bee9f8eb2479ec4b60ac` |
| `logs/compile/agentic-build.log` | 23,148 bytes; modified `2026-08-07 11:44:19.121503764 -0400`; SHA-256 `98616607f9c6e54a9c03b8d804d985fea5477b923996c74e5a7a4d99b52bf52e` |

The changed binary size, timestamp, and hash prove that MetaEditor regenerated
the V11 `.ex5`. No intermediate Sprint 1-9 compile was performed. This compile
remains valid evidence for the failed candidate, but it is superseded by the
required Sprint 12 compile after the lifecycle correction.

## First Human Run Audit - Failed Acceptance

### Evidence Identity

- Symbol and setup: `XAUUSD`, `EXNESS_SESSION`, Macro `H1`, Micro `M3`, export
  enabled, run ID `test_run_1`.
- Tester interval: `2026.06.08 00:00:00` through
  `2026.07.31 20:57:59` broker time.
- Debug evidence: external Common Files `query_debug.txt`, 5,742 lines,
  SHA-256 `1bf4ce10897438f3187f3190fc5f0487a3ab412e931a2318c0522292515511e0`;
  preserved before the corrected run as
  `query_debug_test_run_1_failed_20260807.txt`.
- V11 evidence: eight raw TSV files under external Common Files
  `PivotFractalV11/runs/test_run_1/`, approximately 232 KB.
- Raw query and TSV evidence was inspected read-only and remains unedited.

### Deterministic Exness Time - Pass

All 327 available broker/analysis/offset timestamp triplets satisfy:

```text
analysis_time = broker_time + offset_minutes
```

Every observed offset is `0`. That is correct for XAUUSD across the June-July
2026 UK-DST interval. Static source review confirms that `XAU`, `XAG`, `XPT`,
and `XPD` prefixes use the UK calendar, including suffixed broker symbols. The
analysis offset is `-60` outside UK DST and `0` from the last Sunday of March at
01:00 through the last Sunday of October before 01:00. Broker time remains the
causal clock; normalization is export-only.

This run empirically covers the summer branch. The season-independent behavior
comes from the explicit yearly calendar calculation and symbol-prefix mapping;
a future winter or boundary sample remains useful additional broker evidence,
not a known defect.

### Query Debug Trade Consistency - Pass

The file contains one session header and the following complete event sets:

| Event/result | Rows |
| --- | ---: |
| `PIVOT_ATTEMPT` | 1,922 |
| `PIVOT_SEND_RESULT` | 1,910 |
| Successful sends | 1,909 |
| Failed sends | 1 |
| Pre-send denials | 12 |
| `PIVOT_TERMINAL` | 1,909 |
| Broker TP | 951 |
| Broker SL | 957 |
| Manual tester-end close | 1 |

Read-only reconciliation found zero duplicate or missing event IDs and zero
identity, direction, geometry, normalized-volume, quote-money, 1R, attempt
status, terminal-set, terminal-sign, or binary-label inconsistencies. Every
successful send has one terminal event. The one failed send is consistently
audited as retcode `10016`, `Invalid stops`; all twelve no-send attempts are
explicit `DENIED` rows with unavailable request geometry.

The real broker lane therefore remains internally consistent. This does not
make the V11 research export acceptable because the export lifecycle fails
independently after the first few windows.

### Partial V11 Structure - Valid Before Failure

The run writes exactly the eight strict V11 filenames. Before exporter failure
it records three windows, five origins, 142 trials, 128 virtual outcomes, 19
execution checks, and four broker outcomes. The valid prefix contains:

- five origins with exactly sixteen index-0 matrix cells each;
- the exact four-SL-policy by TP `1,2,3,5` Cartesian product for every origin;
- 57 re-entry rows with contiguous chain indices;
- five parity shadows, four parity outcomes, and four strict parity pairs;
- four strict parity terminal matches and zero mismatches;
- no duplicate identity, row-integrity, or state-cap error.

These facts demonstrate that the matrix geometry and chain behavior reached
runtime, but they cannot authorize research use of a truncated failed run.

### Blocking V11 Failure And Root Cause

`run_summary.tsv` reports `completion_status=NATURAL` but
`export_status=FAILED`, `referential_integrity_error_count=2`, only three
window rows, and only five origin rows despite the broker log continuing
through July. Strict validation fails with fourteen active trials missing
outcomes: thirteen matrix trials and one broker-parity shadow.

The first failure is deterministic lifecycle control flow:

1. A valid H1 window expires and `PivotV11RecordWindow()` exports then removes
   its pending origins.
2. A broker position belonging to one exported origin can remain open beyond
   that H1 boundary.
3. Normal broker reconciliation continues calling `PivotV11UpdateOrigin()` on
   the bounded active `PivotSignal`.
4. The exporter no longer finds the removed pending origin, raises
   `UPDATE_ORIGIN_NOT_FOUND`, and disables all later V11 writes.

Concrete evidence is broker signal `broker_13479693207490312625`: it opens at
`2026.06.08 02:01:28`, its origin window expires at `03:00:00`, and it closes
at `05:30:53`. The secondary referential error is
`PARITY_OUTCOME_MISSING` during summary generation because the already-disabled
exporter cannot finish the outstanding parity shadow.

There is also an observability defect: `PivotV11MarkFailed()` prints the first
failure but does not append `PIVOT_V11_EXPORT_FAILED` to `query_debug.txt` when
file logging is enabled. The failed debug file therefore contains no direct
exporter-failure event even though the summary records failure.

### Corrective Disposition

Sprint 10 stops closeout and preserves this evidence. Sprint 11 adds explicit
`origin_export_finalized` state to active signals, marks it only after a window
record succeeds, allows later updates to no-op only for that explicit state,
keeps unknown origins fail-closed, and writes the first exporter failure once
through the existing query-debug logger. Sprint 11 uses static and existing
Python validation only. Sprint 12 performs the compile required by that first
correction. The second human run later supersedes it as a release candidate and
requires the final Sprint 14 compile after Sprint 13.

## Sprint 11 Corrective Implementation

The correction is intentionally narrow and leaves broker execution and schema
columns unchanged:

- `PivotSignal` carries `origin_export_finalized`, defaults it to `false`, and
  preserves it through explicit copies and bounded active-array compaction.
- A successful expired-window or run-finished `PivotV11RecordWindow()` call
  marks registered active signals with the same deterministic `window_id`.
- Failed window recording does not advance the terminal-export marker or mark
  any signal finalized.
- `PivotV11UpdateOrigin()` continues updating pending origins normally. A
  missing origin returns success only when the supplied signal is registered,
  explicitly finalized, and has non-empty origin/window identity. Every other
  missing origin still raises `UPDATE_ORIGIN_NOT_FOUND` and fails closed.
- `PivotV11MarkFailed()` now sends the first failure once through
  `ExecutionAppendQueryDebugLog()` when file logging is enabled and once to the
  terminal when console logging is enabled.

Non-compiler validation passes:

- exact finalized-state reset/copy/mark/update references and include order;
- one active `OrderSend`, one `OrderCheck`, FOK-only, and no
  `TRADE_ACTION_SLTP` path;
- no trade-mutation API reference in virtual matrix modules;
- Python compileall and all 22 existing contract tests;
- deterministic V11 fixture validate/build/audit with 19 trials, 18 outcomes,
  and expected training support rejection `16 < 500`;
- `git diff --check`.

No MetaEditor compile, MQL5 harness, test EA/script, CI module, or automated
Strategy Tester run is used in Sprint 11. Rollback point is Sprint 10 commit
`99b86c3`.

## Sprint 12 Corrective Compile Evidence

The committed corrective source is `7496c0c3a21c97de11d998e4ba6f779ffda1e830`.
The user intentionally regenerated `.ex5` before requesting the audited final
compile; that expected binary was recorded as 233,778 bytes, modified
`2026-08-07 12:15:07.398892137 -0400`, SHA-256
`c608e0b50cfba4e848f72fb4c66da5ad50530d3aebc7b1d5bfabc24a9122da53`.

The planned real `/compile` then completed with:

| Artifact/result | Evidence |
| --- | --- |
| MetaEditor result | `0 errors, 0 warnings, 9544 ms elapsed, cpu='X64 Regular'` |
| Compile helper result | `PASS` |
| Process-code evidence | Inner Wine return code was not retained by compact command output; the parsed MetaEditor result and regenerated artifacts are authoritative |
| `HFT_Grid_AI.ex5` | 233,176 bytes; modified `2026-08-07 12:52:29.601722974 -0400`; SHA-256 `5b2ffb7966cef3f90ec451fde343c7f1965f06549288a9b0ca24c4edbe6f3ec0` |
| `logs/compile/agentic-build.log` | 23,146 bytes; modified `2026-08-07 12:52:29.601722974 -0400`; SHA-256 `c8f773832ac3d337f4182bf29410007a2f744ab6a9a72c9ee1d375b18a699769` |

The changed binary size, timestamp, and hash prove regeneration from the
Sprint 11 corrective source. The renewed run below supersedes this binary as a
release candidate because it exposes another source defect. Sprint 14 must
compile the Sprint 13 correction before new human evidence.

## Second Human Run Audit - Failed Acceptance

### Evidence Identity

- Symbol and setup: `XAUUSD`, `FIXED_TIME_SESSIONS`, Macro `H1`, Micro `M3`,
  reference-balance lot `0.01`, export enabled, console logs disabled, file
  logs enabled.
- Run ID: `2026.06.05_00_00_00_XAUUSD_pivot_v11`.
- Tester interval: `2026.06.05 00:00:00` through
  `2026.07.31 20:57:59` broker time.
- Debug evidence: external Common Files `query_debug.txt`, 5,904 lines,
  2,434,054 bytes, SHA-256
  `ecc9d78e6d9a1f60e632b2c41b0e24c3665745dca6d20c1efabe056a931aac9e`.
- V11 evidence: exactly eight TSV files under external Common Files
  `PivotFractalV11/runs/2026.06.05_00_00_00_XAUUSD_pivot_v11/`,
  11,001,177 bytes in total.
- Raw query and TSV evidence was inspected read-only and remains unedited.

### Deterministic Time - Pass For The Configured Mode

The manifest and query session header both record `FIXED_TIME_SESSIONS`. All
16,474 available broker/analysis/offset timestamp triplets satisfy:

```text
offset_minutes = 0
analysis_time = broker_time
```

There are zero conversion errors. This proves the configured fixed-time rule,
not seasonal Exness normalization. A stable Exness research hour requires
`EXNESS_SESSION`; for XAUUSD that mode applies the UK DST calendar, with `-60`
minutes outside UK DST and `0` during UK DST. Source review and preserved
winter/summer/transition evidence continue to support that implementation, but
this June-July fixed-mode run cannot independently prove both seasonal
branches. Final seasonal acceptance should use `EXNESS_SESSION` and include a
winter or UK-boundary sample.

### Query Debug Trade Consistency - Pass

The complete query log reconciles as follows:

| Event/result | Rows |
| --- | ---: |
| `PIVOT_ATTEMPT` | 1,974 |
| Filled attempts | 1,964 |
| Pre-send denials | 10 |
| `PIVOT_SEND_RESULT` | 1,964 |
| Accepted retcode `10009` | 1,964 |
| `PIVOT_TERMINAL` | 1,964 |
| Broker TP | 975 |
| Broker SL | 988 |
| Manual tester-end close | 1 |

Every event set has unique `broker_signal_id` values. The 1,964 filled attempts
map one-to-one to accepted sends and terminal positions; all order tickets map
to the same terminal position and identifier. The ten denied attempts create no
send or terminal event and consistently report
`STRUCTURAL_STOP_WRONG_SIDE_OF_FRESH_ENTRY`. Read-only reconciliation found zero
direction, request geometry, exact 1R, normalized volume, quote-money, ticket,
timestamp-order, terminal-sign, or binary-label inconsistencies.

Of the accepted sends, 1,898 retain the trigger second and 66 complete one
second later. That normal synchronous broker delay is the condition that
exposes the V11 boundary defect below; it does not make the broker request
invalid.

### V11 Structure Before The Failure

The natural run summary records:

| Fact | Rows/result |
| --- | ---: |
| Pivot windows | 122 |
| Signal origins | 265 |
| Virtual trials | 6,820 |
| Matrix trials / re-entry trials | 6,552 / 2,248 |
| Broker-parity trials | 268 |
| Virtual outcomes | 6,780 |
| Execution checks / broker outcomes | 1,074 / 268 |
| Active-state peak / cap | 68 / 2,048 |
| Duplicate identities / row-integrity errors | 0 / 0 |
| Referential-integrity errors | 1 |
| Export / completion status | `FAILED` / `NATURAL` |

All 265 exported origins contain exactly the sixteen ordered index-0 matrix
cells, and every exported retry chain is contiguous from index 0. Virtual
outcomes reference known trial rows. The first strict error is
`virtual_trials.tsv:6723: trial references unknown origin`. The final files
contain 99 trial rows and 81 outcome rows for four origins from one unfinalized
H1 window; those buffered rows are valid descendants, but their four origin
rows and window row cannot be emitted after the exporter disables itself.

### Blocking Boundary Defect And Root Cause

The first durable failure is:

```text
2026.06.12 08:00:00 | PIVOT_V11_EXPORT_FAILED | operation=BROKER_PARITY_DECLARATION_FAILED
```

The associated R2 sell is causally triggered inside its H1 origin window at
`2026.06.12 07:59:59`. Its fresh FOK request is accepted by the broker one
second later at `08:00:00` with retcode `10009`, exact structural 1R geometry,
order/deal `538`, and no broker inconsistency. `BuildBrokerParityTrial()`
currently rejects `origin_expiry <= send_check.broker_time`, so the research
parity declaration fails even though the trigger belongs to the origin and the
real broker request has already succeeded.

The exporter then fails closed, later buffers still flush at run end, and the
four pending origins from that H1 window cannot finalize. This produces the 99
unknown-origin trial references. The Sprint 11 finalized-origin correction is
working: this run advances from the first failed run's three windows to 122
windows before reaching this separate accepted-send boundary case.

The correct deterministic representation is:

- matrix and re-entry trials must still be declared while their origin window
  is active;
- every accepted broker request must receive one parity trial when its trigger
  belongs to the origin window;
- parity `declared_broker_time` remains the accepted send time, even when it is
  on or after origin expiry;
- `origin_window_active_at_entry` must explicitly be `0` for that boundary
  crossing instead of falsifying the declaration time or dropping parity.

### Performance Audit And Bounded Optimization

No unbounded state or file behavior is visible. Active virtual state peaks at
68 of 2,048, the tick scan is bounded by current active state rather than the
cap, Bands handles are cached, and V11 rows flush in batches of 256. The 11 MB
folder and 2.4 MB query log cover only the exported prefix plus full broker
diagnostics; a successful full run will be larger by design but remains
append-only and bounded per emitted row.

One safe hot-path improvement is justified by source review:
`ProcessPivotTrialMatrixTick()` currently deep-copies every active trial state
before checking whether the current tick touches TP or SL. The state includes
two feature envelopes and multiple identity/geometry strings. Deferring that
copy until after `ResolvePivotTrialFirstTouch()` succeeds removes unnecessary
per-tick copying while preserving iteration order, first-touch semantics,
re-entry ordering, row content, and broker behavior.

Exact export overhead cannot be claimed from this run because no matched tester
elapsed-time pair was recorded and file logging was enabled. Final performance
evidence should compare the same interval with file/console logs disabled and
export disabled versus enabled. No broader refactor or state-index abstraction
is justified without that measurement.

## Sprint 13 Corrective Implementation And Static Validation

Sprint 13 keeps the accepted broker request authoritative. The parity builder
now validates that the causal trigger belongs to
`[active_bar_open, origin_expiry)`, retains the accepted send time as the parity
declaration, and derives `origin_window_active_at_entry` from whether that send
time is still before expiry. The exporter permits a false active-window flag
only for a broker-parity row whose internal declaration/expiry facts agree.
Matrix and re-entry rows still require the flag to be true.

The strict Python contract mirrors that distinction. A complete linked fixture
mutation moves pre-send, send, parity declaration, virtual outcome, terminal
check, broker entry/close, and run-finish facts to the exact H1 boundary. It
validates with `origin_window_active_at_entry=0`. Negative mutations reject a
false parity flag before expiry and an index-0 matrix declaration at expiry.

The bounded performance correction resolves TP/SL directly against the stored
trial and copies the complete active state only after a first touch. Reverse
iteration, continuation construction, outcome ordering, and removal behavior
are unchanged. No cache, index, allocation policy, state cap, broker API, or
public input changes.

Sprint 13 non-compiler validation records:

- Python compileall: pass.
- Full Python contract suite: 23 tests pass in 8.801 seconds.
- Exact-boundary parity test: pass.
- Deterministic V11 fixture validate/build/audit: pass; audit status remains the
  expected `INSUFFICIENT_SUPPORT` for the tiny fixture.
- Training support guard: expected fail-closed result
  `Not enough rows: 16 < 500`.
- Broker safety sweep: one `OrderSend`, one `OrderCheck`, FOK only, no
  `TRADE_ACTION_SLTP`, and no broker mutation in virtual modules.
- Include aggregation, lifetime references, active-state ordering, and
  whitespace checks: pass.

No MetaEditor compile, MQL5 harness, test EA/script, CI module, or automated
Strategy Tester run is used in Sprint 13. Rollback point is Sprint 12 commit
`c2fa5a0`.

## Sprint 14 Final Compile Evidence

The committed final source candidate is
`5f08f485f193c96c8f65b563f213e862811cce6c`. Before the planned compile, the
user-regenerated binary was 233,958 bytes, modified
`2026-08-07 12:57:03.792286248 -0400`, SHA-256
`be13a5f3f8374adb87376569dd162c5ea3b03f4c9cec23d536cfb352ab813053`.

The sole post-Sprint 13 real `/compile` completed with:

| Artifact/result | Evidence |
| --- | --- |
| MetaEditor result | `0 errors, 0 warnings, 10822 ms elapsed, cpu='X64 Regular'` |
| Compile helper result | `PASS` |
| Wine process return code | `1`; retained as the known wrapper discrepancy because the parsed MetaEditor result is clean |
| `HFT_Grid_AI.ex5` | 233,398 bytes; modified `2026-08-07 13:38:24.154920432 -0400`; SHA-256 `bf522b2bc8e8187047b04a5728fb7f429d1e6a548b3efe0235721594cea36d03` |
| `logs/compile/agentic-build.log` | 23,148 bytes; modified `2026-08-07 13:38:24.155920398 -0400`; SHA-256 `211cd54cfcef1d1fd27be3e7088a6ddaaa4a488b29d28fd2e459e0200171393d` |

The changed binary size, timestamp, and SHA-256 prove regeneration from the
Sprint 13 commit. No further compile is required unless source changes again.
The third human run below requires a source correction, so this compile is
preserved but superseded as release evidence. No hook cleanup or archive is
allowed before the new Sprint 16 acceptance gate passes.

## Third Human Run Audit - Failed Acceptance

### Evidence Identity

- Symbol and setup: `XAUUSD`, `EXNESS_SESSION`, Macro `H1`, Micro `M3`,
  reference-balance lot `0.01`, export enabled, console logs disabled, file
  logs enabled.
- Auto-generated run ID:
  `2026.01.05_00_00_00_XAUUSD_pivot_v11`.
- Tester interval: `2026.01.05 00:00:00` through
  `2026.07.31 20:57:59` broker time.
- Debug evidence: external Common Files `query_debug.txt`, 21,290 lines,
  8,807,587 bytes, SHA-256
  `d1b8874529ccfc187ff10d4b5cf2e104801f78d8fe441b8edf4fe6461204a7e1`;
  preserved before another run as
  `query_debug_pivot_v11_sprint14_failed_20260807.txt` with the same hash.
- V11 evidence: exactly eight raw TSV files under external Common Files
  `PivotFractalV11/runs/2026.01.05_00_00_00_XAUUSD_pivot_v11/`,
  1,676,201 file bytes.
- The query and raw TSV evidence were inspected read-only. The preserved query
  is a byte-identical copy; no raw row was edited.

### Deterministic Exness Time - Pass

All 2,510 available broker/analysis/offset timestamp triplets satisfy:

```text
analysis_time = broker_time + offset_minutes
```

The 2,509 detailed winter triplets use `-60`. The run-finish triplet at
`2026.07.31 20:57:59` uses `0`. The run therefore exercises both configured
seasonal branches: January normalizes one hour earlier and July retains broker
time. There are zero partial triplets or arithmetic mismatches.

Static source review confirms that `XAU`, `XAG`, `XPT`, and `XPD` prefixes,
including broker suffixes, use the UK calendar. For 2026 the transition window
is the last Sunday of March at `01:00` through the last Sunday of October before
`01:00`. Broker time remains the causal clock for bars, triggers, attempts,
orders, outcomes, and durations; only exported analysis time changes.

Because the exporter fails during January, the only empirical summer V11 fact
is the natural run-finish timestamp. That is sufficient to verify the shared
normalizer's summer branch, but Sprint 16 still requires a successful detailed
summer export before final research acceptance.

### Query Debug Trade Consistency - Pass

The complete query log contains one session header and reconciles as follows:

| Event/result | Rows |
| --- | ---: |
| `PIVOT_ATTEMPT` | 7,178 |
| Filled attempts | 7,054 |
| Pre-send denials | 122 |
| Failed sends | 2 |
| `PIVOT_SEND_RESULT` | 7,056 |
| Accepted retcode `10009` | 7,054 |
| Failed retcode `10016` | 2 |
| `PIVOT_TERMINAL` | 7,054 |
| Broker TP | 3,493 |
| Broker SL | 3,560 |
| Manual tester-end close | 1 |

Every event set has unique `broker_signal_id` values. Each filled attempt maps
to one accepted send and one terminal position/identifier; denied attempts
create neither send nor terminal rows, and failed sends create no terminal
position. All routed requests use the correct executable quote side, exact
price-distance 1R within floating tolerance, downward-normalized `0.01` volume
steps, and consistent request/send geometry. Send-result timestamps are the
same second for 6,772 attempts and one second later for 284; none precedes its
trigger and every terminal event follows its send.

The 122 denials are 67 closed-session cases, 52 invalid structural-geometry
cases, and three below-minimum-volume cases. The two `10016 Invalid stops`
send failures remain explicit failed attempts. The terminal set contains one
manual run-end close and otherwise only broker-confirmed TP/SL labels. Read-only
reconciliation finds zero broker-lane identity, geometry, volume, ticket,
timestamp-order, or binary-label defects.

### V11 Structure Before The Failure

The natural run summary records:

| Fact | Rows/result |
| --- | ---: |
| Pivot windows / signal origins | 22 / 42 |
| Virtual trials | 1,028 |
| Matrix / re-entry / parity trials | 987 / 315 / 41 |
| Virtual outcomes | 1,016 |
| Execution checks / broker outcomes | 166 / 41 |
| Matrix TP / SL outcomes | 267 / 708 |
| Parity pairs / matches / mismatches | 41 / 41 / 0 |
| Active-state peak / cap | 49 / 2,048 |
| Duplicate identities / row-integrity errors | 0 / 0 |
| Referential-integrity errors | 1 |
| Export / completion status | `FAILED` / `NATURAL` |

All 42 exported origins contain exactly the ordered sixteen index-0 matrix
cells, covering the exact four SL policies by TP `1,2,3,5` product. Every
exported retry chain is contiguous from index `0`, structural policies never
retry, and the maximum volatility retry index is `3`. All 41 exported parity
trials link one parity outcome and one broker outcome; the summary records 41
terminal matches and zero mismatches or exclusions. Query-to-V11 reconciliation
for those 41 broker outcomes has zero ticket, close-time, reason, gross, or net
differences.

Strict validation correctly rejects the failed run because twelve active
matrix trials have no terminal outcome. These were still active when the
exporter disabled itself and therefore could not receive run-end censor rows.
There are no unexpected outcomes or state-cap failures.

### Blocking Gap-Through Defect And Root Cause

The first durable failure is:

```text
2026.01.05 23:04:25 | PIVOT_V11_EXPORT_FAILED | operation=REGISTER_ORIGIN_GEOMETRY_INVALID
```

On that tick, an `R1` sell origin is consumed with Bid/Ask
`4454.865/4454.977`. Its immutable structural stop is the `R2` pivot at
`4453.166`, already below the fresh sell entry because the market has crossed
both levels in one observed gap-through batch. Broker execution correctly
denies the R1 attempt with
`STRUCTURAL_STOP_WRONG_SIDE_OF_FRESH_ENTRY`. The same tick then processes the
new R2 context and successfully sends its independent structural order with SL
`4456.984`.

The exporter incorrectly couples valid origin identity to structural
tradability. `PivotV11RegisterOrigin()` requires positive directional
structural risk and raises a referential-integrity failure when the stop is on
the wrong side. That disables every later V11 write even though the origin,
pivot ladder, broker facts, and expected denial are all auditable.

The matrix builder contains the matching ambiguity: its structural policy uses
the absolute entry-to-stop distance. If registration were merely relaxed, that
absolute distance would reflect the invalid R2 stop to the opposite side of
entry and create a synthetic active structural trial that no longer copies the
actual pivot route. The deterministic representation must instead be:

- retain the consumed origin and actual structural route facts;
- declare all sixteen index-0 cells in policy order;
- mark the four structural TP cells `INELIGIBLE_GEOMETRY` with no synthesized
  SL, TP, money plan, active state, or outcome;
- evaluate the twelve volatility cells independently from frozen Micro width;
- leave broker denial, same-tick pivot order, and parity rules unchanged.

This is a research-export defect. The complete seven-month query audit confirms
that the real broker lane continues safely and consistently after V11 fails.

### Performance Audit And Recommendation

The observed runtime structures remain bounded: active state peaks at 49 of
2,048, trial processing scans current active state rather than the cap, two
Bands handles are cached, nonvisual tester runs skip chart work, and V11 rows
flush in batches of 256. Sprint 13 already removed the unnecessary deep copy of
every active state before first touch. No additional state-index, cache, file
format, or broker-call refactor is justified by this evidence.

This run cannot measure normal V11 overhead. File logging was enabled and
produced an 8.8 MB query file, while V11 stopped after the first day and wrote
only 1.68 MB despite the broker lane continuing through July. The timings and
folder growth therefore do not represent a successful export-enabled run.
Sprint 16 must use the same real-tick interval twice with both log settings
disabled, once with export disabled and once enabled. Until that matched pair
exists, the honest conclusion is that the implementation is statically bounded
but exact tester overhead remains unmeasured.

### Corrective Disposition

Sprint 14 stops closeout and preserves this third failed run. Sprint 15
separates origin identity from structural tradability, makes wrong-side
structural cells explicit geometry-ineligible facts, aligns strict Python
validation and coverage, and runs the complete non-compiler gate. Sprint 16 is
the only post-correction compile and remains active until renewed human
real-tick, strict V11, broker, parity, seasonal-time, chart, and matched
performance evidence all pass. Archive and hook cleanup remain prohibited
until then.

## Sprint 15 Gap-Through Correction And Static Validation

Origin registration now distinguishes valid identity and broker facts from
fresh-entry structural tradability. A finite positive next-pivot stop remains
an origin fact even when a gap has moved it to the wrong side of the executable
entry. The origin preserves its raw entry/SL and signed algebraic 1R TP instead
of disabling V11.

Initial matrix construction checks the structural stop direction before
requested-risk normalization. A wrong-side or equal stop declares the four
structural TP policies as `INELIGIBLE_GEOMETRY` with reason
`STRUCTURAL_STOP_WRONG_SIDE_OF_ORIGIN_ENTRY`; those rows have no synthesized
geometry, money plan, active state, or outcome. The twelve volatility policies
remain independent and retain the frozen trigger Micro width.

Strict tooling mirrors the exporter. A consistent gap-through origin validates,
while active, distance-only, reflected, geometry-populated, or money-populated
structural cells fail closed. The preserved third failed run remains rejected
for its twelve missing active outcomes; no raw TSV was changed or retroactively
accepted.

Sprint 15 non-compiler validation records:

- Focused gap-through contract: pass.
- Python compileall: pass.
- Full Python contract suite: 24 tests pass in 9.280 seconds.
- Deterministic V11 fixture validate/build/audit: pass; audit status remains the
  expected `INSUFFICIENT_SUPPORT` for the 16-row training cohort.
- Training support guard: expected fail-closed result
  `Not enough rows: 16 < 500`.
- Include graph, nine-input public contract, header/manifest tests, broker
  safety, active-state cap, buffering, handle lifecycle, and frontend isolation:
  pass.
- Broker boundary remains one `OrderSend`, one `OrderCheck`, FOK only, no
  `TRADE_ACTION_SLTP`, and no broker mutation in virtual modules.
- `git diff --check`: pass.

No MetaEditor compile, MQL5 harness, test EA/script, CI module, or automated
Strategy Tester run is used in Sprint 15. Rollback point is Sprint 14 commit
`496ae4a`; the Sprint 15 correction commit is
`448bda1122896557bf8fc5d22c356b19c9bcd59f`.

## Sprint 16 Final Compile Evidence

The sole post-Sprint 15 real `/compile` ran against committed source
`448bda1122896557bf8fc5d22c356b19c9bcd59f` and completed with:

| Artifact/result | Evidence |
| --- | --- |
| MetaEditor result | `0 errors, 0 warnings, 10966 ms elapsed, cpu='X64 Regular'` |
| Compile helper result | `PASS` |
| Wine process return code | `1`; retained as the known wrapper discrepancy because the parsed MetaEditor result is clean |
| Pre-compile `HFT_Grid_AI.ex5` | 233,282 bytes; modified `2026-08-07 14:24:00.867741170 -0400`; SHA-256 `5c4340cffcd909a3c99549d3a94afad4478e178aaa8b4df8e9e801005ef7d3cd` |
| Compiled `HFT_Grid_AI.ex5` | 233,494 bytes; modified `2026-08-07 15:09:04.103724822 -0400`; SHA-256 `777b952b94e024436f5d49fbd34f62f4f9816efe9785b06516c9a598c45696df` |
| `logs/compile/agentic-build.log` | 23,148 bytes; modified `2026-08-07 15:09:04.104724788 -0400`; SHA-256 `22e136350f4dc61ff01272e4e17c0b7ae2e247ebd12a4ccdd55744218fec42d5` |

The changed size, timestamp, and SHA-256 prove `.ex5` regeneration after the
Sprint 15 commit. The fourth run below supersedes this binary as final release
evidence because source correction is required. No second compile is authorized
until Sprint 19.

## Fourth Human Run Audit - Failed Acceptance

### Evidence Identity

- Symbol and setup: `XAUUSD`, `EXNESS_SESSION`, Macro `H1`, Micro `M3`,
  reference-balance lot `0.01`, export enabled, console logs disabled, and file
  logs enabled.
- Source/binary: Sprint 15 commit `448bda1`; Sprint 16 compiled `.ex5`
  SHA-256 `777b952b94e024436f5d49fbd34f62f4f9816efe9785b06516c9a598c45696df`.
- Run ID: `2026.01.05_00_00_00_XAUUSD_pivot_v11`.
- Tester interval: `2026.01.05 00:00:00` through
  `2026.07.31 20:57:59` broker time.
- Debug evidence: `query_debug.txt`, 21,290 lines, 8,807,579 bytes, SHA-256
  `e9b08af8743b2e019b3baf5f5fdceea60ba21d0a9fe6b4d699757d810668ced4`;
  preserved byte-identically as
  `query_debug_pivot_v11_sprint16_e9b08af8.txt`.
- V11 evidence: exactly eight raw TSV files and 299,967,529 file bytes. The
  query and TSV evidence were inspected read-only.

| V11 file | Bytes | SHA-256 |
| --- | ---: | --- |
| `run_manifest.tsv` | 2,516 | `fc06b9d0d500b12b51cec9a58cc0cc4e62346475257af9e6df8935056bfc5691` |
| `pivot_windows.tsv` | 2,785,376 | `b8621592f92c146a0ac87258c36b023f22ac88239a2bb53207819a71d61f57c3` |
| `signal_origins.tsv` | 7,054,206 | `c038e04f51de87c460916b6a7efbe5fa1e9634e325ffbe9ecf4fb3ba30557a65` |
| `virtual_trials.tsv` | 174,878,369 | `2baaca0a92c2671835c6164c073eafb6f25e906898e031f966afccc94c5a716f` |
| `virtual_outcomes.tsv` | 87,299,791 | `0a30b586f26741b72f42877fe431d2b84c82ea7bcf9c033be026d9cdcc52e57c` |
| `execution_checks.tsv` | 22,470,547 | `022acdd4da37ec14d3c41a0543f51a27277d2d6d45b19acdd1ecb71622ece824` |
| `broker_outcomes.tsv` | 5,475,276 | `a47f76e40ee8e77c6d2085a5bc2c823d86af5addb6b01a42d94b969a5d8def5f` |
| `run_summary.tsv` | 1,448 | `da51faa83ed1dc0b7dd83b0a96eb4aac490cd94e70240b89cd393f9ea692221b` |

### Deterministic Exness Time - Pass

All 449,228 non-null broker/analysis/offset triplets satisfy:

```text
analysis_time = broker_time + offset_minutes
```

The distribution is 180,525 rows at `-60` and 268,703 rows at `0`, with zero
partial triplets, arithmetic mismatches, or UK-DST classification errors. The
latest winter fact is `2026.03.27 20:54:03` at `-60`; the first available
post-transition fact is `2026.03.29 22:00:00` at `0`. Broker timestamps remain
unchanged and causal; only analysis timestamps shift.

### Query Debug And Broker Consistency - Pass

The complete query and V11 broker ledger reconcile as follows:

| Event/result | Rows |
| --- | ---: |
| Session headers | 1 |
| `PIVOT_ATTEMPT` | 7,178 |
| Filled / denied / failed sends | 7,054 / 122 / 2 |
| `PIVOT_SEND_RESULT` | 7,056 |
| Accepted `10009` / failed `10016` | 7,054 / 2 |
| `PIVOT_TERMINAL` / `broker_outcomes.tsv` | 7,054 / 7,054 |
| Broker TP / SL / manual run-end close | 3,493 / 3,560 / 1 |

Every event identity is unique. Filled attempts map one-to-one to accepted
sends, terminal events, execution-check ownership, and broker outcomes. Denied
attempts create no send or terminal; failed sends create no broker position.
Trigger/request quote sides, request/send geometry, exact price-distance 1R,
downward volume normalization, ticket/identifier ownership, timestamps, close
reason, gross/net money, and binary eligibility have zero reconciliation errors.
The 122 denials remain 67 closed-session, 52 structural-geometry, and three
below-minimum-volume cases; the two failed sends remain explicit `10016 Invalid
stops` facts.

### Matrix And V11 Structure - Pass Before Parity Summary

A streaming structural audit completes with zero errors:

| Fact | Rows/result |
| --- | ---: |
| Pivot windows / signal origins | 3,412 / 7,178 |
| Virtual trials / active declarations / outcomes | 186,036 / 185,788 / 185,788 |
| Matrix / parity trials | 178,982 / 7,054 |
| Initial matrix origins / policy chains | 7,178 / 114,848 |
| TP / SL / censored virtual outcomes | 54,592 / 131,162 / 34 |
| Geometry / distance / money ineligible rows | 200 / 32 / 16 |
| Gap-through origins | 50, each with exactly four structural geometry-ineligible cells |
| Maximum rows for one origin | 52 |
| Active-state peak / cap | 83 / 2,048; no capacity failure |
| Duplicate / referential / row-integrity counters | 0 / 0 / 0 |

All 7,178 declared origins contain the exact ordered four-SL-policy by TP
`1,2,3,5` index-0 product. Every chain is contiguous, every retry points to its
immediately preceding `SL_FIRST`, structural policies never retry, exact R and
minimum-distance arithmetic pass, and active trials equal outcome identities.
Execution checks contain 7,178 observations, 7,178 fresh pre-send checks, 7,056
send results, and 7,054 terminal checks, with one FOK deal send at most per
signal and no protection mutation.

### Blocking Parity Observation Defects

The summary reports 7,054 parity pairs, 7,048 terminal matches, five strict
mismatches, and one manual run-end exclusion. The five mismatches are:

| Broker signal | Parity first touch | Broker terminal | Causal finding |
| --- | --- | --- | --- |
| `broker_11561925449488809286` | `SL_FIRST` at `2026.01.12 21:44:54` | TP at `23:02:31` | Threshold quote occurs during the metals daily closed interval; broker execution resumes after `23:01` |
| `broker_10887269983167353549` | `TP_FIRST` at `2026.01.26 21:32:02` | SL at `2026.01.27 01:11:59` | Same-window attempts at `21:08` through `21:36` are explicitly denied as `actual_broker_session_closed` |
| `broker_11336469120627649661` | `TP_FIRST` at `2026.02.05 21:04:01` | SL at `23:01:03` | Same-window attempts at `21:02` through `21:34` are explicitly session-closed |
| `broker_5730662912872475597` | `TP_FIRST` at `2026.02.13 21:05:44` | SL at Sunday `2026.02.15 23:01:51` | Friday attempts at `21:12` through `21:46` are explicitly session-closed |
| `broker_12643081431797828316` | `TP_FIRST` at `2026.05.26 22:35:35` | SL at `22:06:58` | Broker reconciliation closes first between relevant `OnTick` observations; the unresolved parity state later reaches the opposite side |

Parity currently treats every quote-side threshold as broker-executable. That
is invalid for calibration during an actual closed trade session. Separately,
broker reconciliation can complete from `OnTradeTransaction` or history before
the matrix receives another qualifying tick; no handoff currently censors the
still-active parity shadow. The correction must remain parity-only: the matrix
continues to be the documented counterfactual quote-path lane, while parity is
the broker-executability calibration lane.

### Blocking Run-Completion Ambiguity

The run reaches the configured tester end but reports
`completion_status=CENSORED`. `PivotRunCompletionStatus()` checks outstanding
virtual state before the successful tester-interval flag, so 33 active matrix
rows and one unresolved parity row make the run-level reason censored before
those rows receive their correct run-end censor outcomes. Run completion and
row terminal state are distinct facts: a natural interval may contain explicit
unlabelled `CENSORED` trials. The runtime and strict summary validator must stop
conflating them.

### Performance Audit

The V11 artifact modification window spans approximately 236 seconds from
manifest creation to summary write while producing about 300 MB for seven
months of real ticks. Runtime state peaks at only 83 of 2,048, uses two cached
Bands handles, scans only current active state, buffers 256 rows per file, and
does no nonvisual chart work. No broad MQL5 cache, state-index, file-format, or
broker-call refactor is justified. The new parity session lookup should run
only after a parity threshold candidate is detected.

Offline strict validation is the material performance defect. The validator
was manually interrupted after more than five minutes while still in
`_validate_trials()`. Its final origin gate scans all 186,036 trials for every
one of 7,178 origins, approximately 1,335,366,408 comparisons. A separate
single-pass streaming audit of the same matrix finishes in about 22 seconds.
Sprint 17 replaces the nested scan with per-origin indices without weakening
validation. Exact tester export overhead still requires the planned matched
log-disabled control/export pair after correction.

### Corrective Disposition

Sprint 16 records this fourth failed acceptance and stops closeout. Sprint 17
makes strict validation linear in run size. Sprint 18 adds session-aware parity
touches, explicit broker-terminal parity censoring, and orthogonal natural run
completion, then runs the complete non-compiler gate. Sprint 19 is the only new
MetaEditor compile and remains active until renewed human real-tick, strict V11,
broker, parity, performance, DST, and chart evidence pass. Archive and hook
cleanup remain prohibited until then.

## Sprint 17 Linear Validator Correction And Validation

`_validate_trials()` now accumulates each origin's ordered index-0 matrix cells
and total matrix row count during its existing single pass. The final origin
gate uses direct per-origin lookups. Exact sixteen-cell order, suppressed-matrix
rejection, and the 52-row cap are unchanged, while the former
`origins x trials` scan is removed.

Validation records:

- Focused initial-matrix count/order/identity mutation test: pass.
- Python compileall: pass.
- Full Python contract suite: 24 tests pass in 9.621 seconds.
- Preserved 299,967,529-byte failed run: reaches the expected strict error
  `broker_outcomes.tsv:281: unexplained broker/parity TP/SL terminal mismatch`
  in 144.69 seconds, with 1,930,264 KB peak RSS. The same command previously
  remained inside the quadratic trial/origin gate after more than five minutes.
- Deterministic fixture validate/build/audit: pass; audit remains the expected
  `INSUFFICIENT_SUPPORT` result.
- Training support guard: expected fail-closed result
  `Not enough rows: 16 < 500`.
- No schema token, runtime source, MetaEditor compile, MQL5 harness, test
  EA/script, CI module, or automated Strategy Tester path changed.
- `git diff --check`: pass.

The remaining approximately 1.9 GB validator peak reflects loading and joining
all strict raw tables in memory. Streaming the entire validator would be a much
larger tooling redesign and is not justified by this run: the full failed path
now completes in bounded time and reports the intended semantic blocker.

## Precompile Validation Record

The frozen candidate has the following non-compiler evidence:

- Python compileall: pass.
- Full Python contract suite: Sprint 13 expands the suite from 22 to 23 tests;
  Sprint 15 expands it to 24 passing tests.
- Exact MQL5/Python V11 header parity: eight files pass.
- Exact manifest key/fixed-token parity: 48 keys pass.
- Deterministic V11 fixture: validation, build, and audit pass.
- Fixture derived counts: 18 matrix-long rows, one initial-wide origin, 16
  eligible virtual rows, 16 policy chains, and one calibration pair.
- Training support guard: expected fail-closed result
  `Not enough rows: 16 < 500`.
- Broker safety sweep: one `OrderSend`, one `OrderCheck`, FOK only, no
  `TRADE_ACTION_SLTP`, and no trade mutation in matrix modules.
- Resource/cleanup sweep: two cached Bands handles, export-gated creation,
  deinit censoring before summary, state reset, and frontend isolation.
- `git diff --check`: pass.

These checks support the release-candidate freeze but do not replace the final
MetaEditor compile or human real-tick evidence.

## Fixed Human Setup

Use `Every tick based on real ticks`. Keep the following fixed between the
export-disabled and export-enabled performance runs:

| Setting | Required value/evidence |
| --- | --- |
| Symbol | Record exact broker symbol, including suffix |
| Broker/session | Record broker and `Broker_Session` |
| Macro/Micro | `PERIOD_H1` / `PERIOD_M3`, unless the evidence states another valid fixed pair |
| Lot mode | `EXECUTION_LOT_REFERENCE_BALANCE_PERCENT` |
| Lot size | `0.01` |
| Tester interval | Same start/end broker timestamps for both performance runs |
| Deposit/leverage | Same values for both runs |
| Logs | `Enable_Logs=false`, `Enable_File_Logs=false` for performance evidence |
| Export run | `Enable_Signal_Feature_Export=true` and unique `Signal_Feature_Run_Id` |
| Control run | `Enable_Signal_Feature_Export=false` |
| EA instances | One instance for the account/symbol |
| Account mode | Hedging for broker execution acceptance |

Record tester settings, start/end timestamps, terminal build, broker server,
symbol properties, and screenshots or broker-history references outside Git.

## Runtime Acceptance Sequence

### 1. Macro Window And Origin Identity

- [ ] Previous completed Macro shift `1` owns PP/S1..S3/R1..R3.
- [ ] Active-window times are broker-native and no missing candle is synthesized.
- [ ] PP above/below/equal arming follows one fixed role per window.
- [ ] Identity is `(symbol, Macro timeframe, active bar open, level)` and first
  trigger consumes it even when routing or execution fails.
- [ ] Same-tick path order remains deterministic for downward and upward moves.

### 2. Initial Sixteen-Cell Matrix

Select at least one feature-complete origin and join `signal_origins.tsv` to
`virtual_trials.tsv` by `origin_id`.

- [ ] Exactly 16 `trial_role=MATRIX`, `reentry_index=0` rows exist.
- [ ] The Cartesian product is exactly four SL policies by TP `1,2,3,5`.
- [ ] `policy_id` and `trial_id` are unique and stable.
- [ ] Structural cells copy the structural risk route; volatility cells use
  frozen `origin_micro_band_width_0 * 0.13/0.21/0.34` before normalization.
- [ ] Buy trial entry is Ask and exit side is Bid; sell entry is Bid and exit
  side is Ask.
- [ ] Risk rounds outward to whole trade ticks and TP is exact integer R from
  normalized risk.
- [ ] Minimum risk is spread plus `max(stops, freeze)` plus one trade tick.
- [ ] Failed feature, geometry, distance, or money plans remain explicit
  ineligible rows and never become broker orders.

### 3. Independent TP Chains And Re-entry

Use naturally observed chains where available. Keep each policy chain separate
by `(origin_id, sl_policy, tp_r_multiple)`.

- [ ] A `TP_FIRST` chain is terminal and never reopens.
- [ ] Only `SL_FIRST` permits the same chain's next generation.
- [ ] Retry indices are contiguous and limited to `0..3`.
- [ ] `preceding_loss_count`, parent trial, source outcome, and next trial links
  reconcile exactly.
- [ ] Retry entry uses the observed executable quote, not the prior SL threshold.
- [ ] Frozen origin width remains unchanged while retry features are fresh.
- [ ] At most one next generation per policy chain is created on one tick.
- [ ] Closed chain nominal R equals the sum of its terminal trial R values.

### 4. Pivot Boundary, Gap, Expiry, And Censoring

- [ ] Buy `PP/S1/S2` retries remain more than one trade tick above `S1/S2/S3`
  for both entry and proposed SL.
- [ ] Sell `PP/R1/R2` retries remain more than one trade tick below `R1/R2/R3`
  for both entry and proposed SL.
- [ ] Equality and gap-through suppress the old-context retry.
- [ ] `S3`/`R3` use the index-3 cap without an outer boundary.
- [ ] An active trial may finish after origin expiry, but no new retry starts.
- [ ] Run-end active rows become `CENSORED` and never receive a binary target.
- [ ] `active_state_peak <= 2048` and `state_capacity_failed=0` in accepted runs.

### 5. Unchanged Broker Lane

- [ ] One consumed identity can cause at most one real structural 1R send.
- [ ] Observation and fresh pre-send checks are distinct; only fresh facts
  authorize `OrderSend`.
- [ ] Requests are `TRADE_ACTION_DEAL` with `ORDER_FILLING_FOK`.
- [ ] Broker SL/TP stay immutable; no trailing, break-even, partial close,
  resize, or `TRADE_ACTION_SLTP` occurs.
- [ ] Reconciliation remains symbol/magic/ticket owned.
- [ ] Broker deal history alone populates actual fill, close, gross, commission,
  swap, fee, net, budget R, and execution R.
- [ ] Frontend displays real positions only and nonvisual mode creates no chart
  objects.

### 6. Broker-Parity Calibration

- [ ] Every accepted send creates one `BROKER_PARITY` trial after acceptance.
- [ ] Denied and failed sends create no parity row.
- [ ] Parity entry, SL, TP, and normalized volume equal the submitted request.
- [ ] Parity is outside the sixteen-cell matrix, retries, policy support, and ML.
- [ ] Each closed broker outcome with `parity_trial_id` joins one parity trial
  and one parity outcome.
- [ ] Manual, mixed, stop-out, expert, other, feature-incomplete, and censored
  pairs have explicit calibration exclusions.
- [ ] Every strict eligible pair agrees on TP versus SL. Any unexplained
  mismatch blocks acceptance.
- [ ] Timing, entry/exit price, virtual gross, broker gross/execution-R, and
  actual cost deltas are reviewed as distributions, not assumed equal.

### 7. Deterministic Time And Features

- [ ] Broker time owns windows, triggers, retries, orders, outcomes, and splits.
- [ ] Analysis time and offset follow the configured fixed/Exness DST policy.
- [ ] Micro `%B 0..5`, Macro pivot `%B 0..5`, shift-0 Micro width, and shift-1
  Macro width reproduce from the recorded Bands facts.
- [ ] One trigger batch shares one origin feature snapshot; retry processing
  captures at most one shared retry snapshot per tick.
- [ ] Missing features affect research eligibility only, never broker admission.

## Static Fallback For Market-Unreachable Cases

Human real-tick evidence remains mandatory overall, but a specific rare branch
may use named static evidence when the selected market interval cannot reach it:

| Branch | Required static evidence |
| --- | --- |
| Outward tick normalization and integer R | `NormalizePivotTrialRiskOutward`, `BuildPivotTrialStopAndTakeProfit`, validator mutations |
| Next-pivot boundary equality/gap | `PivotTrialBoundaryEligible`, `PivotTrialReentryBoundaryEligible`, schema boundary mutations |
| TP-consumed chain cannot reopen | `ConfigurePivotTrialContinuation`, TP-retry rejection test |
| Origin expiry blocks only new retry | `PivotTrialOriginWindowActive`, continuation validator |
| Index-3 extreme cap | `PIVOT_TRIAL_MAX_REENTRY_INDEX`, continuation validator |
| Run-end censoring | `BuildPivotTrialRunEndOutcome`, `FinalizePivotTrialMatrixForExport` |
| Capacity failure | `AppendPivotTrialActiveState`, state-cap summary validation |
| Failed send has no parity | Post-acceptance call order in `SendPivotMarketOrder`, parity schema mutations |

Record the exact function/test reference and why natural market evidence was not
available. Static fallback cannot replace broker lifecycle, parity, natural-run,
performance, DST, or chart acceptance.

## Strict V11 Research Commands

```bash
export PIVOT_RUNS_ROOT="$MT5_COMMON_FILES/PivotFractalV11/runs"
export PIVOT_RUN_ID="<run_id>"
export PIVOT_DATASET_ID="<dataset_id>"
export PIVOT_AUDIT_ID="<audit_id>"

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id "$PIVOT_RUN_ID" \
  --validate-only

.venv/bin/python tools/deterministic_signal_ml/build_dataset.py \
  --runs-root "$PIVOT_RUNS_ROOT" \
  --run-id "$PIVOT_RUN_ID" \
  --dataset-id "$PIVOT_DATASET_ID"

.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py \
  --dataset-id "$PIVOT_DATASET_ID" \
  --audit-id "$PIVOT_AUDIT_ID" \
  --minimum-group-support 30

.venv/bin/python tools/deterministic_signal_ml/train_model.py \
  --dataset-id "$PIVOT_DATASET_ID" \
  --model-id <model_id>
```

The raw run must contain exactly eight files. Acceptance requires
`completion_status=NATURAL`, `export_status=OK`, zero duplicate/referential/row
integrity errors, no state-cap failure, and no unexplained strict parity
mismatch. Natural completion may contain explicit unlabelled run-end trial
censors; those row outcomes do not redefine why the tester run ended.

## Evidence Record

Sprint 10 records the failed first run, Sprint 12 records the second, Sprint 14
records the third gap-through failure, and Sprint 16 records the fourth
parity/session and completion-semantics failure. Sprint 19 will replace only the
pending final-acceptance values after the Sprint 17/18 corrections:

| Evidence | Result |
| --- | --- |
| Current source commit | Sprint 15 correction `448bda1`; Sprint 17/18 corrections and Sprint 19 acceptance pending |
| Latest compile result and elapsed time | Sprint 16 pass: `0 errors, 0 warnings`, 10,966 ms; superseded by the fourth failed run |
| Latest compiled `.ex5` size/mtime/SHA-256 | 233,494 bytes; `2026-08-07 15:09:04.103724822 -0400`; `777b952b94e024436f5d49fbd34f62f4f9816efe9785b06516c9a598c45696df` |
| First failed run | XAUUSD, `EXNESS_SESSION`, `test_run_1`, `2026.06.08` through `2026.07.31`, approximately 232 KB |
| Second failed run | XAUUSD, `FIXED_TIME_SESSIONS`, `2026.06.05_00_00_00_XAUUSD_pivot_v11`, `2026.06.05` through `2026.07.31`, 11,001,177 bytes |
| Third failed run | XAUUSD, `EXNESS_SESSION`, `2026.01.05_00_00_00_XAUUSD_pivot_v11`, `2026.01.05` through `2026.07.31`, 1,676,201 raw TSV bytes |
| Fourth failed run | Same setup/run ID after fresh regeneration, 299,967,529 raw TSV bytes; full interval exported before parity summary failure |
| Second-run windows/origins/matrix/retry/parity rows | 122 / 265 / 6,552 / 2,248 / 268; export fails at the next H1 boundary |
| Third-run windows/origins/matrix/retry/parity rows | 22 / 42 / 987 / 315 / 41; export fails on wrong-side structural origin registration |
| Third-run TP/SL/censored/ineligible counts | 267 TP / 708 SL / 0 censored / 0 ineligible; 12 active matrix outcomes missing after failure |
| Fourth-run windows/origins/matrix/retry/parity rows | 3,412 / 7,178 / 178,982 / 64,134 / 7,054 |
| Fourth-run TP/SL/censored/ineligible counts | 54,592 TP / 131,162 SL / 34 censored / 248 ineligible; active/outcome identities exact |
| Broker outcomes and exclusions | Query runs one through four all reconcile; fourth run has 3,493 TP / 3,560 SL / 1 manual, 122 denials, and 2 failed sends |
| Strict parity pairs/matches/mismatches/exclusions | Fourth run: 7,054 / 7,048 / 5 / 1 |
| Active-state peak/cap status | First/second/third/fourth runs: 25 / 68 / 49 / 83 of 2,048; no capacity failure |
| Dataset/audit/model artifact IDs and sizes | Pending |
| Export-disabled elapsed time | Pending |
| Export-enabled elapsed time and overhead | Pending |
| Human chart/broker-history observations | All broker/query audits pass; all four V11 research runs fail for distinct strict-export/calibration defects |
| Static fallbacks used | Fourth run has detailed winter/summer triplets; matched log-disabled performance and renewed chart acceptance remain pending |

## Blocking Conditions

Stop closeout and preserve evidence when any of the following occurs:

- MetaEditor reports any error or warning, or `.ex5` is not regenerated.
- The broker lane sends more than one order per consumed identity, modifies
  protection, loses ticket ownership, or mixes virtual and actual money facts.
- The matrix is not exactly sixteen index-0 cells for a declared origin.
- Retry indices skip/duplicate, TP reopens, or a boundary/expiry rule is wrong.
- V11 strict validation, build, audit, or support guards fail.
- A strict eligible parity pair has an unexplained TP/SL mismatch.
- State capacity, duplicate identity, referential integrity, row integrity, or
  export status fails.
- Performance or file growth is unbounded or operationally unacceptable.

Final acceptance remains offline-research-only. Older-engine positions must be
flat, the account must be hedging, and one EA instance per account/symbol is
required before any separately authorized future deployment.

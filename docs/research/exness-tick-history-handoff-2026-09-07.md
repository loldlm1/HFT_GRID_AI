# Exness Tick History Handoff

Current as of 2026-09-07 UTC. The six implementation sprints are complete and
[archived](../plans/archive/exness-tick-history-2026-09-07/README.md). The
deterministic capture auditor is committed, and both prepared seasonal custom
imports pass. Formal broker equivalence remains `INCONCLUSIVE`; full-history
operation and tester acceptance remain pending. There is no active implementation
plan to resume.

## Implementation And Validation

Sprint 6 is `4460b2343d264ad003c5ad6b0dba4658017448fb`. The subsequent capture
auditor is `5bb79738a3a39e62d2854f30480b5d37f61a8f86`, with Sprint 6 as its
rollback parent. The [historical acceptance record](exness-tick-history-acceptance.md)
retains the six sprint gates and earlier evidence without rewriting their status.

The [Python service](../../tools/exness_tick_history/README.md) supports configurable
source selection, resumable downloads, deterministic sanitization/merge, native
MT5 export and comparison. `freeze-capture` seals saved raw MCP responses and
actual request metadata. `audit-capture` checks checksums, complete intervals,
ordered tick multiplicity, milliseconds, exact Decimal prices, native
M1/M3/M10/H1 Bid OHLC/tick volumes and real warm-up bars. `compare-broker` accepts
the same raw MCP JSON without creating a JSONL copy.

The auditor passed 74 service tests, compileall and source/include/safety checks.
The existing 38 V13 contract tests passed at Sprint 6; their inputs are unchanged.
Auditor implementation SHA-256:
`304e6f91dd40eb290b0dda9b313758e080444a76b32607f88072ed6c1a37f495`.
Reuse that evidence for documentation-only cleanup. Reuse frozen captures;
reacquire only missing, changed, corrupt or potentially truncated evidence.

## Verified Native Imports

All times below are the supplied UTC text imported with Shift=0; interval ends
are exclusive. These results prove exact preservation of the diagnostic TSVs
in the captured custom symbols. They do not establish broker-feed equivalence
or a registered `export-mt5`/`compare-roundtrip` acceptance.

| Evidence | Winter | Summer |
| --- | --- | --- |
| Custom symbol | `XAUUSD_EXN_PRO_W1` | `XAUUSD_EXN_PRO_S1` |
| Start | 2026-01-12 20:00 | 2026-07-13 00:00 |
| Exclusive end | 2026-01-15 00:00 | 2026-07-16 00:00 |
| Scored day | 2026-01-14 | 2026-07-15 |
| Full-range ticks | 922,664 | 947,513 |
| Scored-day ticks | 459,039 | 272,226 |
| Adjacent equal-time rows | 6,254 | 4,473 |
| Native M1 bars | 2,929 | 4,134 |
| Native M3 bars | 979 | 1,380 |
| Native M10 bars | 294 | 414 |
| Native H1 bars | 49 | 69 |
| Preceding completed H1 bars | 26 | 46 |
| Tick and bar/tick-volume audits | PASS, zero mismatches | PASS, zero mismatches |

MT5 generated the validated bars from the imported ticks. These ranges need no
further import, separate bar import or chart opening for this verification.
Winter uses the compact file starting at 20:00, not the original larger January
12-14 preparation. Keep the two existing symbols separate.

Winter capture used 119 requests and 119 saved tick responses with no retries.
Its offline audit took 141.02 seconds with 42,724 KiB peak RSS. Summer took
147.31 seconds with 44,356 KiB peak RSS; a same-implementation replay produced a
byte-identical report. Offline audits made no terminal requests.

## Broker Findings And Remaining Gates

Diagnostic clock evidence supports Shift=0 on both sampled days. Unique
matching-quote samples show median broker delays of 38 ms in winter and 37 ms
in summer; the main observed quote break occurs approximately one hour earlier
in summer. This does not prove every year's clock regime or transition dates.
The feeds differ: maximum observed M1 OHLC errors are 1.605 winter and 0.375
summer in price units, using broker-tick-derived M1 diagnostics.

Continue from the [operator workflow](../workflows/exness-tick-history.md) in
this order:

1. Resolve native broker specification/trade tick size and archive-to-Pro feed
   mapping. Ubuntu/Wine, Pro demo/live and bare symbols with configurable future
   suffixes are accepted choices. The prior broker MCP snapshot reports tick
   size/value zero; do not infer the trade tick from Point. Last observed custom
   tick values differ (winter `0.1`, summer `1`), so specification and P&L parity
   remain unverified. Property changes can erase history; preserve existing
   symbols and use a fresh version if a corrected specification is required.
2. Obtain native broker January M1 bars, previously unavailable through MCP
   with the 100,000-bar chart limit. Complete broker ticks exist, but deriving
   M1 from them does not replace the formal native-bar gate.
3. Pin independent comparison limits and formal clock/reference evidence. The
   two scored days have already been inspected; do not calibrate limits on them.
   Complete verified registered-export/round-trip evidence before formal
   `compare-broker` acceptance. Do not invent export IDs or operator attestations
   for these diagnostic TSVs.
4. Complete seasonal acceptance and broader DST transition diagnostics with
   complete frozen references. Preserve failures and missing-history limits.
5. Measure native storage, refresh capacity planning and complete the selected
   full-history backfill/build/audit/import. The original 146.4 GB estimate
   exceeded the then-free 120.4 GB; those are historical measurements. Downloaded
   pilots and HEAD inventories do not establish complete 2015-present coverage.
6. Complete an operator-owned real-tick Strategy Tester run and strict V13
   validation with input provenance stored outside its twelve-file run folder.

No MQL5 source, include or broker execution changes are part of this service.
No new compile, tester pass or live rollout is claimed. The separate V13 human
chart-object/rendering gate remains outstanding.

## Retained Local Evidence

Raw data and private profiles remain ignored and at their existing paths:

| Location | Contents |
| --- | --- |
| `.codex-artifacts/exness-seasonal-native-20260906/` | Seasonal summary, frozen custom captures, request manifests, compact winter TSV and exact audit reports |
| `.codex-artifacts/exness-seasonal-20260906/` | Original seasonal TSVs/source manifests, frozen broker captures and broker review JSONs |
| `artifacts/exness_tick_history/` | Private profiles, immutable ZIPs, ledgers and datasets, including `xauusd-winter-20260112-15-v1` and `xauusd-summer-20260713-16-v1` |
| `.codex-artifacts/exness-sprint1/` | Retained early pilot and capability evidence |
| `.codex-artifacts/exness-native-probe-20260906/` | Earlier five-minute native verification |
| `.codex-artifacts/exness-2015-parser-sample.json` | Bounded historical parser evidence |

Within the seasonal-native directory, `seasonal-native-imports-v1.json` records
both final results. Report SHA-256 values are:

- `winter-audit-v1.json`:
  `40f03493e3e04b430e80f652524fba077e00745e0589e7192d96686c964e4975`.
- `summer-audit-v2.json`:
  `6f9f4ec7dc4918128773f3da553c3bae1aa6ee1a9acc7ea27f11c91112712df5`.

Earlier receipts/checkpoints retain their original facts, including the auditor's
then-uncommitted status and then-pending winter verification. The commit and
seasonal results recorded here supersede those status fields without modifying
the historical evidence.

## Thread Closeout

Completed project-local plan/compact state and Exness checkpoints are archived
byte-for-byte under `.codex-artifacts/thread-closeout-exness-20260907/hook-state/`.
The original seasonal preparation guide is retained there as
`seasonal-preparation-README.md`; its working copy points here. Only the
disposable `.codex-artifacts/exness-clean-venv` is removed; the maintained `.venv`,
source data, imports, captures and reports remain available.

The local `closeout-receipt.json` in that archive records cleanup validation,
the final cleanup commit and its rollback parent
`5bb79738a3a39e62d2854f30480b5d37f61a8f86`. Code rollback uses reviewed reverts;
it does not restore or alter terminal history. Start the next thread from this
handoff and the workflow, without restoring completed hook state.

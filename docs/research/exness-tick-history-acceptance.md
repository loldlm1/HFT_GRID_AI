# Exness Implementation And Acceptance Evidence

Implementation follows the saved plan, now recoverable at Git location
`bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93:docs/plans/archive/exness-tick-history-2026-09-07/exness-tick-history-plan.md`.
See [history recovery](../README.md#guides-and-history-recovery);
original sprint results below are unchanged.
Operator-dependent gates are deferred by explicit user instruction. Automated
software validation is separate from native import and broker-feed acceptance.

## Sprint 1

Rollback parent: `5cb7b2420607759ecca829b910a2c9a02b4c1f5e`.
Configuration and source contract implementation includes strict profiles,
half-open date semantics, explicit suffix handling, bounded source inspection,
HTTP classification and safe redirect handling.

Automated gate PASS: 12 unittest cases; compileall; CLI help/config smoke;
real archive HEAD 200 and full local source inspection; identifier/include and
broker-boundary review; artifact-ignore checks; `git diff --check`. No executable
terminal/trading mutation references occur in the service. Source pilot:
`Exness_XAUUSD_2026_09_01.zip`, SHA-256
`a81e11c64339786dd98481130cf8ed3b7c315de809bac32a41442431edba0bea`,
344,128 rows, 766 adjacent equal timestamps, no timestamp regressions.
Native specification, feed mapping, clock mapping, import round trip and bar
availability: `PENDING_OPERATOR`. No broker-equivalence claim is made.

## Sprint 2

Sprint 1 commit / rollback parent: `66ca15f`.
Automated gate PASS: 22 tests including mixed calendar ownership, leap day,
HTTP recovery, 200/206 range semantics, changed validators, rejected HTML,
truncation, Retry-After, corrupt ZIP, disk reserve, lock contention and cached
reuse. Compileall and the common source/include/safety/whitespace gate pass.

Real pilot inventories: `inv-de3bd1931b34c6722c14a2cf` (2015 annual) and
`inv-138658e774d08b22dfc2ad01` (August 2026 monthly plus September 1 daily).
All three ZIPs passed length/structure/CRC and SHA-256 checks: 124,484,055
compressed bytes total. The recent run was deliberately interrupted (exit 130),
then completed while reusing the daily object already committed to the ledger.
Its monthly partial had zero bytes at interruption; nonzero byte-range resume
is validated by deterministic transfer fixtures. A competing writer failed
without disturbing the active lock. Repeat download performs zero HTTP body
bytes. Source rows and historical coverage are assessed in Sprint 3.

## Sprint 3

Sprint 2 commit / rollback parent: `286e6b7`.
Automated gate PASS: 32 tests, including exact decimal range/precision,
malformed UTC dates, legitimate duplicates, stable tie order, quarantine and
selection conservation, interrupted atomic publication, altered Parquet,
9,000-row multiple-batch processing at 64 MB, and actual DuckDB spill-limit
exhaustion. Compileall and the common source/include/safety gate pass.

Real dataset `xauusd-20260901-v2`, inventory
`inv-77b1cceb5cf5e13a90c6e695`: 344,128 retained rows, zero quarantined or
excluded rows, 766 equal-time rows, no adjacent identical ticks, and no source
timestamp regressions. Ordered logical dataset SHA-256:
`7b69fd2dc2a4d23a8e308be2b2852c5079d611325a9dd18ffd7773126309cb16`.
An earlier build produced the same logical hash. Final Parquet: 3,891,663 bytes;
build: 59.089 seconds, peak RSS 358,532 KiB with a 512 MB DuckDB setting.
The full archive/partition audit verifies bytes, logical order and conservation.
Resource evidence is a one-day measurement, not a completed full backfill.
The 2015/August archives are retained for subsequent larger-range operation.

## Sprint 4

Sprint 3 commit / rollback parent: `f51d489`.
Automated gate PASS: 40 tests, including native six-field formatting, exact
digits/trade-tick compatibility, reversible clock intervals, unknown regimes,
backward DST ambiguity, name collisions, unsplit timestamp groups, duplicate
multiplicity and exact native Bid OHLC comparison on M1/M3/M10/H1 fixtures.
Deletion, added ticks, tied-row reversal, 1 ms/price perturbations, altered
specification and bar files cannot pass. Millisecond precision loss and absent
native evidence yield `INCONCLUSIVE`. Compileall and common review pass.

The public specification/clock templates remain deliberately unverified and
the real export command refuses them. Native custom-symbol creation/import,
round trip, current nonzero trade tick and M1 history generation remain
`PENDING_OPERATOR`. There is no new MQL5 program or terminal mutation API.
Whether a companion M1 file is necessary is deferred with the native capability
finding; no unverified native bar convention has been implemented.

## Sprint 5

Sprint 4 commit / rollback parent: `46ec437`.
Automated gate PASS: 51 tests. Authored complete native round-trip and broker-day
fixtures pass all independent gates; wrong feeds, an hour shift, missing ticks,
reversed equal-time groups and widened spreads cannot pass. Empty, incomplete,
limit-sized MCP captures, missing pin provenance and absent native acceptance
remain inconclusive. Tests cover JSON numeric lexemes, interval bisection and
the unsplittable one-millisecond limit case, seasonal/DST candidates, real prior
bar warm-up and source-versus-native Bid OHLC/pivot input metrics. Compileall,
CLI schedule/inconclusive seasonal report and common source/include review pass.

The numerical profile remains `PROPOSED` in the public example. No complete
operator broker reference, verified clock/specification or native custom-symbol
round trip has been supplied. Real winter, summer and transition comparison
results therefore remain `PENDING_OPERATOR`; fixture results are software
validation only. Future autumn dates are not represented as observed history.

## Sprint 6

Sprint 5 commit / rollback parent: `3005705`.
Automated gate PASS: **58 service tests** in a newly created virtual environment
with Python 3.12.11 and a fresh DuckDB 1.5.4 install; **38 existing V13 contract
tests** in the project environment. CLI help/build/audit/status tests and
compileall pass. The final reliability review added bounded validator/price
inputs, source revision retention, conservative storage planning, and recovery
after ZIP publication but before ledger commit. An initially failing retry
fixture was isolated from the prior iteration's recoverable object; the final
full suite passes with its HTTP/retry assertions intact.

Real network check: selection page HEAD 403; archive host HEAD 200. No VPN or
proxy configuration was changed. Full inventory
`inv-6e244609e216802ca3d09123`, frozen September 6 UTC, selects 23 candidates
(11 annual, eight monthly, four daily), 2,993,886,749 ZIP bytes, with requested
start 2015-01-01 and resolved exclusive cutoff 2026-09-05. These are HEAD
candidates, not a verified full backfill. Three pilot ZIP bodies are verified.

The first 10,000 rows sampled from the retained 2015 ZIP pass the exact parser,
begin at 2015-08-10 00:00:00.000Z and include 3,817 adjacent equal timestamps.
This is a bounded first-row sample, not proof of the annual minimum or complete
2015 coverage. The complete modern-day dataset/audit remains the Sprint 3
evidence, including its preserved ordered hash and 344,128 ticks.

The conservative full-workflow storage estimate is 146,437,977,528 bytes versus
120,363,225,088 free at measurement. Its source expansion and Parquet inputs
are measured; the native text/history allowances are explicit estimates.
Full backfill/export/import is `PENDING_CAPACITY_AND_NATIVE_PILOT`. Measure the
native pilot and/or provision capacity before executing it. No full-history,
native round-trip, real seasonal comparison or tester pass is claimed.

The final documentation/identifier/include/safety gate preserves all `.mq5`,
`.mqh` and existing V13 Python source. Local links, artifact ignore paths and
`git diff --check` pass. No compile or Strategy Tester run was performed in this
Python-only batch. The workflow supplies the concrete deferred operator queue.

## Commit And Rollback Ledger

| Sprint | Commit | Rollback parent |
| --- | --- | --- |
| 1 | `66ca15f` | `5cb7b24` |
| 2 | `286e6b7` | `66ca15f` |
| 3 | `f51d489` | `286e6b7` |
| 4 | `46ec437` | `f51d489` |
| 5 | `3005705` | `46ec437` |
| 6 | The commit containing this final handoff | `3005705` |

The ignored execution journal records full commit and rollback SHAs, including
Sprint 6 after publication. Revert reviewed code commits in reverse order if
necessary; preserve raw archives, data manifests and operator evidence. There
is no accepted new custom symbol, seasonal cohort or V13 tester run to roll
back yet. Implementation completion does not close the operator gates listed
in the [workflow](../../tools/exness_tick_history/README.md#operator-validation-queue).

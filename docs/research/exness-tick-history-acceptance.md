# Exness Implementation And Acceptance Evidence

Implementation follows [the saved plan](../../exness-tick-history-plan.md).
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

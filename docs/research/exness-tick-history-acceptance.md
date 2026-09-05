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

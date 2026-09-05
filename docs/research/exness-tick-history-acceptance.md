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

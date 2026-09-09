# Parent Close Chronology - Execution Plan

Status: authorized and in progress, 2026-09-09. One writing session.

## Objective And Boundaries

Fix the confirmed broker-parent censor timestamp defect in the V13 EA and
validate parent-dependent research chronology in Python. Preserve the original
`XAUUSD_Exness_Run_2015` run and prepared Exness tick files. Censored children
remain excluded from binary outcomes. Broker execution and the export-only
`EXNESS_SESSION` analysis calendar retain their existing policies.

The immediate correction retains strict V13's twelve files and frozen headers.
Broker outcomes provide actual close times; terminal execution checks provide
the broker-clock time at which reconciliation records closure. Censored-row
observed quotes are observation evidence, never hypothetical quotes reconstructed
at an earlier close time. A recovered copy must retain explicit correction and
observation provenance outside its twelve-file run directory.

## Sprints

1. **Producer handoff and strict chronology.** Preserve the confirmed close time
   before broker-parent cleanup, censor only its unfinished links, and handle
   repeated reconciliation/run termination without duplicate outcomes. Strengthen
   strict Python parent interval checks and replace repeated parent-outcome scans
   with indexed lookups. Add regression cases in the existing Python suite.
   Gate: include/reference and execution-boundary review, Python checks, compile
   with zero errors/warnings, regenerated binary metadata, `git diff --check`.
2. **Bounded full-run audit and recovery tooling.** Add an explicit, memory-bounded
   parent chronology audit that reuses V13 headers/manifest rules, rejects invalid
   relationships and reports all affected rows. Audit the original run for child
   admission/completion beyond actual parent closure. Recover into a separate
   run only when the evidence supports timestamp-only repair; retain originals,
   observation clocks, hashes and the exact transformation in a sidecar. Otherwise
   document why a full rerun is required. Gate: mutation/negative regression
   cases, full original-run chronology evidence, source stability and diff checks.
3. **Tester and operational acceptance.** Run the corrected EA on a bounded
   real-tick XAUUSD interval that contains observed failures, using isolated run
   IDs and the existing H1/M10/M3, Exness policy and 50 ms delay. Validate exports
   with strict V13 and the new chronology audit; compare export-on/off broker
   behavior. Validate a recovered run if recovery qualifies. Record exact results,
   residual validation limits and rollback references. Human chart acceptance
   and live deployment remain outside this correction.

Each completed sprint receives its own reviewed commit. Previous uncommitted
Exness preparation changes remain outside these commits. No old handoff is edited.

## Checkpoint And Rollback Ledger

| Sprint | Status | Commit | Rollback |
| --- | --- | --- | --- |
| 1 | Complete | `65090dc` | `3478c97` |
| 2 | Complete | Recorded by sprint commit | `65090dc` |
| 3 | In progress | Pending | Sprint 2 commit |

Runtime evidence: ignored `.codex-artifacts/parent-close-chronology-20260909/`.
Earlier diagnosis: [run verification](../../research/exness-xauusd-run-verification-2026-09-09.md).
The full existing in-memory semantic validator is not silently replaced by a
parent-only audit; each acceptance report must state which checks actually ran.

Sprint 1 evidence: 40 existing Python contract tests pass, including new
broker-delay, completed-child and run-end boundaries. MetaEditor build 6184
reports zero errors/warnings; the regenerated binary is 295,370 bytes,
SHA-256 `ac5ae06f4d7a2c788d4470e2b849a9bb76cd6b97d1d0c646c2e9ffd719b79237`.
All 39 project include files resolve without cycles. Public inputs and the one
`OrderSend` owner remain unchanged. The CLI did not expose compiler tools; after
the documented Wine runner produced no log, runtime discovery reached the local
MetaEditor MCP endpoint and `get_workspace_info` preceded `compile_file` there.

Sprint 2 evidence: 44 Python tests pass. The maintained bounded audit confirms
that the original full run has only 1,109 late broker-parent censor rows; zero
late admissions or completed children were found. A separate recovered copy
at `/home/admin/Documents/Exness_Research_Runs/` passes parent chronology, with
per-row observation/quote provenance and both file hash sets. Full semantic
validation of this large derivative remains separate and is not claimed.
